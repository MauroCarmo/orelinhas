-- ==============================================================================
-- Migração: Suporte a Reconhecimento Visual de Pets, Matches e Notificações
-- Banco de Dados: PostgreSQL com extensão pgvector (Supabase)
-- ==============================================================================

-- 1. Habilita a extensão pgvector para operações vetoriais de embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- ==============================================================================
-- 2. Tabela de Embeddings Individuais por Imagem (pet_images)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pet_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL, -- Pode referenciar pet_lost_alerts ou pet_found_alerts
    image_url TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'processed', -- pending, processing, processed, not_detected, error
    embedding VECTOR(768), -- SigLIP Base for Animal Identification (768 dimensões)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice HNSW para acelerar a busca aproximada por vizinhos nos embeddings individuais
CREATE INDEX IF NOT EXISTS idx_pet_images_embedding_hnsw 
ON public.pet_images 
USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_pet_images_pet_id ON public.pet_images(pet_id);

-- ==============================================================================
-- 3. Tabela de Perfis Visuais Agregados (pet_visual_profiles)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pet_visual_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL UNIQUE,
    pet_type VARCHAR(50) NOT NULL, -- dog, cat, other
    aggregated_embedding VECTOR(768), -- Média vetorial L2-normalizada das imagens válidas
    images JSONB DEFAULT '[]'::jsonb,
    last_analyzed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice HNSW no embedding agregado para recuperação rápida de candidatos (Etapa 1)
CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_embedding_hnsw 
ON public.pet_visual_profiles 
USING hnsw (aggregated_embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_pet_visual_profiles_pet_type ON public.pet_visual_profiles(pet_type);

-- ==============================================================================
-- 4. Tabela de Matches (Histórico e Registro de Correspondências)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lost_pet_id UUID NOT NULL,
    found_pet_id UUID NOT NULL,
    similarity_score DOUBLE PRECISION NOT NULL, -- 0.0 a 1.0 (ex: 0.885 para 88.5%)
    match_method VARCHAR(50) NOT NULL DEFAULT 'visual', -- visual, cadastral
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, confirmed, rejected
    individual_scores JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
    type VARCHAR(50) NOT NULL DEFAULT 'match_found', -- match_found, pet_status_update, system
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    related_pet_id UUID, -- ID do pet do usuário (ex: pet_lost_alerts.id)
    related_match_id UUID, -- ID do pet encontrado ou do registro em matches
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
    device_type VARCHAR(50) DEFAULT 'flutter', -- android, ios, web, flutter
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_user_push_token UNIQUE(user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_id ON public.user_push_tokens(user_id);

-- ==============================================================================
-- 7. Row Level Security (RLS)
-- ==============================================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_visual_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pet_images ENABLE ROW LEVEL SECURITY;

-- Políticas para notifications
CREATE POLICY "Usuários podem ver suas próprias notificações"
ON public.notifications FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem atualizar suas próprias notificações (marcar como lida)"
ON public.notifications FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Políticas para push tokens
CREATE POLICY "Usuários podem gerenciar seus tokens de push"
ON public.user_push_tokens FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Políticas para perfis visuais e imagens
CREATE POLICY "Leitura pública de perfis visuais"
ON public.pet_visual_profiles FOR SELECT
USING (true);

CREATE POLICY "Inserção/Atualização autenticada de perfis visuais"
ON public.pet_visual_profiles FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Leitura pública de imagens de pets"
ON public.pet_images FOR SELECT
USING (true);

CREATE POLICY "Inserção autenticada de imagens de pets"
ON public.pet_images FOR ALL
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- ==============================================================================
-- 8. Trigger Automático: Geração de Notificação quando um Match for Detectado
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_auto_match_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_owner_user_id UUID;
    v_lost_pet_name VARCHAR(100);
    v_found_location VARCHAR(200);
    v_score_percentage VARCHAR(10);
BEGIN
    -- Dispara notificação somente se o score atingir o limiar mínimo (ex: 0.75 / 75%)
    IF NEW.similarity_score >= 0.75 THEN
        -- Busca dados do pet perdido e do respectivo tutor
        SELECT user_id, pet_name 
        INTO v_owner_user_id, v_lost_pet_name
        FROM public.pet_lost_alerts
        WHERE id = NEW.lost_pet_id;

        -- Busca a localização onde o pet foi encontrado
        SELECT found_location 
        INTO v_found_location
        FROM public.pet_found_alerts
        WHERE id = NEW.found_pet_id;

        -- Se o tutor existir, gera a notificação automaticamente
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
                'Um pet parecido com "' || COALESCE(v_lost_pet_name, 'seu pet') || '" foi avistado em ' || COALESCE(v_found_location, 'sua região') || '. Toque para conferir.',
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
