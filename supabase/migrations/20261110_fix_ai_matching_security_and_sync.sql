-- ==============================================================================
-- Migração Corretiva: 20261110_fix_ai_matching_security_and_sync.sql
-- Objetivo:
--  1. Deduplicação segura e determinística em pet_images:
--     - Prioriza manter o registro que possui embedding válido (NOT NULL).
--     - Entre válidos (ou entre nulos), prioriza o registro mais recente (created_at DESC).
--     - Garante que embeddings válidos jamais sejam descartados para manter registros nulos.
--  2. Reforço de segurança nas funções RPC de busca vetorial:
--     - Revoga permissão de EXECUTE para a role 'anon' e 'PUBLIC'.
--     - Garante EXECUTE restrito a 'authenticated' e 'service_role'.
--     - Valida obrigatoriedade de usuário autenticado (auth.uid() IS NOT NULL).
--     - Valida que o usuário autenticado é o proprietário do alerta de origem (exclude_pet_id).
--     - Valida dimensionalidade do vetor (768 dimensões).
--  3. Correção do trigger de notificações em matches (trg_notify_on_match):
--     - Dispara no INSERT com origin = 'automatic' E similarity_score >= 0.70.
--     - Dispara no UPDATE apenas se houver transição de origem (OLD.origin IS DISTINCT FROM 'automatic' AND NEW.origin = 'automatic').
--     - Evita execuções redundantes em atualizações automáticas sucessivas.
-- ==============================================================================

-- 1. DEDUPLICAÇÃO SEGURA E DETERMINÍSTICA EM pet_images
WITH ranked_images AS (
    SELECT
        id,
        pet_id,
        image_url,
        ROW_NUMBER() OVER (
            PARTITION BY pet_id, image_url
            ORDER BY
                (embedding IS NOT NULL) DESC,
                created_at DESC,
                id DESC
        ) AS rn
    FROM public.pet_images
)
DELETE FROM public.pet_images
WHERE id IN (
    SELECT id FROM ranked_images WHERE rn > 1
);

-- Garante existência da constraint de unicidade após deduplicação segura
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_pet_images_pet_url'
    ) THEN
        ALTER TABLE public.pet_images
        ADD CONSTRAINT uq_pet_images_pet_url UNIQUE (pet_id, image_url);
    END IF;
END $$;

-- 2. FUNÇÕES RPC SEGURAS (SECURITY DEFINER + CHECAGEM DE PROPRIEDADE + SEM ANON)

-- 2.1 match_found_pets_for_lost
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
DECLARE
    v_calling_user UUID;
    v_owner_user UUID;
BEGIN
    -- 1. Valida autenticação obrigatória
    v_calling_user := auth.uid();
    IF v_calling_user IS NULL THEN
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado.';
    END IF;

    -- 2. Valida titularidade do alerta do pet perdido de origem
    SELECT user_id INTO v_owner_user
    FROM public.pet_lost_alerts
    WHERE id = exclude_pet_id;

    IF v_owner_user IS NULL OR v_owner_user <> v_calling_user THEN
        RAISE EXCEPTION 'Acesso não autorizado para o alerta de pet informado.';
    END IF;

    -- 3. Validação defensiva dos parâmetros
    IF query_embedding IS NULL THEN
        RAISE EXCEPTION 'query_embedding não pode ser nulo';
    END IF;

    IF similarity_threshold < 0.0 OR similarity_threshold > 1.0 THEN
        RAISE EXCEPTION 'similarity_threshold deve estar entre 0.0 e 1.0';
    END IF;

    IF match_limit < 1 OR match_limit > 100 THEN
        RAISE EXCEPTION 'match_limit deve estar entre 1 e 100';
    END IF;

    -- 4. Busca vetorial rápida contra pets encontrados ativos da mesma espécie
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

-- 2.2 match_lost_pets_for_found
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
DECLARE
    v_calling_user UUID;
    v_owner_user UUID;
BEGIN
    -- 1. Valida autenticação obrigatória
    v_calling_user := auth.uid();
    IF v_calling_user IS NULL THEN
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado.';
    END IF;

    -- 2. Valida titularidade do alerta do pet encontrado de origem
    SELECT user_id INTO v_owner_user
    FROM public.pet_found_alerts
    WHERE id = exclude_pet_id;

    IF v_owner_user IS NULL OR v_owner_user <> v_calling_user THEN
        RAISE EXCEPTION 'Acesso não autorizado para o alerta de pet informado.';
    END IF;

    -- 3. Validação defensiva dos parâmetros
    IF query_embedding IS NULL THEN
        RAISE EXCEPTION 'query_embedding não pode ser nulo';
    END IF;

    IF similarity_threshold < 0.0 OR similarity_threshold > 1.0 THEN
        RAISE EXCEPTION 'similarity_threshold deve estar entre 0.0 e 1.0';
    END IF;

    IF match_limit < 1 OR match_limit > 100 THEN
        RAISE EXCEPTION 'match_limit deve estar entre 1 e 100';
    END IF;

    -- 4. Busca vetorial rápida contra pets perdidos ativos da mesma espécie
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

-- 2.3 REGRAS DE PERMISSÃO RESTITAS (REVOGA EXECUTE DE ANON E PUBLIC)
REVOKE ALL ON FUNCTION public.match_found_pets_for_lost FROM PUBLIC;
REVOKE ALL ON FUNCTION public.match_lost_pets_for_found FROM PUBLIC;

REVOKE ALL ON FUNCTION public.match_found_pets_for_lost FROM anon;
REVOKE ALL ON FUNCTION public.match_lost_pets_for_found FROM anon;

GRANT EXECUTE ON FUNCTION public.match_found_pets_for_lost TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_lost_pets_for_found TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_found_pets_for_lost TO service_role;
GRANT EXECUTE ON FUNCTION public.match_lost_pets_for_found TO service_role;

-- 3. TRIGGER REFINADO PARA TRANSIÇÃO MANUAL -> AUTOMÁTICO E IDEMPOTÊNCIA
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
    v_should_notify BOOLEAN := FALSE;
BEGIN
    -- Caso 1: Novo registro automático com score suficiente
    IF TG_OP = 'INSERT' AND NEW.origin = 'automatic' AND NEW.similarity_score >= 0.70 THEN
        v_should_notify := TRUE;
    END IF;

    -- Caso 2: Transição de manual para automatic com score suficiente
    IF TG_OP = 'UPDATE' AND (OLD.origin IS DISTINCT FROM 'automatic') AND NEW.origin = 'automatic' AND NEW.similarity_score >= 0.70 THEN
        v_should_notify := TRUE;
    END IF;

    IF v_should_notify THEN
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

DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;

CREATE TRIGGER trg_notify_on_match
AFTER INSERT OR UPDATE OF origin ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_auto_match_notification();
