-- ==============================================================================
-- ORELINHAS: CORREÇÃO PONTUAL DE IDEMPOTÊNCIA DE NOTIFICAÇÕES DE MATCH
-- Arquivo: supabase/migrations/20261021_fix_notification_idempotence.sql
-- ==============================================================================
-- Objetivo:
-- 1. Deduplicar registros antigos de notificações de match repetidas para o mesmo par.
-- 2. Criar índice único parcial impedindo inserções duplicadas para o mesmo evento.
-- 3. Atualizar a trigger function com tipos TEXT, search_path seguro e ON CONFLICT direto.
-- ==============================================================================

-- 1. Remoção segura de notificações duplicadas existentes (preserva a mais recente)
WITH duplicate_notifications AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, related_pet_id, related_match_id 
               ORDER BY created_at DESC NULLS LAST
           ) as row_num
    FROM public.notifications
    WHERE type = 'match_found'
      AND related_pet_id IS NOT NULL
      AND related_match_id IS NOT NULL
)
DELETE FROM public.notifications
WHERE id IN (
    SELECT id FROM duplicate_notifications WHERE row_num > 1
);

-- 2. Criação de índice único condicional para garantir idempotência a nível de banco
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_match_event 
ON public.notifications (user_id, related_pet_id, related_match_id) 
WHERE type = 'match_found';

-- 3. Atualização da função do trigger com tipos TEXT, search_path seguro e inserção atômica
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
    -- Dispara apenas para correspondências relevantes (>= 70%)
    IF NEW.similarity_score >= 0.70 THEN
        -- 1. Identifica o tutor do pet perdido
        SELECT user_id, pet_name 
        INTO v_owner_user_id, v_lost_pet_name
        FROM public.pet_lost_alerts
        WHERE id = NEW.lost_pet_id;

        -- 2. Identifica detalhes do pet encontrado
        SELECT found_location, image_url, breed
        INTO v_found_location, v_found_image_url, v_found_breed
        FROM public.pet_found_alerts
        WHERE id = NEW.found_pet_id;

        IF v_owner_user_id IS NOT NULL THEN
            v_score_percentage := TO_CHAR(ROUND((NEW.similarity_score * 100)::numeric, 1), 'FM990.0') || '%';

            -- 3. Inserção atômica com resolução de conflito no índice parcial
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
                    'found_pet_breed', v_found_breed
                ),
                NOW()
            )
            ON CONFLICT (user_id, related_pet_id, related_match_id) WHERE type = 'match_found'
            DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Garantia da associação do gatilho
DROP TRIGGER IF EXISTS trg_notify_on_match ON public.matches;
CREATE TRIGGER trg_notify_on_match
AFTER INSERT ON public.matches
FOR EACH ROW
EXECUTE FUNCTION public.handle_auto_match_notification();
