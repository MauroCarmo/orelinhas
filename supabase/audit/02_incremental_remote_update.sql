-- ==============================================================================
-- ORELINHAS: SCRIPT INCREMENTAL DE ATUALIZAÇÃO DO BANCO REMOTO
-- Arquivo: supabase/audit/02_incremental_remote_update.sql
-- Finalidade: Aplicar exclusivamente as correções estruturais, índices HNSW,
--             RPCs blindadas (search_path = ''), RLS estrito por titularidade,
--             proteção de embeddings e Storage no banco Supabase remoto.
-- Execução: Transacional (BEGIN/COMMIT), idempotente e seguro para o Supabase SQL Editor.
-- ==============================================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '>>> [ORELINHAS] Iniciando aplicação do script incremental...';
END $$;

-- ------------------------------------------------------------------------------
-- 1. EXTENSÃO PGVECTOR
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

-- ------------------------------------------------------------------------------
-- 2. TABELA matches (COLUNA origin, INTEGRIDADE E CHAVES ESTRANGEIRAS)
-- ------------------------------------------------------------------------------

-- 2.1 Adicionar coluna origin com default 'manual'
-- NOTA TÉCNICA: Registros pré-existentes cuja origem não possa ser comprovada 
-- permanecem estritamente como 'manual'. Não forçamos 'automatic' via script.
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS origin VARCHAR(20) NOT NULL DEFAULT 'manual';

-- 2.2 Remoção prévia de correspondências órfãs antes de criar Foreign Keys
-- NOTA TÉCNICA: Usa NOT EXISTS em vez de NOT IN para tratar corretamente valores
-- NULL em lost_pet_id / found_pet_id. NOT IN com subconsulta que contenha NULL
-- retorna UNKNOWN para todas as linhas, impedindo exclusões corretas.
DELETE FROM public.matches m
WHERE NOT EXISTS (SELECT 1 FROM public.pet_lost_alerts pla WHERE pla.id = m.lost_pet_id)
   OR NOT EXISTS (SELECT 1 FROM public.pet_found_alerts pfa WHERE pfa.id = m.found_pet_id);

-- 2.3 Foreign Keys com deleção em cascata (evita órfãos na exclusão de alertas)
-- NOTA TÉCNICA: A verificação inclui conrelid para evitar falso positivo caso
-- outro objeto diferente compartilhe o mesmo nome de constraint em outro schema.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_matches_lost_pet'
          AND conrelid = 'public.matches'::regclass
    ) THEN
        ALTER TABLE public.matches
        ADD CONSTRAINT fk_matches_lost_pet
        FOREIGN KEY (lost_pet_id) REFERENCES public.pet_lost_alerts(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fk_matches_found_pet'
          AND conrelid = 'public.matches'::regclass
    ) THEN
        ALTER TABLE public.matches
        ADD CONSTRAINT fk_matches_found_pet
        FOREIGN KEY (found_pet_id) REFERENCES public.pet_found_alerts(id) ON DELETE CASCADE;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. DEDUPLICAÇÃO DETERMINÍSTICA E CONSTRAINT ÚNICA EM pet_images
