-- ==============================================================================
-- Migração: 20261110_standardize_ai_matching_and_pgvector.sql
-- Objetivo:
--  1. Adicionar restrição de unicidade em pet_images (pet_id, image_url) para idempotência
--  2. Adicionar coluna 'origin' em matches ('automatic' | 'manual')
--  3. Criar índices HNSW com vector_cosine_ops para busca rápida por similaridade
--  4. Criar funções RPC seguras com SECURITY DEFINER para matching vetorial
--  5. Atualizar trigger trg_notify_on_match para notificar APENAS correspondências automáticas
-- ==============================================================================

-- 1. Remoção de duplicatas históricas em pet_images antes de criar constraint
DELETE FROM public.pet_images a
USING public.pet_images b
WHERE a.id > b.id
  AND a.pet_id = b.pet_id
  AND a.image_url = b.image_url;

-- Adiciona restrição de unicidade para permitir UPSERT seguro
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_pet_images_pet_url'
    ) THEN
        ALTER TABLE public.pet_images
        ADD CONSTRAINT uq_pet_images_pet_url UNIQUE (pet_id, image_url);
    END IF;
END $$;

-- 2. Adicionar coluna origin na tabela matches
ALTER TABLE public.matches
ADD COLUMN IF NOT EXISTS origin VARCHAR(20) NOT NULL DEFAULT 'manual';

-- Atualiza registros existentes
UPDATE public.matches
SET origin = 'automatic'
WHERE match_method IN ('visual_single_vector', 'visual')
  AND origin = 'manual';

