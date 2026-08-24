-- ==============================================================================
-- ORELINHAS: RESET TOTAL E RECRIACAO DA FEATURE DE IA E NOTIFICACOES
-- Execute este script completo no Supabase Dashboard > SQL Editor
-- Ele limpa qualquer conflito anterior e recria tudo do zero de forma limpa.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PASSO 1: LIMPEZA COMPLETA (DROP DE TRIGGERS, FUNCOES E TABELAS)
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;
DROP FUNCTION IF EXISTS public.handle_auto_match_notification();

-- Dropar tabelas relacionadas (CASCADE remove chaves estrangeiras e índices)
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.matches CASCADE;
DROP TABLE IF EXISTS public.pet_images CASCADE;
DROP TABLE IF EXISTS public.pet_visual_profiles CASCADE;
DROP TABLE IF EXISTS public.user_push_tokens CASCADE;

-- ------------------------------------------------------------------------------
-- PASSO 2: HABILITAR EXTENSAO PGVECTOR
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;

-- ------------------------------------------------------------------------------
-- PASSO 3: TABELA DE IMAGENS E EMBEDDINGS (pet_images)
-- Salva a imagem original e o vetor de 768 dimensões gerado pelo SigLIP
-- ------------------------------------------------------------------------------
CREATE TABLE public.pet_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'processed',
    embedding VECTOR(768),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_pet_images_pet_id ON public.pet_images(pet_id);

-- ------------------------------------------------------------------------------
-- PASSO 4: TABELA DE PERFIS VISUAIS AGREGADOS (pet_visual_profiles)
-- Salva o vetor consolidado (média L2 normalizada de até 3 fotos)
-- ------------------------------------------------------------------------------
CREATE TABLE public.pet_visual_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL UNIQUE,
    pet_type VARCHAR(50) NOT NULL,
    aggregated_embedding VECTOR(768),
    images JSONB DEFAULT '[]'::jsonb,
    last_analyzed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_pet_visual_profiles_pet_type ON public.pet_visual_profiles(pet_type);

-- ------------------------------------------------------------------------------
-- PASSO 5: TABELA DE MATCHES (matches)
-- Registra correspondências detectadas pela IA entre pet perdido e pet encontrado
-- ------------------------------------------------------------------------------
CREATE TABLE public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lost_pet_id UUID NOT NULL,
    found_pet_id UUID NOT NULL,
    similarity_score DOUBLE PRECISION NOT NULL,
    match_method VARCHAR(50) NOT NULL DEFAULT 'visual',
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    individual_scores JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_matches_pair UNIQUE (lost_pet_id, found_pet_id)
);

CREATE INDEX idx_matches_lost_pet ON public.matches(lost_pet_id);
CREATE INDEX idx_matches_found_pet ON public.matches(found_pet_id);
CREATE INDEX idx_matches_similarity ON public.matches(similarity_score DESC);

-- ------------------------------------------------------------------------------
-- PASSO 6: TABELA DE NOTIFICACOES (notifications)
-- ------------------------------------------------------------------------------
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL DEFAULT 'match_found',
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    related_pet_id UUID,
    related_match_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(user_id, is_read);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at DESC);

-- ------------------------------------------------------------------------------
-- PASSO 7: TABELA DE TOKENS DE PUSH (user_push_tokens)
-- ------------------------------------------------------------------------------
CREATE TABLE public.user_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type VARCHAR(50) DEFAULT 'flutter',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_user_push_token UNIQUE(user_id, token)
);

-- ------------------------------------------------------------------------------
-- PASSO 8: ROW LEVEL SECURITY (RLS) - PERMISSOES COMPLETAS
-- ------------------------------------------------------------------------------
ALTER TABLE public.pet_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_visual_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- Permissões para pet_images
CREATE POLICY "pet_images_select_public"
ON public.pet_images FOR SELECT USING (true);

CREATE POLICY "pet_images_insert_authenticated"
ON public.pet_images FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Permissões para pet_visual_profiles
CREATE POLICY "pet_visual_profiles_select_public"
ON public.pet_visual_profiles FOR SELECT USING (true);

CREATE POLICY "pet_visual_profiles_all_authenticated"
ON public.pet_visual_profiles FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Permissões para matches
CREATE POLICY "matches_select_public"
ON public.matches FOR SELECT USING (true);

CREATE POLICY "matches_insert_authenticated"
ON public.matches FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "matches_update_authenticated"
ON public.matches FOR UPDATE
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Permissões para notifications
CREATE POLICY "notifications_select_owner"
ON public.notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_owner"
ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "notifications_insert_authenticated"
ON public.notifications FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Permissões para user_push_tokens
CREATE POLICY "user_push_tokens_all_owner"
ON public.user_push_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- PASSO 9: TRIGGER AUTOMATICO DE NOTIFICACAO POR MATCH
-- Dispara automaticamente ao inserir em matches com score >= 0.70 (70%)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_auto_match_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_user_id UUID;
    v_lost_pet_name VARCHAR(100);
    v_found_location VARCHAR(200);
    v_score_percentage VARCHAR(10);
BEGIN
    IF NEW.similarity_score >= 0.70 THEN
        -- Identifica o tutor do pet perdido
        SELECT user_id, pet_name 
        INTO v_owner_user_id, v_lost_pet_name
        FROM public.pet_lost_alerts
        WHERE id = NEW.lost_pet_id;

        -- Identifica a localização onde o pet foi avistado
        SELECT found_location 
        INTO v_found_location
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
                    'found_pet_id', NEW.found_pet_id
                ),
                NOW()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_notify_on_match
AFTER INSERT ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_auto_match_notification();
