-- =====================================================================
-- MIGRAÇÃO DE ENDEREÇO ESTRUTURADO - ORELINHAS
-- Execute este script no SQL Editor do seu painel do Supabase.
-- =====================================================================

-- Adiciona novas colunas de endereço estruturado à tabela profiles de forma segura
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cep VARCHAR(8) DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS street VARCHAR(150) DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS number VARCHAR(20) DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS district VARCHAR(100) DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100) DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS state VARCHAR(2) DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS complement VARCHAR(150) DEFAULT '';

-- Atualiza a função de trigger handle_new_user() para persistir novos cadastros com suporte a endereços e compatibilidade retrátil
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
LANGUAGE plpgsql
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
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    new.email,
    coalesce(new.raw_user_meta_data->>'location', ''),
    coalesce(new.raw_user_meta_data->>'cep', ''),
    coalesce(new.raw_user_meta_data->>'street', ''),
    coalesce(new.raw_user_meta_data->>'number', ''),
    coalesce(new.raw_user_meta_data->>'district', ''),
    coalesce(new.raw_user_meta_data->>'city', ''),
    coalesce(new.raw_user_meta_data->>'state', ''),
    coalesce(new.raw_user_meta_data->>'complement', '')
  );
  RETURN new;
END;
$$;