-- ------------------------------------------------------------------------------
-- Deduplicação segura: preserva vetores SigLIP válidos de 768d e registros mais recentes
WITH ranked_images AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY pet_id, image_url
            ORDER BY
                (embedding IS NOT NULL AND public.vector_dims(embedding) = 768) DESC,
                created_at DESC,
                id DESC
        ) AS rn
    FROM public.pet_images
)
DELETE FROM public.pet_images
WHERE id IN (
    SELECT id FROM ranked_images WHERE rn > 1
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'uq_pet_images_pet_url'
          AND conrelid = 'public.pet_images'::regclass
    ) THEN
        ALTER TABLE public.pet_images
        ADD CONSTRAINT uq_pet_images_pet_url UNIQUE (pet_id, image_url);
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 4. ÍNDICES VETORIAIS HNSW (PGVECTOR)
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_embedding_hnsw
ON public.pet_visual_profiles
USING hnsw (aggregated_embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_pet_images_embedding_hnsw
ON public.pet_images
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- ------------------------------------------------------------------------------
-- 5. FUNÇÕES DE AUTENTICAÇÃO (SECURITY DEFINER BLINDADAS COM search_path = '')
-- ------------------------------------------------------------------------------

-- 5.1 is_email_locked
CREATE OR REPLACE FUNCTION public.is_email_locked(user_email text) 
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    rec RECORD;
    now_ts TIMESTAMP WITH TIME ZONE := pg_catalog.now();
    rem_seconds INTEGER := 0;
    v_clean_email TEXT;
BEGIN
    v_clean_email := pg_catalog.lower(pg_catalog.trim(user_email));
    IF v_clean_email IS NULL OR v_clean_email = '' THEN
        RETURN pg_catalog.jsonb_build_object('is_locked', false, 'remaining_seconds', 0, 'attempts_count', 0);
    END IF;

    SELECT * INTO rec FROM public.login_attempts WHERE email = v_clean_email;
    IF rec IS NULL THEN
        RETURN pg_catalog.jsonb_build_object('is_locked', false, 'remaining_seconds', 0, 'attempts_count', 0);
    END IF;

    IF rec.locked_until IS NOT NULL AND rec.locked_until > now_ts THEN
        rem_seconds := EXTRACT(epoch FROM (rec.locked_until - now_ts))::INTEGER;
        RETURN pg_catalog.jsonb_build_object('is_locked', true, 'remaining_seconds', rem_seconds, 'attempts_count', rec.attempts_count);
    END IF;

    IF rec.locked_until IS NOT NULL AND rec.locked_until <= now_ts THEN
        UPDATE public.login_attempts
        SET attempts_count = 0, locked_until = NULL, last_attempt_at = now_ts
        WHERE email = v_clean_email;
        RETURN pg_catalog.jsonb_build_object('is_locked', false, 'remaining_seconds', 0, 'attempts_count', 0);
    END IF;

    RETURN pg_catalog.jsonb_build_object('is_locked', false, 'remaining_seconds', 0, 'attempts_count', rec.attempts_count);
END;
$$;

-- 5.2 register_login_attempt
CREATE OR REPLACE FUNCTION public.register_login_attempt(user_email text, is_success boolean) 
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    rec RECORD;
    new_count INTEGER;
    lock_time TIMESTAMP WITH TIME ZONE := NULL;
    now_ts TIMESTAMP WITH TIME ZONE := pg_catalog.now();
    v_clean_email TEXT;
    v_auth_email TEXT;
BEGIN
    v_clean_email := pg_catalog.lower(pg_catalog.trim(user_email));
    IF v_clean_email IS NULL OR v_clean_email = '' THEN
        RETURN pg_catalog.jsonb_build_object('error', 'E-mail inválido');
    END IF;

    -- Sucesso: apenas reseta se o usuário já estiver autenticado no Supabase Auth e o e-mail coincidir
    IF is_success THEN
        IF auth.uid() IS NOT NULL THEN
            SELECT email INTO v_auth_email FROM auth.users WHERE id = auth.uid();
            IF v_auth_email IS NOT NULL AND pg_catalog.lower(v_auth_email) = v_clean_email THEN
                DELETE FROM public.login_attempts WHERE email = v_clean_email;
                RETURN pg_catalog.jsonb_build_object('status', 'reset');
            END IF;
        END IF;
        RETURN pg_catalog.jsonb_build_object('status', 'ignored');
    END IF;

    -- Falha: verifica se o e-mail existe em auth.users para evitar poluição da base com contas inexistentes
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = v_clean_email) THEN
        RETURN pg_catalog.jsonb_build_object('attempts_count', 0, 'is_locked', false);
    END IF;

    SELECT * INTO rec FROM public.login_attempts WHERE email = v_clean_email;
    IF rec IS NULL THEN
        INSERT INTO public.login_attempts (email, attempts_count, last_attempt_at)
        VALUES (v_clean_email, 1, now_ts);
        RETURN pg_catalog.jsonb_build_object('attempts_count', 1, 'is_locked', false);
    END IF;

    IF rec.locked_until IS NOT NULL AND rec.locked_until > now_ts THEN
        RETURN pg_catalog.jsonb_build_object(
            'attempts_count', rec.attempts_count,
            'is_locked', true,
            'remaining_seconds', EXTRACT(epoch FROM (rec.locked_until - now_ts))::INTEGER
        );
    END IF;

    IF rec.locked_until IS NOT NULL AND rec.locked_until <= now_ts THEN
        new_count := 1;
        lock_time := NULL;
    ELSE
        new_count := rec.attempts_count + 1;
    END IF;

    -- Bloqueio após 3 tentativas falhas consecutivas (15 minutos)
    IF new_count >= 3 THEN
        lock_time := now_ts + INTERVAL '15 minutes';
    END IF;

    UPDATE public.login_attempts
    SET attempts_count = new_count, locked_until = lock_time, last_attempt_at = now_ts
    WHERE email = v_clean_email;

    RETURN pg_catalog.jsonb_build_object(
        'attempts_count', new_count,
        'is_locked', (lock_time IS NOT NULL),
        'remaining_seconds', CASE WHEN lock_time IS NOT NULL THEN EXTRACT(epoch FROM (lock_time - now_ts))::INTEGER ELSE 0 END
    );
