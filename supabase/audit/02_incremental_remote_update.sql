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

-- 2.1 Adicionar coluna origin com default 'manual' e updated_at
-- NOTA TÉCNICA: Registros pré-existentes cuja origem não possa ser comprovada 
-- permanecem estritamente como 'manual'. Não forçamos 'automatic' via script.
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS origin VARCHAR(20) NOT NULL DEFAULT 'manual';

ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

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
-- 5. RPCs DE BUSCA VETORIAL BIDIRECIONAL COM DEFESA EM PROFUNDIDADE
-- ------------------------------------------------------------------------------

-- Função interna auxiliar para cálculo estrito da fórmula oficial
-- Ordem canônica invariante: primeiro argumento = lost_pet, segundo argumento = found_pet
CREATE OR REPLACE FUNCTION public.calculate_match_score(
    p_lost_pet_id uuid,
    p_found_pet_id uuid
)
RETURNS TABLE (
    score double precision,
    individual_scores jsonb,
    match_method text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_lost_profile public.pet_visual_profiles%ROWTYPE;
    v_found_profile public.pet_visual_profiles%ROWTYPE;
    v_agg_similarity double precision := NULL;
    v_pair_similarities double precision[] := ARRAY[]::double precision[];
    v_max_sim double precision := 0.0;
    v_avg_sim double precision := 0.0;
    v_calculated_score double precision := 0.0;
    v_lost_emb public.vector(768);
    v_found_emb public.vector(768);
    v_best_for_lost double precision;
    v_sim double precision;
    v_sum_pairs double precision := 0.0;
    v_count_pairs integer := 0;
    v_lost_has_images boolean := false;
    v_found_has_images boolean := false;
BEGIN
    SELECT * INTO v_lost_profile FROM public.pet_visual_profiles WHERE pet_id = p_lost_pet_id;
    SELECT * INTO v_found_profile FROM public.pet_visual_profiles WHERE pet_id = p_found_pet_id;

    -- 1. Similaridade agregada (se ambos tiverem embedding agregado válido de 768d)
    IF v_lost_profile.aggregated_embedding IS NOT NULL
       AND v_found_profile.aggregated_embedding IS NOT NULL
       AND public.vector_dims(v_lost_profile.aggregated_embedding) = 768
       AND public.vector_dims(v_found_profile.aggregated_embedding) = 768
    THEN
        v_agg_similarity := 1.0 - (v_lost_profile.aggregated_embedding OPERATOR(public.<=>) v_found_profile.aggregated_embedding);
    END IF;

    -- 2. Verifica se ambos os animais possuem pelo menos uma imagem com embedding válido de 768d
    SELECT EXISTS (
        SELECT 1 FROM public.pet_images
        WHERE pet_id = p_lost_pet_id
          AND embedding IS NOT NULL
          AND public.vector_dims(embedding) = 768
    ) INTO v_lost_has_images;

    SELECT EXISTS (
        SELECT 1 FROM public.pet_images
        WHERE pet_id = p_found_pet_id
          AND embedding IS NOT NULL
          AND public.vector_dims(embedding) = 768
    ) INTO v_found_has_images;

    -- 3. Cálculo multi-vetor: executado SOMENTE quando ambos possuem imagens individuais válidas
    IF v_lost_has_images AND v_found_has_images THEN
        FOR v_lost_emb IN
            SELECT pi.embedding
            FROM public.pet_images pi
            WHERE pi.pet_id = p_lost_pet_id
              AND pi.embedding IS NOT NULL
              AND public.vector_dims(pi.embedding) = 768
        LOOP
            v_best_for_lost := 0.0;
            FOR v_found_emb IN
                SELECT pi2.embedding
                FROM public.pet_images pi2
                WHERE pi2.pet_id = p_found_pet_id
                  AND pi2.embedding IS NOT NULL
                  AND public.vector_dims(pi2.embedding) = 768
            LOOP
                v_sim := 1.0 - (v_lost_emb OPERATOR(public.<=>) v_found_emb);
                IF v_sim > v_best_for_lost THEN
                    v_best_for_lost := v_sim;
                END IF;
            END LOOP;

            -- Registra a melhor similaridade (incluindo 0.0, espelhando VectorMath.computeDetailedMatchScore)
            v_pair_similarities := array_append(v_pair_similarities, v_best_for_lost);
            v_sum_pairs := v_sum_pairs + v_best_for_lost;
            v_count_pairs := v_count_pairs + 1;
            IF v_best_for_lost > v_max_sim THEN
                v_max_sim := v_best_for_lost;
            END IF;
        END LOOP;
    END IF;

    -- 4. Aplicação da fórmula oficial conforme disponibilidade de embeddings:
    -- Cenário A: Ambos possuem imagens individuais válidas
    IF v_count_pairs > 0 THEN
        v_avg_sim := v_sum_pairs / v_count_pairs;
        IF v_agg_similarity IS NOT NULL AND v_agg_similarity > 0.0 THEN
            -- 50% max individual + 30% média + 20% agregado
            v_calculated_score := (0.50 * v_max_sim + 0.30 * v_avg_sim + 0.20 * v_agg_similarity);
        ELSE
            -- Sem agregado válido: 60% max individual + 40% média
            v_calculated_score := (0.60 * v_max_sim + 0.40 * v_avg_sim);
        END IF;
        match_method := 'visual_multi_vector';

    -- Cenário B: Não há pares individuais válidos, mas há similaridade agregada
    ELSIF v_agg_similarity IS NOT NULL THEN
        v_calculated_score := v_agg_similarity;
        v_pair_similarities := ARRAY[v_agg_similarity];
        match_method := 'visual_single_vector';

    -- Cenário C: Nenhum embedding válido suficiente
    ELSE
        v_calculated_score := 0.0;
        match_method := 'insufficient_embeddings';
    END IF;

    score := GREATEST(0.0, LEAST(1.0, v_calculated_score));
    individual_scores := pg_catalog.to_jsonb(v_pair_similarities);
    RETURN NEXT;
END;
$$;

-- 5.1 match_found_pets_for_lost
-- Ordem canônica: lost_pet = v_source_id, found_pet = pfa.id
DROP FUNCTION IF EXISTS public.match_found_pets_for_lost(uuid, character varying, uuid, double precision, integer, public.vector);
DROP FUNCTION IF EXISTS public.match_found_pets_for_lost(public.vector, character varying, uuid, double precision, integer);
DROP FUNCTION IF EXISTS public.match_found_pets_for_lost(uuid, character varying, uuid, double precision, integer);
DROP FUNCTION IF EXISTS public.match_found_pets_for_lost(uuid, character varying, uuid, double precision, integer, uuid);

CREATE OR REPLACE FUNCTION public.match_found_pets_for_lost(
    p_source_pet_id uuid DEFAULT NULL,
    target_pet_type character varying DEFAULT NULL,
    exclude_pet_id uuid DEFAULT NULL,
    similarity_threshold double precision DEFAULT 0.88,
    match_limit integer DEFAULT 20,
    p_user_id uuid DEFAULT NULL
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
    v_session_user uuid;
    v_session_role text;
    v_calling_user uuid;
    v_source_id uuid;
    v_source_alert_pet_type character varying(50);
    v_source_alert_status text;
    v_normalized_species character varying(50);
    v_norm_threshold double precision;
    v_norm_limit integer;
    v_source_has_embeddings boolean := false;
BEGIN
    v_source_id := COALESCE(p_source_pet_id, exclude_pet_id);
    IF v_source_id IS NULL THEN
        RAISE EXCEPTION 'ID do animal de origem não pode ser nulo.' USING ERRCODE = 'P0002';
    END IF;

    -- 1. Validar autenticação e autorização de sessão
    v_session_user := auth.uid();
    v_session_role := auth.role();

    IF v_session_role = 'service_role' THEN
        IF p_user_id IS NOT NULL THEN
            v_calling_user := p_user_id;
        ELSE
            SELECT pla.user_id INTO v_calling_user
            FROM public.pet_lost_alerts pla
            WHERE pla.id = v_source_id;
        END IF;
    ELSIF v_session_role = 'authenticated' OR v_session_user IS NOT NULL THEN
        IF p_user_id IS NOT NULL AND p_user_id <> v_session_user THEN
            RAISE EXCEPTION 'Acesso negado: p_user_id informado diverge do usuário autenticado.' USING ERRCODE = '42501';
        END IF;
        v_calling_user := v_session_user;
    ELSE
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado ou service_role.' USING ERRCODE = '42501';
    END IF;

    IF v_calling_user IS NULL THEN
        RAISE EXCEPTION 'Não foi possível determinar o usuário autenticado.' USING ERRCODE = 'P0001';
    END IF;

    -- 2. Validar titularidade, existência e status ativo do animal de origem em pet_lost_alerts
    SELECT pla.pet_type, pla.status 
    INTO v_source_alert_pet_type, v_source_alert_status
    FROM public.pet_lost_alerts pla
    WHERE pla.id = v_source_id AND pla.user_id = v_calling_user;

    IF v_source_alert_pet_type IS NULL THEN
        RAISE EXCEPTION 'Animal de origem não encontrado ou não pertence ao usuário autenticado.' USING ERRCODE = 'P0003';
    END IF;

    IF v_source_alert_status <> 'active' THEN
        RAISE EXCEPTION 'O alerta do animal de origem não está ativo.' USING ERRCODE = 'P0004';
    END IF;

    v_normalized_species := pg_catalog.lower(pg_catalog.btrim(v_source_alert_pet_type));

    IF v_normalized_species NOT IN ('dog', 'cat') THEN
        RAISE EXCEPTION 'Espécie do animal não é elegível para busca visual por IA.' USING ERRCODE = 'P0005';
    END IF;

    IF target_pet_type IS NOT NULL AND pg_catalog.lower(pg_catalog.btrim(target_pet_type)) <> v_normalized_species THEN
        RAISE EXCEPTION 'Espécie alvo incompatível com a espécie do animal de origem.' USING ERRCODE = 'P0006';
    END IF;

    -- 3. Validar se o animal de origem possui perfil visual com embeddings válidos (agregado OU individuais)
    SELECT EXISTS (
        SELECT 1 FROM public.pet_visual_profiles pvp
        WHERE pvp.pet_id = v_source_id
          AND pvp.aggregated_embedding IS NOT NULL
          AND public.vector_dims(pvp.aggregated_embedding) = 768
    ) OR EXISTS (
        SELECT 1 FROM public.pet_images pi
        WHERE pi.pet_id = v_source_id
          AND pi.embedding IS NOT NULL
          AND public.vector_dims(pi.embedding) = 768
    ) INTO v_source_has_embeddings;

    IF NOT v_source_has_embeddings THEN
        RAISE EXCEPTION 'Animal de origem não possui embeddings visuais válidos de 768 dimensões.' USING ERRCODE = 'P0007';
    END IF;

    -- 4. Normalização defensiva de parâmetros de busca
    -- Limiar fixo e inviolável no servidor: 0.88
    v_norm_threshold := 0.88;

    v_norm_limit := COALESCE(match_limit, 20);
    IF v_norm_limit < 1 OR v_norm_limit > 100 THEN
        v_norm_limit := 20;
    END IF;

    -- 5 & 6. Persistência atômica via CTE sem tabelas temporárias
    -- Ordem canônica de chamada: calculate_match_score(lost_pet_id, found_pet_id)
    RETURN QUERY
    WITH ranked AS (
        SELECT
            v_source_id AS lost_id,
            pfa.id AS found_id,
            ms.score AS calc_score,
            ms.match_method AS calc_method,
            ms.individual_scores AS calc_individual
        FROM public.pet_found_alerts pfa
        CROSS JOIN LATERAL public.calculate_match_score(v_source_id, pfa.id) ms
        WHERE pg_catalog.lower(pg_catalog.btrim(pfa.pet_type)) = v_normalized_species
          AND pfa.status = 'active'
          AND pfa.id <> v_source_id
          AND pfa.user_id <> v_calling_user
          AND ms.score >= v_norm_threshold
        ORDER BY ms.score DESC, pfa.id ASC
        LIMIT v_norm_limit
    ),
    upserted AS (
        INSERT INTO public.matches (
            lost_pet_id,
            found_pet_id,
            similarity_score,
            match_method,
            status,
            origin,
            individual_scores,
            created_at,
            updated_at
        )
        SELECT
            r.lost_id,
            r.found_id,
            r.calc_score,
            r.calc_method,
            'pending',
            'automatic',
            r.calc_individual,
            NOW(),
            NOW()
        FROM ranked r
        ON CONFLICT (lost_pet_id, found_pet_id) DO UPDATE SET
            similarity_score = GREATEST(public.matches.similarity_score, EXCLUDED.similarity_score),
            match_method = CASE
                WHEN EXCLUDED.similarity_score >= public.matches.similarity_score THEN EXCLUDED.match_method
                ELSE public.matches.match_method
            END,
            individual_scores = CASE
                WHEN EXCLUDED.similarity_score >= public.matches.similarity_score THEN EXCLUDED.individual_scores
                ELSE public.matches.individual_scores
            END,
            origin = 'automatic',
            updated_at = NOW()
        RETURNING matches.found_pet_id AS ret_pet_id, matches.similarity_score AS ret_score
    )
    SELECT u.ret_pet_id AS pet_id, u.ret_score AS similarity_score
    FROM upserted u
    ORDER BY u.ret_score DESC, u.ret_pet_id ASC;
END;
$$;

-- 5.2 match_lost_pets_for_found
-- Ordem canônica: lost_pet = pla.id, found_pet = v_source_id
DROP FUNCTION IF EXISTS public.match_lost_pets_for_found(uuid, character varying, uuid, double precision, integer, public.vector);
DROP FUNCTION IF EXISTS public.match_lost_pets_for_found(public.vector, character varying, uuid, double precision, integer);
DROP FUNCTION IF EXISTS public.match_lost_pets_for_found(uuid, character varying, uuid, double precision, integer);
DROP FUNCTION IF EXISTS public.match_lost_pets_for_found(uuid, character varying, uuid, double precision, integer, uuid);

CREATE OR REPLACE FUNCTION public.match_lost_pets_for_found(
    p_source_pet_id uuid DEFAULT NULL,
    target_pet_type character varying DEFAULT NULL,
    exclude_pet_id uuid DEFAULT NULL,
    similarity_threshold double precision DEFAULT 0.88,
    match_limit integer DEFAULT 20,
    p_user_id uuid DEFAULT NULL
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
    v_session_user uuid;
    v_session_role text;
    v_calling_user uuid;
    v_source_id uuid;
    v_source_alert_pet_type character varying(50);
    v_source_alert_status text;
    v_normalized_species character varying(50);
    v_norm_threshold double precision;
    v_norm_limit integer;
    v_source_has_embeddings boolean := false;
BEGIN
    v_source_id := COALESCE(p_source_pet_id, exclude_pet_id);
    IF v_source_id IS NULL THEN
        RAISE EXCEPTION 'ID do animal de origem não pode ser nulo.' USING ERRCODE = 'P0002';
    END IF;

    -- 1. Validar autenticação e autorização de sessão
    v_session_user := auth.uid();
    v_session_role := auth.role();

    IF v_session_role = 'service_role' THEN
        IF p_user_id IS NOT NULL THEN
            v_calling_user := p_user_id;
        ELSE
            SELECT pfa.user_id INTO v_calling_user
            FROM public.pet_found_alerts pfa
            WHERE pfa.id = v_source_id;
        END IF;
    ELSIF v_session_role = 'authenticated' OR v_session_user IS NOT NULL THEN
        IF p_user_id IS NOT NULL AND p_user_id <> v_session_user THEN
            RAISE EXCEPTION 'Acesso negado: p_user_id informado diverge do usuário autenticado.' USING ERRCODE = '42501';
        END IF;
        v_calling_user := v_session_user;
    ELSE
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado ou service_role.' USING ERRCODE = '42501';
    END IF;

    IF v_calling_user IS NULL THEN
        RAISE EXCEPTION 'Não foi possível determinar o usuário autenticado.' USING ERRCODE = 'P0001';
    END IF;

    -- 2. Validar titularidade, existência e status ativo do animal de origem em pet_found_alerts
    SELECT pfa.pet_type, pfa.status 
    INTO v_source_alert_pet_type, v_source_alert_status
    FROM public.pet_found_alerts pfa
    WHERE pfa.id = v_source_id AND pfa.user_id = v_calling_user;

    IF v_source_alert_pet_type IS NULL THEN
        RAISE EXCEPTION 'Animal de origem não encontrado ou não pertence ao usuário autenticado.' USING ERRCODE = 'P0003';
    END IF;

    IF v_source_alert_status <> 'active' THEN
        RAISE EXCEPTION 'O alerta do animal de origem não está ativo.' USING ERRCODE = 'P0004';
    END IF;

    v_normalized_species := pg_catalog.lower(pg_catalog.btrim(v_source_alert_pet_type));

    IF v_normalized_species NOT IN ('dog', 'cat') THEN
        RAISE EXCEPTION 'Espécie do animal não é elegível para busca visual por IA.' USING ERRCODE = 'P0005';
    END IF;

    IF target_pet_type IS NOT NULL AND pg_catalog.lower(pg_catalog.btrim(target_pet_type)) <> v_normalized_species THEN
        RAISE EXCEPTION 'Espécie alvo incompatível com a espécie do animal de origem.' USING ERRCODE = 'P0006';
    END IF;

    -- 3. Validar se o animal de origem possui perfil visual com embeddings válidos (agregado OU individuais)
    SELECT EXISTS (
        SELECT 1 FROM public.pet_visual_profiles pvp
        WHERE pvp.pet_id = v_source_id
          AND pvp.aggregated_embedding IS NOT NULL
          AND public.vector_dims(pvp.aggregated_embedding) = 768
    ) OR EXISTS (
        SELECT 1 FROM public.pet_images pi
        WHERE pi.pet_id = v_source_id
          AND pi.embedding IS NOT NULL
          AND public.vector_dims(pi.embedding) = 768
    ) INTO v_source_has_embeddings;

    IF NOT v_source_has_embeddings THEN
        RAISE EXCEPTION 'Animal de origem não possui embeddings visuais válidos de 768 dimensões.' USING ERRCODE = 'P0007';
    END IF;

    -- 4. Normalização defensiva de parâmetros
    -- Limiar fixo e inviolável no servidor: 0.88
    v_norm_threshold := 0.88;

    v_norm_limit := COALESCE(match_limit, 20);
    IF v_norm_limit < 1 OR v_norm_limit > 100 THEN
        v_norm_limit := 20;
    END IF;

    -- 5 & 6. Persistência atômica via CTE sem tabelas temporárias
    -- Ordem canônica de chamada: calculate_match_score(lost_pet_id, found_pet_id) -> pla.id é lost, v_source_id é found
    RETURN QUERY
    WITH ranked AS (
        SELECT
            pla.id AS lost_id,
            v_source_id AS found_id,
            ms.score AS calc_score,
            ms.match_method AS calc_method,
            ms.individual_scores AS calc_individual
        FROM public.pet_lost_alerts pla
        CROSS JOIN LATERAL public.calculate_match_score(pla.id, v_source_id) ms
        WHERE pg_catalog.lower(pg_catalog.btrim(pla.pet_type)) = v_normalized_species
          AND pla.status = 'active'
          AND pla.id <> v_source_id
          AND pla.user_id <> v_calling_user
          AND ms.score >= v_norm_threshold
        ORDER BY ms.score DESC, pla.id ASC
        LIMIT v_norm_limit
    ),
    upserted AS (
        INSERT INTO public.matches (
            lost_pet_id,
            found_pet_id,
            similarity_score,
            match_method,
            status,
            origin,
            individual_scores,
            created_at,
            updated_at
        )
        SELECT
            r.lost_id,
            r.found_id,
            r.calc_score,
            r.calc_method,
            'pending',
            'automatic',
            r.calc_individual,
            NOW(),
            NOW()
        FROM ranked r
        ON CONFLICT (lost_pet_id, found_pet_id) DO UPDATE SET
            similarity_score = GREATEST(public.matches.similarity_score, EXCLUDED.similarity_score),
            match_method = CASE
                WHEN EXCLUDED.similarity_score >= public.matches.similarity_score THEN EXCLUDED.match_method
                ELSE public.matches.match_method
            END,
            individual_scores = CASE
                WHEN EXCLUDED.similarity_score >= public.matches.similarity_score THEN EXCLUDED.individual_scores
                ELSE public.matches.individual_scores
            END,
            origin = 'automatic',
            updated_at = NOW()
        RETURNING matches.lost_pet_id AS ret_pet_id, matches.similarity_score AS ret_score
    )
    SELECT u.ret_pet_id AS pet_id, u.ret_score AS similarity_score
    FROM upserted u
    ORDER BY u.ret_score DESC, u.ret_pet_id ASC;
END;
$$;

-- ------------------------------------------------------------------------------
-- 5.3 RPC DE PERSISTÊNCIA SEGURA DE CORRESPONDÊNCIAS MANUAIS (save_match)
-- ------------------------------------------------------------------------------
-- SEGURANÇA D1 e D2: Elimina escrita direta no cliente REST/PostgREST.
-- Atribuição estrita de origin = 'manual' (cliente não pode forjar 'automatic').
-- Valida no servidor: autenticação, status dos alertas, espécies e titularidade.
-- Calcula a pontuação oficial usando a fórmula multi-sinal (0.50 maior + 0.30 média + 0.20 agregado).
-- Preserva individual_scores real e idempotência com GREATEST sob concorrência.
CREATE OR REPLACE FUNCTION public.save_match(
    p_lost_pet_id uuid,
    p_found_pet_id uuid,
    p_match_method text DEFAULT 'visual_multi_vector',
    p_similarity_threshold double precision DEFAULT 0.88
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_lost_pet public.pet_lost_alerts%ROWTYPE;
    v_found_pet public.pet_found_alerts%ROWTYPE;
    v_lost_profile public.pet_visual_profiles%ROWTYPE;
    v_found_profile public.pet_visual_profiles%ROWTYPE;
    v_agg_similarity double precision := NULL;
    v_pair_similarities double precision[] := ARRAY[]::double precision[];
    v_max_sim double precision := 0.0;
    v_avg_sim double precision := 0.0;
    v_calculated_score double precision := 0.0;
    v_persisted_score double precision;
    v_persisted_origin text;
    v_match_id uuid;
    v_threshold double precision;
    v_q_emb public.vector(768);
    v_c_emb public.vector(768);
    v_best_for_q double precision;
    v_sim double precision;
    v_sum_pairs double precision := 0.0;
    v_count_pairs integer := 0;
BEGIN
    -- 1. Validar autenticação do chamador
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Acesso negado: operação requer usuário autenticado.' USING ERRCODE = 'P0001';
    END IF;

    -- Normalização e validação de limiar: fixo em 0.88 no servidor
    v_threshold := 0.88;

    -- 2. Validar existência e status ativo do pet perdido
    SELECT * INTO v_lost_pet FROM public.pet_lost_alerts WHERE id = p_lost_pet_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Animal perdido não encontrado.' USING ERRCODE = 'P0002';
    END IF;
    IF v_lost_pet.status <> 'active' THEN
        RAISE EXCEPTION 'O alerta do animal perdido não está ativo.' USING ERRCODE = 'P0003';
    END IF;

    -- 3. Validar existência e status ativo do pet encontrado
    SELECT * INTO v_found_pet FROM public.pet_found_alerts WHERE id = p_found_pet_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Animal encontrado não encontrado.' USING ERRCODE = 'P0004';
    END IF;
    IF v_found_pet.status <> 'active' THEN
        RAISE EXCEPTION 'O alerta do animal encontrado não está ativo.' USING ERRCODE = 'P0005';
    END IF;

    -- 4. Validar compatibilidade estrita de espécies (cão != gato)
    IF pg_catalog.lower(pg_catalog.btrim(v_lost_pet.pet_type)) <> pg_catalog.lower(pg_catalog.btrim(v_found_pet.pet_type)) THEN
        RAISE EXCEPTION 'Incompatibilidade de espécie entre os animais da correspondência.' USING ERRCODE = 'P0006';
    END IF;

    -- 5. Validar titularidade do chamador: DEVE ser o proprietário do lost_pet OU do found_pet
    IF v_lost_pet.user_id <> v_user_id AND v_found_pet.user_id <> v_user_id THEN
        RAISE EXCEPTION 'Usuário não possui titularidade sobre nenhum dos animais envolvidos.' USING ERRCODE = 'P0007';
    END IF;

    -- 6. Validar existência dos perfis visuais oficiais
    SELECT * INTO v_lost_profile FROM public.pet_visual_profiles WHERE pet_id = p_lost_pet_id;
    SELECT * INTO v_found_profile FROM public.pet_visual_profiles WHERE pet_id = p_found_pet_id;

    IF v_lost_profile.pet_id IS NULL OR v_found_profile.pet_id IS NULL THEN
        RAISE EXCEPTION 'Perfis visuais necessários para validação não foram encontrados.' USING ERRCODE = 'P0008';
    END IF;

    -- 7. Calcular similaridade agregada se ambos tiverem embeddings agregados válidos de 768d
    IF v_lost_profile.aggregated_embedding IS NOT NULL
       AND v_found_profile.aggregated_embedding IS NOT NULL
       AND public.vector_dims(v_lost_profile.aggregated_embedding) = 768
       AND public.vector_dims(v_found_profile.aggregated_embedding) = 768
    THEN
        v_agg_similarity := 1.0 - (v_lost_profile.aggregated_embedding OPERATOR(public.<=>) v_found_profile.aggregated_embedding);
    END IF;

    -- 8. Calcular similaridades individuais entre as fotos de pet_images (fórmula oficial do projeto)
    -- SOMENTE se ambos os pets possuírem imagens com embedding válido de 768d
    -- (espelha calculate_match_score e VectorMath.computeDetailedMatchScore)
    IF EXISTS (
        SELECT 1 FROM public.pet_images
        WHERE pet_id = p_lost_pet_id AND embedding IS NOT NULL AND public.vector_dims(embedding) = 768
    ) AND EXISTS (
        SELECT 1 FROM public.pet_images
        WHERE pet_id = p_found_pet_id AND embedding IS NOT NULL AND public.vector_dims(embedding) = 768
    ) THEN
        FOR v_q_emb IN
            SELECT pi.embedding
            FROM public.pet_images pi
            WHERE pi.pet_id = p_lost_pet_id
              AND pi.embedding IS NOT NULL
              AND public.vector_dims(pi.embedding) = 768
        LOOP
            v_best_for_q := 0.0;
            FOR v_c_emb IN
                SELECT pi2.embedding
                FROM public.pet_images pi2
                WHERE pi2.pet_id = p_found_pet_id
                  AND pi2.embedding IS NOT NULL
                  AND public.vector_dims(pi2.embedding) = 768
            LOOP
                v_sim := 1.0 - (v_q_emb OPERATOR(public.<=>) v_c_emb);
                IF v_sim > v_best_for_q THEN
                    v_best_for_q := v_sim;
                END IF;
            END LOOP;

            -- Adiciona SEMPRE (incluindo zero), espelhando VectorMath.computeDetailedMatchScore
            -- (Dart: pairSimilarities.add(bestForQ) incondicionalmente)
            v_pair_similarities := array_append(v_pair_similarities, v_best_for_q);
            v_sum_pairs := v_sum_pairs + v_best_for_q;
            v_count_pairs := v_count_pairs + 1;
            IF v_best_for_q > v_max_sim THEN
                v_max_sim := v_best_for_q;
            END IF;
        END LOOP;
    END IF;

    -- 9. Aplicação da fórmula obrigatória: 0.50 * maior + 0.30 * média + 0.20 * agregado
    IF v_count_pairs > 0 THEN
        v_avg_sim := v_sum_pairs / v_count_pairs;
        IF v_agg_similarity IS NOT NULL AND v_agg_similarity > 0.0 THEN
            v_calculated_score := (0.50 * v_max_sim + 0.30 * v_avg_sim + 0.20 * v_agg_similarity);
        ELSE
            v_calculated_score := (0.60 * v_max_sim + 0.40 * v_avg_sim);
        END IF;
    ELSIF v_agg_similarity IS NOT NULL THEN
        v_calculated_score := v_agg_similarity;
        v_pair_similarities := ARRAY[v_agg_similarity];
    ELSE
        RAISE EXCEPTION 'Não existem embeddings válidos suficientes para calcular a correspondência.' USING ERRCODE = 'P0009';
    END IF;

    -- Limita score no intervalo [0.0, 1.0]
    v_calculated_score := GREATEST(0.0, LEAST(1.0, v_calculated_score));

    -- 10. Validação de legitimidade contra o limiar mínimo de similaridade
    IF v_calculated_score < v_threshold THEN
        RETURN pg_catalog.jsonb_build_object(
            'success', false,
            'reason', 'similarity_below_threshold',
            'similarity_score', v_calculated_score,
            'threshold', v_threshold
        );
    END IF;

    -- 11. Persistência idempotente e atômica com ON CONFLICT (lost_pet_id, found_pet_id)
    -- Origem via save_match é SEMPRE 'manual'. Se já existia como 'automatic', preserva 'automatic'.
    INSERT INTO public.matches (
        lost_pet_id,
        found_pet_id,
        similarity_score,
        match_method,
        status,
        origin,
        individual_scores,
        created_at,
        updated_at
    ) VALUES (
        p_lost_pet_id,
        p_found_pet_id,
        v_calculated_score,
        COALESCE(p_match_method, 'visual_multi_vector'),
        'pending',
        'manual',
        pg_catalog.to_jsonb(v_pair_similarities),
        NOW(),
        NOW()
    )
    ON CONFLICT (lost_pet_id, found_pet_id) DO UPDATE SET
        similarity_score = GREATEST(public.matches.similarity_score, EXCLUDED.similarity_score),
        match_method = CASE
            WHEN EXCLUDED.similarity_score >= public.matches.similarity_score THEN EXCLUDED.match_method
            ELSE public.matches.match_method
        END,
        individual_scores = CASE
            WHEN EXCLUDED.similarity_score >= public.matches.similarity_score THEN EXCLUDED.individual_scores
            ELSE public.matches.individual_scores
        END,
        updated_at = NOW()
    RETURNING id, similarity_score, origin INTO v_match_id, v_persisted_score, v_persisted_origin;

    RETURN pg_catalog.jsonb_build_object(
        'success', true,
        'match_id', v_match_id,
        'similarity_score', v_persisted_score,
        'origin', v_persisted_origin
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. ATUALIZAÇÃO DA TRIGGER FUNCTION DE NOTIFICAÇÃO
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
    IF TG_OP = 'INSERT' AND NEW.origin = 'automatic' AND NEW.similarity_score >= 0.88 THEN
        v_should_notify := true;
    END IF;

    IF TG_OP = 'UPDATE' AND (OLD.origin IS DISTINCT FROM 'automatic') AND NEW.origin = 'automatic' AND NEW.similarity_score >= 0.88 THEN
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
-- 7. PERMISSÕES E GRANTS EXPLÍCITOS DAS RPCs DE RECONHECIMENTO
-- ------------------------------------------------------------------------------
-- Função auxiliar interna de cálculo: revogada de PUBLIC, anon e authenticated.
-- As RPCs chamadoras são SECURITY DEFINER e executam como o owner da função,
-- portanto calculate_match_score é invocada com a permissão do owner (superuser/postgres),
-- não precisando de grant direto para authenticated.
REVOKE ALL ON FUNCTION public.calculate_match_score(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_match_score(uuid, uuid) TO service_role;

REVOKE ALL ON FUNCTION public.match_found_pets_for_lost(uuid, character varying, uuid, double precision, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_found_pets_for_lost(uuid, character varying, uuid, double precision, integer, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.match_lost_pets_for_found(uuid, character varying, uuid, double precision, integer, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_lost_pets_for_found(uuid, character varying, uuid, double precision, integer, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.save_match(uuid, uuid, text, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_match(uuid, uuid, text, double precision) TO authenticated, service_role;

-- Revoga acesso público de anon às tabelas de embeddings internos
REVOKE ALL ON public.pet_images FROM anon;
REVOKE ALL ON public.pet_visual_profiles FROM anon;

-- ------------------------------------------------------------------------------
-- 8. SANEAMENTO E REFORÇO DE POLÍTICAS ROW LEVEL SECURITY (RLS) DO MÓDULO VISUAL
-- ------------------------------------------------------------------------------

-- 8.1 pet_images: Proteção de embeddings e mutação restrita ao titular
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

-- 8.2 pet_visual_profiles: Leitura e mutações restritas ao titular do animal
-- SEGURANÇA D1 RESOLVIDA:
-- A política permissiva SELECT USING (true) foi eliminada. Apenas os proprietários
-- legítimos de pet_lost_alerts ou pet_found_alerts podem consultar diretamente seus
-- próprios perfis visuais. A busca vetorial e o cálculo de similaridade contra animais
-- de terceiros ocorrem exclusivamente no servidor via RPCs SECURITY DEFINER, sem jamais
-- expor os vetores de embeddings SigLIP a clientes ou usuários terceiros.
DROP POLICY IF EXISTS "pet_visual_profiles_select_public" ON public.pet_visual_profiles;
DROP POLICY IF EXISTS "pet_visual_profiles_select_authenticated" ON public.pet_visual_profiles;
DROP POLICY IF EXISTS "pet_visual_profiles_select_owner" ON public.pet_visual_profiles;
CREATE POLICY "pet_visual_profiles_select_owner" ON public.pet_visual_profiles
FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
);

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

-- 8.3 matches: Leitura restrita aos titulares envolvidos (lost_pet_id ou found_pet_id); escrita direta vedada
-- SEGURANÇA D2 RESOLVIDA:
-- Inserções e atualizações diretas na tabela matches via cliente REST/PostgREST foram REVOGADAS.
-- Nenhuma política de INSERT ou UPDATE é concedida a authenticated ou anon.
-- Toda persistência de correspondência é realizada exclusivamente pela RPC public.save_match() (SECURITY DEFINER),
-- que valida autenticação, existência, status ativo, compatibilidade estrita de espécie, titularidade
-- e calcula a pontuação real a partir dos embeddings oficiais, impedindo matches arbitrários ou pontuações manipuladas.
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

-- 8.4 pet_found_alerts: Permitir exclusão pelo próprio usuário criador
DROP POLICY IF EXISTS "Permitir exclusão do próprio alerta encontrado" ON public.pet_found_alerts;
CREATE POLICY "Permitir exclusão do próprio alerta encontrado" ON public.pet_found_alerts
FOR DELETE USING (auth.uid() = user_id);

-- 8.5 notifications: Revogação de inserção direta por clientes
DROP POLICY IF EXISTS "notifications_insert_authenticated" ON public.notifications;

-- ------------------------------------------------------------------------------
-- 9. STORAGE (CONFIGURAÇÃO DEFENSIVA DE BUCKETS E POLÍTICAS DE PETS)
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

-- ------------------------------------------------------------------------------
-- 10. PERMISSÕES E GRANTS DA TABELA matches
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.save_match(uuid, uuid, text, double precision) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_match(uuid, uuid, text, double precision) TO authenticated, service_role;

-- Revoga acesso de anon e impede escrita direta por authenticated na tabela matches
REVOKE ALL ON public.matches FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.matches FROM authenticated;
GRANT SELECT ON public.matches TO authenticated;

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '>>> [ORELINHAS] Script incremental concluído com sucesso e consolidado no banco remoto!';
END $$;
