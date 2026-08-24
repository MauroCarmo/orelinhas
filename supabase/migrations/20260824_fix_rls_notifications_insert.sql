-- ==============================================================================
-- Migração de Correção: Políticas RLS faltantes
-- Aplicar no Supabase Dashboard > SQL Editor
-- ==============================================================================

-- 1. Política de INSERT para notificações
-- Permite que o sistema (usuários autenticados) crie notificações.
-- Necessário para que o NotificationRepository.notifyMatchFound() funcione
-- quando chamado diretamente do app Flutter via Supabase SDK.
CREATE POLICY "Usuários autenticados podem criar notificações"
ON public.notifications FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- 2. Política de SELECT para matches (leitura pelo dono do pet)
-- Permite que o dono de um pet perdido veja os matches relacionados.
CREATE POLICY "Usuários podem ver matches dos seus pets"
ON public.matches FOR SELECT
USING (
    lost_pet_id IN (
        SELECT id FROM public.pet_lost_alerts WHERE user_id = auth.uid()
    )
    OR
    found_pet_id IN (
        SELECT id FROM public.pet_found_alerts WHERE user_id = auth.uid()
    )
);