END;
$$;

-- 5.3 delete_own_user
CREATE OR REPLACE FUNCTION public.delete_own_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado.';
    END IF;

    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. RPCs DE BUSCA VETORIAL BIDIRECIONAL COM DEFESA EM PROFUNDIDADE
-- ------------------------------------------------------------------------------

-- 6.1 match_found_pets_for_lost
-- Consome EXCLUSIVAMENTE o embedding oficial de pet_visual_profiles.
-- Sem fallback de vetores do cliente. Valida titularidade, espécie e status ativo.
CREATE OR REPLACE FUNCTION public.match_found_pets_for_lost(
    query_embedding public.vector(768) DEFAULT NULL,
    target_pet_type character varying DEFAULT NULL,
    exclude_pet_id uuid DEFAULT NULL,
    similarity_threshold double precision DEFAULT 0.70,
    match_limit integer DEFAULT 20
)
RETURNS TABLE (
    pet_id uuid,
    similarity_score double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_calling_user uuid;
    v_source_alert_pet_type character varying(50);
    v_source_alert_status text;
    v_source_embedding public.vector(768);
    v_source_profile_pet_type character varying(50);
    v_normalized_species character varying(50);
BEGIN
    -- 1. Validar autenticação
    v_calling_user := auth.uid();
    IF v_calling_user IS NULL THEN
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado.';
    END IF;

    IF exclude_pet_id IS NULL THEN
        RAISE EXCEPTION 'exclude_pet_id não pode ser nulo.';
    END IF;

    -- 2. Validar titularidade, existência e status ativo do animal de origem em pet_lost_alerts
    SELECT pla.pet_type, pla.status 
    INTO v_source_alert_pet_type, v_source_alert_status
    FROM public.pet_lost_alerts pla
    WHERE pla.id = exclude_pet_id AND pla.user_id = v_calling_user;

    IF v_source_alert_pet_type IS NULL THEN
        RAISE EXCEPTION 'Animal de origem não encontrado ou não pertence ao usuário autenticado.';
    END IF;

    IF v_source_alert_status <> 'active' THEN
        RAISE EXCEPTION 'O alerta do animal de origem não está ativo.';
    END IF;

    v_normalized_species := pg_catalog.lower(pg_catalog.trim(v_source_alert_pet_type));

    -- Validar elegibilidade da espécie (somente cão e gato são elegíveis para IA visual)
    IF v_normalized_species NOT IN ('dog', 'cat') THEN
        RAISE EXCEPTION 'Espécie do animal não é elegível para busca visual por IA.';
    END IF;

    -- Se target_pet_type foi informado, validar consistência
    IF target_pet_type IS NOT NULL AND pg_catalog.lower(pg_catalog.trim(target_pet_type)) <> v_normalized_species THEN
        RAISE EXCEPTION 'Espécie alvo incompatível com a espécie do animal de origem.';
    END IF;

    -- 3. Recuperar EXCLUSIVAMENTE o embedding oficial persistido em pet_visual_profiles
    SELECT pvp.aggregated_embedding, pvp.pet_type 
    INTO v_source_embedding, v_source_profile_pet_type
    FROM public.pet_visual_profiles pvp
    WHERE pvp.pet_id = exclude_pet_id;

    IF v_source_embedding IS NULL THEN
        RAISE EXCEPTION 'Animal de origem não possui perfil visual com embedding oficial persistido.';
    END IF;

    IF public.vector_dims(v_source_embedding) <> 768 THEN
        RAISE EXCEPTION 'Dimensão do embedding oficial inválida. Esperado vetor de 768 dimensões.';
    END IF;

    IF v_source_profile_pet_type IS NOT NULL AND pg_catalog.lower(pg_catalog.trim(v_source_profile_pet_type)) <> v_normalized_species THEN
        RAISE EXCEPTION 'Inconsistência de espécie entre o alerta do animal e seu perfil visual.';
    END IF;

    -- 4. Normalização defensiva de parâmetros de busca
    IF similarity_threshold IS NULL OR similarity_threshold < 0.0 OR similarity_threshold > 1.0 THEN
        similarity_threshold := 0.70;
    END IF;

    IF match_limit IS NULL OR match_limit < 1 OR match_limit > 100 THEN
        match_limit := 20;
    END IF;

    -- 5. Execução da busca vetorial aproximada (pgvector HNSW)
    -- Valida espécie tanto no perfil visual quanto no alerta candidato (pfa.pet_type e pvp.pet_type)
    -- Garante que somente candidatos ativos e elegíveis participem
    RETURN QUERY
    SELECT
        pvp.pet_id,
        (1 - (pvp.aggregated_embedding OPERATOR(public.<=>) v_source_embedding))::double precision AS similarity_score
    FROM public.pet_visual_profiles pvp
    INNER JOIN public.pet_found_alerts pfa ON pfa.id = pvp.pet_id
    WHERE pg_catalog.lower(pg_catalog.trim(pvp.pet_type)) = v_normalized_species
      AND pg_catalog.lower(pg_catalog.trim(pfa.pet_type)) = v_normalized_species
      AND pfa.status = 'active'
      AND pvp.pet_id <> exclude_pet_id
      AND pvp.aggregated_embedding IS NOT NULL
      AND (1 - (pvp.aggregated_embedding OPERATOR(public.<=>) v_source_embedding)) >= similarity_threshold
    ORDER BY pvp.aggregated_embedding OPERATOR(public.<=>) v_source_embedding ASC
    LIMIT match_limit;
END;
$$;

-- 6.2 match_lost_pets_for_found
CREATE OR REPLACE FUNCTION public.match_lost_pets_for_found(
    query_embedding public.vector(768) DEFAULT NULL,
    target_pet_type character varying DEFAULT NULL,
    exclude_pet_id uuid DEFAULT NULL,
    similarity_threshold double precision DEFAULT 0.70,
    match_limit integer DEFAULT 20
)
RETURNS TABLE (
    pet_id uuid,
    similarity_score double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_calling_user uuid;
    v_source_alert_pet_type character varying(50);
    v_source_alert_status text;
    v_source_embedding public.vector(768);
    v_source_profile_pet_type character varying(50);
    v_normalized_species character varying(50);
BEGIN
    -- 1. Validar autenticação
    v_calling_user := auth.uid();
    IF v_calling_user IS NULL THEN
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado.';
    END IF;

    IF exclude_pet_id IS NULL THEN
        RAISE EXCEPTION 'exclude_pet_id não pode ser nulo.';
    END IF;

    -- 2. Validar titularidade, existência e status ativo do animal de origem em pet_found_alerts
    SELECT pfa.pet_type, pfa.status 
    INTO v_source_alert_pet_type, v_source_alert_status
    FROM public.pet_found_alerts pfa
    WHERE pfa.id = exclude_pet_id AND pfa.user_id = v_calling_user;

    IF v_source_alert_pet_type IS NULL THEN
        RAISE EXCEPTION 'Animal de origem não encontrado ou não pertence ao usuário autenticado.';
    END IF;

    IF v_source_alert_status <> 'active' THEN
        RAISE EXCEPTION 'O alerta do animal de origem não está ativo.';
    END IF;

    v_normalized_species := pg_catalog.lower(pg_catalog.trim(v_source_alert_pet_type));

    -- Validar elegibilidade da espécie
    IF v_normalized_species NOT IN ('dog', 'cat') THEN
        RAISE EXCEPTION 'Espécie do animal não é elegível para busca visual por IA.';
    END IF;

    -- Validar compatibilidade de espécie
    IF target_pet_type IS NOT NULL AND pg_catalog.lower(pg_catalog.trim(target_pet_type)) <> v_normalized_species THEN
        RAISE EXCEPTION 'Espécie alvo incompatível com a espécie do animal de origem.';
    END IF;

    -- 3. Recuperar EXCLUSIVAMENTE o embedding oficial persistido
    SELECT pvp.aggregated_embedding, pvp.pet_type 
    INTO v_source_embedding, v_source_profile_pet_type
    FROM public.pet_visual_profiles pvp
    WHERE pvp.pet_id = exclude_pet_id;

    IF v_source_embedding IS NULL THEN
        RAISE EXCEPTION 'Animal de origem não possui perfil visual com embedding oficial persistido.';
    END IF;

    IF public.vector_dims(v_source_embedding) <> 768 THEN
        RAISE EXCEPTION 'Dimensão do embedding oficial inválida. Esperado vetor de 768 dimensões.';
    END IF;

    IF v_source_profile_pet_type IS NOT NULL AND pg_catalog.lower(pg_catalog.trim(v_source_profile_pet_type)) <> v_normalized_species THEN
        RAISE EXCEPTION 'Inconsistência de espécie entre o alerta do animal e seu perfil visual.';
    END IF;

    -- 4. Normalização defensiva de parâmetros
    IF similarity_threshold IS NULL OR similarity_threshold < 0.0 OR similarity_threshold > 1.0 THEN
        similarity_threshold := 0.70;
    END IF;

    IF match_limit IS NULL OR match_limit < 1 OR match_limit > 100 THEN
        match_limit := 20;
    END IF;

    -- 5. Busca vetorial
    RETURN QUERY
    SELECT
        pvp.pet_id,
        (1 - (pvp.aggregated_embedding OPERATOR(public.<=>) v_source_embedding))::double precision AS similarity_score
    FROM public.pet_visual_profiles pvp
    INNER JOIN public.pet_lost_alerts pla ON pla.id = pvp.pet_id
    WHERE pg_catalog.lower(pg_catalog.trim(pvp.pet_type)) = v_normalized_species
      AND pg_catalog.lower(pg_catalog.trim(pla.pet_type)) = v_normalized_species
      AND pla.status = 'active'
      AND pvp.pet_id <> exclude_pet_id
      AND pvp.aggregated_embedding IS NOT NULL
      AND (1 - (pvp.aggregated_embedding OPERATOR(public.<=>) v_source_embedding)) >= similarity_threshold
    ORDER BY pvp.aggregated_embedding OPERATOR(public.<=>) v_source_embedding ASC
    LIMIT match_limit;
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. ATUALIZAÇÃO DA TRIGGER FUNCTION DE NOTIFICAÇÃO
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_auto_match_notification()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_owner_user_id uuid;
    v_lost_pet_name text;
    v_found_location text;
    v_found_image_url text;
    v_found_breed text;
    v_score_percentage text;
    v_should_notify boolean := false;
BEGIN
    IF TG_OP = 'INSERT' AND NEW.origin = 'automatic' AND NEW.similarity_score >= 0.70 THEN
        v_should_notify := true;
    END IF;

    IF TG_OP = 'UPDATE' AND (OLD.origin IS DISTINCT FROM 'automatic') AND NEW.origin = 'automatic' AND NEW.similarity_score >= 0.70 THEN
        v_should_notify := true;
    END IF;

    IF v_should_notify THEN
        SELECT user_id, pet_name 
        INTO v_owner_user_id, v_lost_pet_name
        FROM public.pet_lost_alerts 
        WHERE id = NEW.lost_pet_id;

        SELECT found_location, image_url, breed
        INTO v_found_location, v_found_image_url, v_found_breed
        FROM public.pet_found_alerts 
        WHERE id = NEW.found_pet_id;

        IF v_owner_user_id IS NOT NULL THEN
            v_score_percentage := pg_catalog.to_char(pg_catalog.round((NEW.similarity_score * 100)::numeric, 1), 'FM990.0') || '%';
            
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
                false,
                NEW.lost_pet_id,
                NEW.found_pet_id,
                pg_catalog.jsonb_build_object(
                    'match_id', NEW.id,
                    'similarity_score', NEW.similarity_score,
                    'lost_pet_id', NEW.lost_pet_id,
                    'found_pet_id', NEW.found_pet_id,
                    'found_pet_image_url', v_found_image_url,
                    'found_pet_breed', v_found_breed,
                    'origin', NEW.origin
                ),
                pg_catalog.now()
            )
            ON CONFLICT (user_id, related_pet_id, related_match_id) 
            WHERE type = 'match_found' 
              AND related_pet_id IS NOT NULL 
              AND related_match_id IS NOT NULL
            DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;
CREATE TRIGGER trg_notify_on_match
AFTER INSERT OR UPDATE OF origin ON public.matches
FOR EACH ROW EXECUTE FUNCTION public.handle_auto_match_notification();

-- ------------------------------------------------------------------------------
-- 8. PERMISSÕES E GRANTS EXPLÍCITOS
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.match_found_pets_for_lost(public.vector(768), character varying, uuid, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_found_pets_for_lost(public.vector(768), character varying, uuid, double precision, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.match_lost_pets_for_found(public.vector(768), character varying, uuid, double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_lost_pets_for_found(public.vector(768), character varying, uuid, double precision, integer) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.delete_own_user() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_own_user() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.is_email_locked(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_email_locked(text) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.register_login_attempt(text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_login_attempt(text, boolean) TO anon, authenticated, service_role;

-- Revoga acesso público de anon às tabelas de embeddings internos
REVOKE ALL ON public.pet_images FROM anon;
REVOKE ALL ON public.pet_visual_profiles FROM anon;

-- ------------------------------------------------------------------------------
-- 9. SANEAMENTO E REFORÇO DE POLÍTICAS ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------

-- 9.1 profiles: Revogar política permissiva que expõe dados cadastrais de terceiros
DROP POLICY IF EXISTS "Qualquer usuário autenticado pode ver perfis" ON public.profiles;

-- 9.2 pet_images: Proteção de embeddings e mutação restrita ao titular
DROP POLICY IF EXISTS "pet_images_select_public" ON public.pet_images;
DROP POLICY IF EXISTS "pet_images_select_owner" ON public.pet_images;
CREATE POLICY "pet_images_select_owner" ON public.pet_images
FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
);

DROP POLICY IF EXISTS "pet_images_insert_authenticated" ON public.pet_images;
DROP POLICY IF EXISTS "pet_images_update_authenticated" ON public.pet_images;
DROP POLICY IF EXISTS "pet_images_delete_authenticated" ON public.pet_images;
DROP POLICY IF EXISTS "pet_images_insert_owner" ON public.pet_images;
DROP POLICY IF EXISTS "pet_images_update_owner" ON public.pet_images;
DROP POLICY IF EXISTS "pet_images_delete_owner" ON public.pet_images;

CREATE POLICY "pet_images_insert_owner" ON public.pet_images
FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    )
);

CREATE POLICY "pet_images_update_owner" ON public.pet_images
FOR UPDATE USING (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    )
) WITH CHECK (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    )
);

CREATE POLICY "pet_images_delete_owner" ON public.pet_images
FOR DELETE USING (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    )
);

