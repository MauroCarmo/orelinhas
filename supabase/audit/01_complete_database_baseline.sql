-- ==============================================================================
-- ORELINHAS: BASELINE COMPLETO E CONSOLIDADO DO BANCO DE DADOS (POSTGRESQL + SUPABASE)
-- Arquivo: supabase/audit/01_complete_database_baseline.sql
-- Finalidade: Representar a estrutura canônica final e consolidada do banco de dados,
--             contemplando regras de negócio, IA, pgvector HNSW, RLS estrito por titularidade,
--             funções SECURITY DEFINER blindadas (search_path = ''), Storage e triggers.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EXTENSÕES
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "public";

-- ------------------------------------------------------------------------------
-- 2. TABELAS PÚBLICAS
-- ------------------------------------------------------------------------------

-- 2.1 Perfis de Usuário (espelha auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL,
    email VARCHAR(80) NOT NULL UNIQUE,
    location VARCHAR(150) NOT NULL,
    cep VARCHAR(8) DEFAULT '',
    street VARCHAR(150) DEFAULT '',
    number VARCHAR(20) DEFAULT '',
    district VARCHAR(100) DEFAULT '',
    city VARCHAR(100) DEFAULT '',
    state VARCHAR(2) DEFAULT '',
    complement VARCHAR(150) DEFAULT '',
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 2.2 Controle de Tentativas de Login e Bloqueio Temporário
CREATE TABLE IF NOT EXISTS public.login_attempts (
    email TEXT PRIMARY KEY,
    attempts_count INTEGER DEFAULT 0 NOT NULL,
    locked_until TIMESTAMP WITH TIME ZONE,
    last_attempt_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2.3 Tokens Push (FCM / Notificações Móveis)
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type VARCHAR(50) DEFAULT 'flutter',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_user_push_token UNIQUE (user_id, token)
);

-- 2.4 Alertas de Pets Perdidos
CREATE TABLE IF NOT EXISTS public.pet_lost_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    pet_name VARCHAR(100) NOT NULL,
    pet_type VARCHAR(50) NOT NULL,
    breed VARCHAR(100),
    age VARCHAR(50),
    description VARCHAR(255) NOT NULL,
    last_location VARCHAR(200) NOT NULL,
    lost_date TIMESTAMP WITH TIME ZONE NOT NULL,
    contact VARCHAR(20) NOT NULL,
    image_url VARCHAR(500),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 2.5 Alertas de Pets Encontrados
CREATE TABLE IF NOT EXISTS public.pet_found_alerts (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    pet_type TEXT NOT NULL,
    breed TEXT,
    apparent_age TEXT,
    description TEXT NOT NULL,
    found_location TEXT NOT NULL,
    found_date TIMESTAMP WITH TIME ZONE NOT NULL,
    contact TEXT,
    image_url TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2.6 Alertas de Pets para Adoção
CREATE TABLE IF NOT EXISTS public.pet_adoption_alerts (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    image_url TEXT NOT NULL,
    characteristics VARCHAR(255) NOT NULL,
    is_vaccinated BOOLEAN DEFAULT FALSE NOT NULL,
    status VARCHAR(20) DEFAULT 'available' NOT NULL,
    species VARCHAR(50) NOT NULL,
    region VARCHAR(150) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2.7 Imagens Individuais e Embeddings SigLIP (768d)
CREATE TABLE IF NOT EXISTS public.pet_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'processed' NOT NULL,
    embedding public.vector(768),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_pet_images_pet_url UNIQUE (pet_id, image_url)
);

-- 2.8 Perfis Visuais Agregados (1 por pet com fotos elegíveis)
CREATE TABLE IF NOT EXISTS public.pet_visual_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL UNIQUE,
    pet_type VARCHAR(50) NOT NULL,
    aggregated_embedding public.vector(768),
    images JSONB DEFAULT '[]'::jsonb,
    last_analyzed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2.9 Correspondências (Matches)
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lost_pet_id UUID NOT NULL REFERENCES public.pet_lost_alerts(id) ON DELETE CASCADE,
    found_pet_id UUID NOT NULL REFERENCES public.pet_found_alerts(id) ON DELETE CASCADE,
    similarity_score DOUBLE PRECISION NOT NULL,
    match_method VARCHAR(50) DEFAULT 'visual_single_vector' NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' NOT NULL,
    origin VARCHAR(20) DEFAULT 'manual' NOT NULL,
    individual_scores JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_matches_pair UNIQUE (lost_pet_id, found_pet_id)
);

-- 2.10 Notificações
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type VARCHAR(50) DEFAULT 'match_found' NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    related_pet_id UUID,
    related_match_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. ÍNDICES (BTREE E HNSW PGVECTOR)
-- ------------------------------------------------------------------------------

-- Perfis e Alertas
CREATE INDEX IF NOT EXISTS idx_pet_lost_user_id ON public.pet_lost_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_pet_lost_created_at ON public.pet_lost_alerts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pet_found_user_id ON public.pet_found_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_pet_found_created_at ON public.pet_found_alerts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pet_adoption_user_id ON public.pet_adoption_alerts(user_id);

-- Reconhecimento e Imagens
CREATE INDEX IF NOT EXISTS idx_pet_images_pet_id ON public.pet_images(pet_id);
CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_pet_type ON public.pet_visual_profiles(pet_type);

-- Matches e Notificações
CREATE INDEX IF NOT EXISTS idx_matches_lost_pet ON public.matches(lost_pet_id);
CREATE INDEX IF NOT EXISTS idx_matches_found_pet ON public.matches(found_pet_id);
CREATE INDEX IF NOT EXISTS idx_matches_similarity ON public.matches(similarity_score DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(user_id, is_read);

-- Idempotência de Notificações por Evento de Match
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_match_event 
ON public.notifications(user_id, related_pet_id, related_match_id) 
WHERE type = 'match_found' AND related_pet_id IS NOT NULL AND related_match_id IS NOT NULL;

-- Índices HNSW para pgvector com métrica de cosseno
CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_embedding_hnsw
ON public.pet_visual_profiles
USING hnsw (aggregated_embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_pet_images_embedding_hnsw
ON public.pet_images
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

-- ------------------------------------------------------------------------------
-- 4. FUNÇÕES DE BANCO (TRIGGERS, AUTH E RPCs)
-- ------------------------------------------------------------------------------

-- 4.1 Atualização de updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at() 
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = pg_catalog.now();
    RETURN NEW;
END;
$$;

-- 4.2 Criação automática de perfil ao cadastrar no Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (
        id, 
        name, 
        phone, 
        email, 
        location,
        cep,
        street,
        number,
        district,
        city,
        state,
        complement
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', ''),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'location', ''),
        COALESCE(NEW.raw_user_meta_data->>'cep', ''),
        COALESCE(NEW.raw_user_meta_data->>'street', ''),
        COALESCE(NEW.raw_user_meta_data->>'number', ''),
        COALESCE(NEW.raw_user_meta_data->>'district', ''),
        COALESCE(NEW.raw_user_meta_data->>'city', ''),
        COALESCE(NEW.raw_user_meta_data->>'state', ''),
        COALESCE(NEW.raw_user_meta_data->>'complement', '')
    );
    RETURN NEW;
END;
$$;

-- 4.3 Exclusão de própria conta (LGPD / Requisito Apple Store)
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

-- 4.4 Verificação de bloqueio temporário por tentativas de login
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

-- 4.5 Registro de tentativa de login (com proteção contra manipulação anônima)
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

    -- Sucesso: apenas reseta se o usuário já estiver autenticado e o e-mail coincidir
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

    -- Falha: verifica se o e-mail existe em auth.users para evitar poluição de dados
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

-- 4.6 RPC: Busca de pets encontrados para pet perdido (pgvector)
-- Segurança: Consome EXCLUSIVAMENTE o embedding oficial persistido em pet_visual_profiles.
-- Remove qualquer fallback para embeddings enviados pelo cliente.
-- Valida titularidade, status ativo, espécie (em perfil e alerta) e 768 dimensões.
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

-- 4.7 RPC: Busca de pets perdidos para pet encontrado (pgvector)
-- Segurança: Consome EXCLUSIVAMENTE o embedding oficial persistido em pet_visual_profiles.
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

-- 4.8 Notificação automática de matches (apenas matches automáticos com score >= 0.70)
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

-- ------------------------------------------------------------------------------
-- 5. TRIGGERS
-- ------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS on_profiles_updated ON public.profiles;
CREATE TRIGGER on_profiles_updated
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS on_pet_lost_alerts_updated ON public.pet_lost_alerts;
CREATE TRIGGER on_pet_lost_alerts_updated
BEFORE UPDATE ON public.pet_lost_alerts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;
CREATE TRIGGER trg_notify_on_match
AFTER INSERT OR UPDATE OF origin ON public.matches
FOR EACH ROW EXECUTE FUNCTION public.handle_auto_match_notification();

-- ------------------------------------------------------------------------------
-- 6. POLÍTICAS DE ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------------------------

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_lost_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_found_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_adoption_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_visual_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 6.1 profiles: Acesso estritamente restrito ao próprio usuário
DROP POLICY IF EXISTS "Qualquer usuário autenticado pode ver perfis" ON public.profiles;
DROP POLICY IF EXISTS "Usuários visualizam o próprio perfil" ON public.profiles;
CREATE POLICY "Usuários visualizam o próprio perfil" ON public.profiles
FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Usuários inserem o próprio perfil" ON public.profiles;
CREATE POLICY "Usuários inserem o próprio perfil" ON public.profiles
FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Usuários atualizam o próprio perfil" ON public.profiles;
CREATE POLICY "Usuários atualizam o próprio perfil" ON public.profiles
FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Usuários deletam o próprio perfil" ON public.profiles;
CREATE POLICY "Usuários deletam o próprio perfil" ON public.profiles
FOR DELETE USING (auth.uid() = id);

-- 6.2 user_push_tokens: Acesso total apenas ao dono do token
DROP POLICY IF EXISTS "user_push_tokens_all_owner" ON public.user_push_tokens;
CREATE POLICY "user_push_tokens_all_owner" ON public.user_push_tokens
FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 6.3 pet_lost_alerts
DROP POLICY IF EXISTS "Usuários autenticados podem ver todos os alertas" ON public.pet_lost_alerts;
DROP POLICY IF EXISTS "Usuários visualizam próprios alertas" ON public.pet_lost_alerts;
CREATE POLICY "Usuários autenticados podem ver todos os alertas" ON public.pet_lost_alerts
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Usuários inserem próprios alertas" ON public.pet_lost_alerts;
CREATE POLICY "Usuários inserem próprios alertas" ON public.pet_lost_alerts
FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuários atualizam próprios alertas" ON public.pet_lost_alerts;
CREATE POLICY "Usuários atualizam próprios alertas" ON public.pet_lost_alerts
FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Usuários deletam próprios alertas" ON public.pet_lost_alerts;
CREATE POLICY "Usuários deletam próprios alertas" ON public.pet_lost_alerts
FOR DELETE USING (auth.uid() = user_id);

-- 6.4 pet_found_alerts
DROP POLICY IF EXISTS "Permitir leitura pública" ON public.pet_found_alerts;
CREATE POLICY "Permitir leitura pública" ON public.pet_found_alerts
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Permitir inserção a usuários logados" ON public.pet_found_alerts;
CREATE POLICY "Permitir inserção a usuários logados" ON public.pet_found_alerts
FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Permitir atualização do próprio alerta" ON public.pet_found_alerts;
CREATE POLICY "Permitir atualização do próprio alerta" ON public.pet_found_alerts
FOR UPDATE USING (auth.uid() = user_id);

-- 6.5 pet_adoption_alerts
DROP POLICY IF EXISTS "Permitir leitura pública de adoções disponíveis ou própria" ON public.pet_adoption_alerts;
CREATE POLICY "Permitir leitura pública de adoções disponíveis ou própria" ON public.pet_adoption_alerts
FOR SELECT USING (status = 'available' OR auth.uid() = user_id);

DROP POLICY IF EXISTS "Permitir inserção a usuários logados" ON public.pet_adoption_alerts;
CREATE POLICY "Permitir inserção a usuários logados" ON public.pet_adoption_alerts
FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Permitir atualização do próprio anúncio" ON public.pet_adoption_alerts;
CREATE POLICY "Permitir atualização do próprio anúncio" ON public.pet_adoption_alerts
FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Permitir exclusão do próprio anúncio" ON public.pet_adoption_alerts;
CREATE POLICY "Permitir exclusão do próprio anúncio" ON public.pet_adoption_alerts
FOR DELETE USING (auth.uid() = user_id);

-- 6.6 pet_images (Proteção de embeddings: leitura permitida apenas ao titular do animal)
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
CREATE POLICY "pet_images_insert_owner" ON public.pet_images
FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    )
);

DROP POLICY IF EXISTS "pet_images_update_owner" ON public.pet_images;
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

DROP POLICY IF EXISTS "pet_images_delete_owner" ON public.pet_images;
CREATE POLICY "pet_images_delete_owner" ON public.pet_images
FOR DELETE USING (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = pet_id AND user_id = auth.uid())
    )
);

