-- =====================================================================
-- MIGRAÇÃO DE BANCO DE DADOS - ALERTAS PÚBLICOS (US03 - Refinamento)
-- =====================================================================

-- Remover a política atual restrita de visualização
DROP POLICY IF EXISTS "Usuários visualizam próprios alertas" ON public.pet_lost_alerts;

-- Criar a nova política de visualização pública (ou para qualquer usuário autenticado/anon)
-- O 'true' permite que qualquer pessoa faça SELECT na tabela (Feed Público).
CREATE POLICY "Visualização pública de alertas" ON public.pet_lost_alerts
  FOR SELECT USING (true);

-- As demais políticas (INSERT, UPDATE, DELETE) permanecem inalteradas,
-- garantindo que:
-- 1. INSERT requer auth.uid() = user_id
-- 2. UPDATE requer auth.uid() = user_id
-- 3. DELETE requer auth.uid() = user_id
