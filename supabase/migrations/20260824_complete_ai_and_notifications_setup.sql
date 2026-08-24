-- ==============================================================================
-- ORELINHAS: SETUP COMPLETO DE IA (PGVECTOR), MATCHES E NOTIFICAÇÕES
-- Execute este script completo no Supabase Dashboard > SQL Editor
-- ==============================================================================

-- 1. Habilitar a extensão pgvector para busca e armazenamento vetorial
CREATE EXTENSION IF NOT EXISTS vector;

-- ==============================================================================
-- 2. Tabela de Imagens e Embeddings Individuais (pet_images)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pet_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL,
    image_url TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'processed',
    embedding VECTOR(768),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pet_images_pet_id ON public.pet_images(pet_id);

-- ==============================================================================
-- 3. Tabela de Perfis Visuais Agregados (pet_visual_profiles)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pet_visual_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL UNIQUE,
    pet_type VARCHAR(50) NOT NULL,
    aggregated_embedding VECTOR(768),
    images JSONB DEFAULT '[]'::jsonb,
    last_analyzed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_pet_type ON public.pet_visual_profiles(pet_type);

-- ==============================================================================
-- 4. Tabela de Matches (Correspondências Detectadas)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.matches (
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

CREATE INDEX IF NOT EXISTS idx_matches_lost_pet ON public.matches(lost_pet_id);
CREATE INDEX IF NOT EXISTS idx_matches_found_pet ON public.matches(found_pet_id);
CREATE INDEX IF NOT EXISTS idx_matches_similarity ON public.matches(similarity_score DESC);

-- ==============================================================================
-- 5. Tabela de Notificações (notifications)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
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

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- ==============================================================================
-- 6. Tabela de Tokens de Push (user_push_tokens)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type VARCHAR(50) DEFAULT 'flutter',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_user_push_token UNIQUE(user_id, token)
);

-- ==============================================================================
-- 7. Configuração de Row Level Security (RLS)
-- ==============================================================================
ALTER TABLE public.pet_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_visual_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

-- Limpar policies anteriores para evitar duplicidade
DROP POLICY IF EXISTS "Leitura publica de pet_images" ON public.pet_images;
DROP POLICY IF EXISTS "Insercao autenticada de pet_images" ON public.pet_images;
DROP POLICY IF EXISTS "Leitura publica de perfis visuais" ON public.pet_visual_profiles;
DROP POLICY IF EXISTS "Gerenciamento autenticado de perfis visuais" ON public.pet_visual_profiles;
DROP POLICY IF EXISTS "Leitura de matches" ON public.matches;
DROP POLICY IF EXISTS "Insercao autenticada de matches" ON public.matches;
DROP POLICY IF EXISTS "Atualizacao autenticada de matches" ON public.matches;
DROP POLICY IF EXISTS "Leitura de notificacoes do usuario" ON public.notifications;
DROP POLICY IF EXISTS "Atualizacao de notificacoes do usuario" ON public.notifications;
DROP POLICY IF EXISTS "Insercao autenticada de notificacoes" ON public.notifications;
DROP POLICY IF EXISTS "Gerenciamento de push tokens" ON public.user_push_tokens;

-- Policies para pet_images
CREATE POLICY "Leitura publica de pet_images"
ON public.pet_images FOR SELECT USING (true);

CREATE POLICY "Insercao autenticada de pet_images"
ON public.pet_images FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Policies para pet_visual_profiles
CREATE POLICY "Leitura publica de perfis visuais"
ON public.pet_visual_profiles FOR SELECT USING (true);

CREATE POLICY "Gerenciamento autenticado de perfis visuais"
ON public.pet_visual_profiles FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Policies para matches
CREATE POLICY "Leitura de matches"
ON public.matches FOR SELECT USING (true);

CREATE POLICY "Insercao autenticada de matches"
ON public.matches FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Atualizacao autenticada de matches"
ON public.matches FOR UPDATE
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Policies para notifications
CREATE POLICY "Leitura de notificacoes do usuario"
ON public.notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Atualizacao de notificacoes do usuario"
ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Insercao autenticada de notificacoes"
ON public.notifications FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Policies para user_push_tokens
CREATE POLICY "Gerenciamento de push tokens"
ON public.user_push_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 8. Trigger: Notificação Automática ao Inserir um Match
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_auto_match_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_user_id UUID;
    v_lost_pet_name VARCHAR(100);
    v_found_location VARCHAR(200);
    v_score_percentage VARCHAR(10);
BEGIN
    IF NEW.similarity_score >= 0.70 THEN
        -- Busca o tutor do pet perdido
        SELECT user_id, pet_name 
        INTO v_owner_user_id, v_lost_pet_name
        FROM public.pet_lost_alerts
        WHERE id = NEW.lost_pet_id;

        -- Busca a localização do pet encontrado
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
                'Um pet com características semelhantes a "' || COALESCE(v_lost_pet_name, 'seu pet') || '" foi avistado em ' || COALESCE(v_found_location, 'sua região') || '. Toque para conferir.',
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

DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;
CREATE TRIGGER trg_notify_on_match
AFTER INSERT ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_auto_match_notification();