-- 6.7 pet_visual_profiles (leitura por usuários autenticados; mutações restritas ao titular do animal)
-- DECISÃO ARQUITETURAL (SELECT USING true):
-- O pipeline de reconhecimento visual do Flutter lê perfis de outros usuários (getVisualProfile,
-- getVisualProfilesByIds) para calcular similaridade de candidatos. Restringir SELECT ao próprio
-- dono quebraria o matching. TRADE-OFF DOCUMENTADO: embeddings de outros usuários ficam visíveis
-- via API direta para autenticados. Mitigação: RPCs SECURITY DEFINER consomem só o embedding
-- oficial da base; acesso anon revogado. Evolução futura: view sem aggregated_embedding.
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

-- 6.8 matches (leitura restrita aos titulares envolvidos; inserção e atualização restrita ao titular de ao menos um dos pets da correspondência)
-- DECISÃO ARQUITETURAL (INSERT/UPDATE com OR):
-- O Flutter chama saveMatch diretamente (cliente autenticado) tanto para buscas manuais
-- quanto automáticas. Exigir propriedade dos DOIS animais bloquearia o caso central:
-- o dono do pet perdido salva correspondências com found_pets de outros usuários.
-- RISCO RESIDUAL: um usuário pode associar seu pet a qualquer found_pet_id válido.
-- Mitigação futura: mover saveMatch para RPC SECURITY DEFINER ou Edge Function.
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
CREATE POLICY "matches_insert_owner" ON public.matches
FOR INSERT WITH CHECK (
    auth.role() = 'authenticated' AND (
        EXISTS (SELECT 1 FROM public.pet_lost_alerts WHERE id = lost_pet_id AND user_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.pet_found_alerts WHERE id = found_pet_id AND user_id = auth.uid())
    )
);

DROP POLICY IF EXISTS "matches_update_owner" ON public.matches;
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

-- 6.9 notifications: Usuário lê e atualiza apenas suas próprias notificações.
DROP POLICY IF EXISTS "notifications_insert_authenticated" ON public.notifications;

DROP POLICY IF EXISTS "notifications_select_owner" ON public.notifications;
CREATE POLICY "notifications_select_owner" ON public.notifications
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_update_owner" ON public.notifications;
CREATE POLICY "notifications_update_owner" ON public.notifications
FOR UPDATE USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 7. PERMISSÕES E GRANTS EXPLÍCITOS
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
-- 8. STORAGE (CONFIGURAÇÃO DEFENSIVA DE BUCKETS E POLÍTICAS)
-- ------------------------------------------------------------------------------
-- Não força public = true em buckets já existentes (preserva configurações)
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