-- 9.3 pet_visual_profiles: Leitura para autenticados; mutação restrita ao titular
-- DECISÃO ARQUITETURAL (SELECT USING true):
-- O pipeline de reconhecimento visual do Flutter lê perfis de outros usuários legitimamente
-- (getVisualProfile, getVisualProfilesByIds) para calcular similaridade de candidatos
-- retornados pelas RPCs pgvector. Restringir o SELECT ao próprio dono quebraria
-- completamente o matching. Essa decisão é um trade-off deliberado: embeddings de
-- outros usuários ficam visíveis para qualquer autenticado via API direta.
-- Mitigação existente: (1) RPCs SECURITY DEFINER consomem embedding apenas da base,
-- sem aceitar vetor do cliente; (2) REVOKE ALL FROM anon impede acesso não autenticado.
-- Para proteção adicional futura considerar: view sem coluna aggregated_embedding
-- + GRANT somente na view para leitura pública, mantendo acesso direto via service_role.
DROP POLICY IF EXISTS "pet_visual_profiles_select_public" ON public.pet_visual_profiles;
DROP POLICY IF EXISTS "pet_visual_profiles_select_authenticated" ON public.pet_visual_profiles;
CREATE POLICY "pet_visual_profiles_select_authenticated" ON public.pet_visual_profiles
FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "pet_visual_profiles_all_authenticated" ON public.pet_visual_profiles;
DROP POLICY IF EXISTS "pet_visual_profiles_manage_owner" ON public.pet_visual_profiles;