-- 3. Índices HNSW para alta performance em consultas vetoriais
CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_embedding_hnsw
ON public.pet_visual_profiles
USING hnsw (aggregated_embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_pet_images_embedding_hnsw
ON public.pet_images
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- 4. Funções RPC com SECURITY DEFINER e search_path fixo

-- 4.1. Busca pets encontrados candidatos para um pet perdido
CREATE OR REPLACE FUNCTION public.match_found_pets_for_lost(
    query_embedding VECTOR(768),
    target_pet_type VARCHAR(50),
    exclude_pet_id UUID,
    similarity_threshold FLOAT DEFAULT 0.70,
    match_limit INT DEFAULT 20
)
RETURNS TABLE (
    pet_id UUID,
    similarity_score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Validações defensivas
    IF query_embedding IS NULL THEN
        RAISE EXCEPTION 'query_embedding não pode ser nulo';
    END IF;

    IF similarity_threshold < 0.0 OR similarity_threshold > 1.0 THEN
        RAISE EXCEPTION 'similarity_threshold deve estar entre 0.0 e 1.0';
    END IF;

    IF match_limit < 1 OR match_limit > 100 THEN
        RAISE EXCEPTION 'match_limit deve estar entre 1 e 100';
    END IF;

    RETURN QUERY
    SELECT
        pvp.pet_id,
        (1 - (pvp.aggregated_embedding <=> query_embedding))::FLOAT AS similarity_score
    FROM public.pet_visual_profiles pvp
    INNER JOIN public.pet_found_alerts pfa ON pfa.id = pvp.pet_id
    WHERE pvp.pet_type = target_pet_type
      AND pvp.pet_id <> exclude_pet_id
      AND pvp.aggregated_embedding IS NOT NULL
      AND pfa.status = 'active'
      AND (1 - (pvp.aggregated_embedding <=> query_embedding)) >= similarity_threshold
    ORDER BY pvp.aggregated_embedding <=> query_embedding ASC
    LIMIT match_limit;
END;
$$;

-- 4.2. Busca pets perdidos candidatos para um pet encontrado recém-cadastrado
CREATE OR REPLACE FUNCTION public.match_lost_pets_for_found(
    query_embedding VECTOR(768),
    target_pet_type VARCHAR(50),
    exclude_pet_id UUID,
    similarity_threshold FLOAT DEFAULT 0.70,
    match_limit INT DEFAULT 20
)
RETURNS TABLE (
    pet_id UUID,
    similarity_score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF query_embedding IS NULL THEN
        RAISE EXCEPTION 'query_embedding não pode ser nulo';
    END IF;

    IF similarity_threshold < 0.0 OR similarity_threshold > 1.0 THEN
        RAISE EXCEPTION 'similarity_threshold deve estar entre 0.0 e 1.0';
    END IF;

    IF match_limit < 1 OR match_limit > 100 THEN
        RAISE EXCEPTION 'match_limit deve estar entre 1 e 100';
    END IF;

    RETURN QUERY
    SELECT
        pvp.pet_id,
        (1 - (pvp.aggregated_embedding <=> query_embedding))::FLOAT AS similarity_score
    FROM public.pet_visual_profiles pvp
    INNER JOIN public.pet_lost_alerts pla ON pla.id = pvp.pet_id
    WHERE pvp.pet_type = target_pet_type
      AND pvp.pet_id <> exclude_pet_id
      AND pvp.aggregated_embedding IS NOT NULL
      AND pla.status = 'active'
      AND (1 - (pvp.aggregated_embedding <=> query_embedding)) >= similarity_threshold
    ORDER BY pvp.aggregated_embedding <=> query_embedding ASC
    LIMIT match_limit;
END;
$$;

-- Permissões de execução para usuários autenticados e anon
GRANT EXECUTE ON FUNCTION public.match_found_pets_for_lost TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_lost_pets_for_found TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_found_pets_for_lost TO anon;
GRANT EXECUTE ON FUNCTION public.match_lost_pets_for_found TO anon;

-- 5. Atualização da trigger function: Notifica SOMENTE em matches automáticos com score >= 0.70
CREATE OR REPLACE FUNCTION public.handle_auto_match_notification()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_owner_user_id UUID;
    v_lost_pet_name TEXT;
    v_found_location TEXT;
    v_found_image_url TEXT;
    v_found_breed TEXT;
    v_score_percentage TEXT;
BEGIN
    -- Dispara notificação APENAS se origin for 'automatic' e score >= 0.70
    IF NEW.origin = 'automatic' AND NEW.similarity_score >= 0.70 THEN
        -- Recupera dono do pet perdido
        SELECT user_id, pet_name 
        INTO v_owner_user_id, v_lost_pet_name
        FROM public.pet_lost_alerts 
        WHERE id = NEW.lost_pet_id;

        -- Recupera dados do pet encontrado
        SELECT found_location, image_url, breed
        INTO v_found_location, v_found_image_url, v_found_breed
        FROM public.pet_found_alerts 
        WHERE id = NEW.found_pet_id;

        IF v_owner_user_id IS NOT NULL THEN
            v_score_percentage := TO_CHAR(ROUND((NEW.similarity_score * 100)::numeric, 1), 'FM990.0') || '%';
            
            INSERT INTO public.notifications (
                user_id,
                type,
                title,
                body,
                is_read,
                related_pet_id,
                related_match_id,
                metadata,
                created_at
            ) VALUES (
                v_owner_user_id,
                'match_found',
                'Possível correspondência encontrada! (' || v_score_percentage || ')',
                'Um pet com características visuais semelhantes a "' || COALESCE(v_lost_pet_name, 'seu pet') || '" foi avistado em ' || COALESCE(v_found_location, 'sua região') || '. Toque para conferir.',
                FALSE,
                NEW.lost_pet_id,
                NEW.found_pet_id,
                jsonb_build_object(
                    'match_id', NEW.id,
                    'similarity_score', NEW.similarity_score,
                    'lost_pet_id', NEW.lost_pet_id,
                    'found_pet_id', NEW.found_pet_id,
                    'found_pet_image_url', v_found_image_url,
                    'found_pet_breed', v_found_breed,
                    'origin', NEW.origin
                ),
                NOW()
            )
            ON CONFLICT (user_id, related_pet_id, related_match_id) 
            WHERE type = 'match_found' 
            DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recria a trigger para disparar tanto no INSERT quanto no UPDATE da coluna origin
DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;

CREATE TRIGGER trg_notify_on_match
AFTER INSERT OR UPDATE OF origin ON public.matches
FOR EACH ROW
WHEN (NEW.origin = 'automatic')
EXECUTE FUNCTION public.handle_auto_match_notification();
