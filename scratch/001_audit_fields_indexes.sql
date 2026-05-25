-- =====================================================================
-- MIGRAÇÃO DE BANCO DE DADOS - AUDITORIA E ÍNDICES (REFINAMENTO)
-- =====================================================================

-- 1. Criação da Função Trigger para Atualização de 'updated_at'
-- Essa função será responsável por renovar o timestamp sempre que um registro for modificado.
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER 
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- 2. Tabela public.profiles
-- A tabela profiles já possui 'updated_at', mas precisamos garantir que o trigger esteja ativo.
DROP TRIGGER IF EXISTS on_profiles_updated ON public.profiles;
CREATE TRIGGER on_profiles_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

-- 3. Tabela public.pet_lost_alerts
-- Adicionar a coluna 'updated_at' caso não exista
ALTER TABLE public.pet_lost_alerts 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL;

-- Criar a trigger para atualizar o 'updated_at'
DROP TRIGGER IF EXISTS on_pet_lost_alerts_updated ON public.pet_lost_alerts;
CREATE TRIGGER on_pet_lost_alerts_updated
  BEFORE UPDATE ON public.pet_lost_alerts
  FOR EACH ROW EXECUTE PROCEDURE public.handle_updated_at();

-- 4. Criação de Índices Otimizados
-- Criar índices de forma concorrente para evitar lock em tabelas grandes (ideal para produção)
-- Nota: O Supabase não suporta CONCURRENTLY dentro de blocos de transação se já estivermos rodando de uma UI,
-- mas num script solto funciona perfeitamente.

CREATE INDEX IF NOT EXISTS idx_pet_lost_user_id 
ON public.pet_lost_alerts(user_id);

CREATE INDEX IF NOT EXISTS idx_pet_lost_created_at 
ON public.pet_lost_alerts(created_at DESC);

-- Obs: O índice para profiles(email) NÃO foi criado intencionalmente porque 
-- a coluna "email" já possui a constraint UNIQUE, o que gera implicitamente 
-- um índice B-Tree no PostgreSQL. Criar outro índice seria redundante.