CREATE POLICY "pet_visual_profiles_manage_owner" ON public.pet_visual_profiles
FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
) WITH CHECK (
    EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
);

-- 9.4 matches: Leitura restrita aos titulares envolvidos (lost_pet_id ou found_pet_id)
-- Inserção e atualização restrita ao titular de ao menos um dos pets envolvidos
-- DECISÃO ARQUITETURAL (INSERT/UPDATE com OR):
-- O Flutter chama saveMatch diretamente (cliente autenticado), tanto para buscas manuais
-- quanto automáticas — origem determinada pelo parâmetro 'origin'. Exigir propriedade
-- dos DOIS animais bloquearia o caso central: o dono do pet perdido salva correspondências
-- com pets encontrados de outros usuários. A política atual (OR) permite isso
-- intencionalmente. RISCO RESIDUAL: um usuário pode associar seu pet a qualquer
-- found_pet_id válido. Mitigação futura recomendada: mover saveMatch para uma RPC
-- SECURITY DEFINER ou Edge Function que valide a origem do match antes da persistência,
-- removendo o INSERT direto do cliente e substituindo por service_role apenas.
DROP POLICY IF EXISTS "matches_select_public" ON public.matches;
DROP POLICY IF EXISTS "matches_select_authenticated" ON public.matches;
DROP POLICY IF EXISTS "matches_select_involved_owner" ON public.matches;
CREATE POLICY "matches_select_involved_owner" ON public.matches
FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = lost_pet_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = found_pet_id AND user_id = auth.uid())
);

