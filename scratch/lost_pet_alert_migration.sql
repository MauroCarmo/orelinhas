-- =====================================================================
-- MIGRAÇÃO DE BANCO DE DADOS - ALERTAS DE PETS PERDIDOS (USER STORY 3)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.pet_lost_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pet_name VARCHAR(100) NOT NULL,
  pet_type VARCHAR(50) NOT NULL,
  breed VARCHAR(100),
  age VARCHAR(50),
  description TEXT NOT NULL,
  last_location VARCHAR(200) NOT NULL,
  lost_date TIMESTAMP WITH TIME ZONE NOT NULL,
  contact VARCHAR(20) NOT NULL,
  image_url VARCHAR(500),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Ativar RLS (Row Level Security) na tabela pet_lost_alerts
ALTER TABLE public.pet_lost_alerts ENABLE ROW LEVEL SECURITY;

-- Remover políticas existentes se houver (para evitar duplicações)
DROP POLICY IF EXISTS "Usuários visualizam próprios alertas" ON public.pet_lost_alerts;
DROP POLICY IF EXISTS "Usuários inserem próprios alertas" ON public.pet_lost_alerts;
DROP POLICY IF EXISTS "Usuários atualizam próprios alertas" ON public.pet_lost_alerts;
DROP POLICY IF EXISTS "Usuários deletam próprios alertas" ON public.pet_lost_alerts;

-- Criar Políticas de Segurança RLS
-- SELECT → apenas o próprio proprietário do alerta
CREATE POLICY "Usuários visualizam próprios alertas" ON public.pet_lost_alerts
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT → apenas usuários autenticados, com verificação explícita de sessão não-nula
CREATE POLICY "Usuários inserem próprios alertas" ON public.pet_lost_alerts
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user_id);

-- UPDATE → apenas o proprietário do alerta
CREATE POLICY "Usuários atualizam próprios alertas" ON public.pet_lost_alerts
  FOR UPDATE USING (auth.uid() = user_id);

-- DELETE → apenas o proprietário do alerta
CREATE POLICY "Usuários deletam próprios alertas" ON public.pet_lost_alerts
  FOR DELETE USING (auth.uid() = user_id);