DROP POLICY IF EXISTS "matches_insert_authenticated" ON public.matches;
DROP POLICY IF EXISTS "matches_update_authenticated" ON public.matches;
DROP POLICY IF EXISTS "matches_insert_owner" ON public.matches;
DROP POLICY IF EXISTS "matches_update_owner" ON public.matches;

CREATE POLICY "matches_insert_owner" ON public.matches
FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = lost_pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = found_pet_id AND user_id = auth.uid())
    )
);

CREATE POLICY "matches_update_owner" ON public.matches
FOR UPDATE USING (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = lost_pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = found_pet_id AND user_id = auth.uid())
    )
) WITH CHECK (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = lost_pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = found_pet_id AND user_id = auth.uid())
    )
);

-- 9.5 notifications: Revogação de inserção direta por clientes
DROP POLICY IF EXISTS "notifications_insert_authenticated" ON public.notifications;

-- ------------------------------------------------------------------------------
-- 10. STORAGE (CONFIGURAÇÃO DEFENSIVA DE BUCKETS E POLÍTICAS)
-- ------------------------------------------------------------------------------
-- Preserva configuração existente sem forçar public = true compulsoriamente
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pet_images',
    'pet_images',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Remoção preventiva de políticas legadas
DROP POLICY IF EXISTS "Imagens de pets sao publicas" ON storage.objects;
DROP POLICY IF EXISTS "Qualquer pessoa pode ver imagens de pets" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios autenticados podem enviar imagens de pets" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem enviar imagens de pets" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios podem atualizar e deletar suas fotos de pets" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem gerenciar suas próprias imagens" ON storage.objects;
DROP POLICY IF EXISTS "storage_pet_images_select_public" ON storage.objects;
DROP POLICY IF EXISTS "storage_pet_images_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "storage_pet_images_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "storage_pet_images_delete_owner" ON storage.objects;

DROP POLICY IF EXISTS "Avatares sao publicos" ON storage.objects;
DROP POLICY IF EXISTS "Qualquer pessoa pode ver avatares" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios podem enviar seu avatar" ON storage.objects;
DROP POLICY IF EXISTS "Usuários podem enviar seus avatares" ON storage.objects;
DROP POLICY IF EXISTS "Usuarios gerenciam seu proprio avatar" ON storage.objects;
DROP POLICY IF EXISTS "Usuários gerenciam seus avatares" ON storage.objects;
DROP POLICY IF EXISTS "storage_avatars_select_public" ON storage.objects;
DROP POLICY IF EXISTS "storage_avatars_insert_owner" ON storage.objects;
DROP POLICY IF EXISTS "storage_avatars_update_owner" ON storage.objects;
DROP POLICY IF EXISTS "storage_avatars_delete_owner" ON storage.objects;

-- Políticas de Storage para pet_images
CREATE POLICY "storage_pet_images_select_public" ON storage.objects
FOR SELECT USING (bucket_id = 'pet_images');

CREATE POLICY "storage_pet_images_insert_owner" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'pet_images'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
);

CREATE POLICY "storage_pet_images_update_owner" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'pet_images'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
) WITH CHECK (
    bucket_id = 'pet_images'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
);

CREATE POLICY "storage_pet_images_delete_owner" ON storage.objects
FOR DELETE USING (
    bucket_id = 'pet_images'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Políticas de Storage para avatars
CREATE POLICY "storage_avatars_select_public" ON storage.objects
FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "storage_avatars_insert_owner" ON storage.objects
FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
);

CREATE POLICY "storage_avatars_update_owner" ON storage.objects
FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
) WITH CHECK (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp')
);

CREATE POLICY "storage_avatars_delete_owner" ON storage.objects
FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '>>> [ORELINHAS] Script incremental concluído com sucesso e consolidado no banco remoto!';
END $$;
