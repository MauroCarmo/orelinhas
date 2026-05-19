-- =====================================================================
-- CONFIGURAÇÃO DO BANCO DE DADOS - ORELINHAS (IBL01 & IBL02)
-- Execute este script no SQL Editor do seu painel do Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELA DE PERFIS (PROFILES) - Vinculada a auth.users
-- ---------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  name varchar(100) not null,
  phone varchar(15) not null,
  email varchar(80) not null unique,
  location varchar(150) not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- Habilitar RLS (Row Level Security) na tabela profiles
alter table public.profiles enable row level security;

-- Remover políticas existentes se houver (para evitar duplicações)
drop policy if exists "Usuários visualizam o próprio perfil" on public.profiles;
drop policy if exists "Usuários atualizam o próprio perfil" on public.profiles;
drop policy if exists "Usuários inserem o próprio perfil" on public.profiles;
drop policy if exists "Usuários deletam o próprio perfil" on public.profiles;

-- Criar as Políticas de Segurança RLS
create policy "Usuários visualizam o próprio perfil" on public.profiles
  for select using (auth.uid() = id);

create policy "Usuários atualizam o próprio perfil" on public.profiles
  for update using (auth.uid() = id);

create policy "Usuários inserem o próprio perfil" on public.profiles
  for insert with check (auth.uid() = id);

create policy "Usuários deletam o próprio perfil" on public.profiles
  for delete using (auth.uid() = id);

-- Trigger automatizado para criar o perfil correspondente ao criar o usuário
create or replace function public.handle_new_user()
returns trigger
security definer
language plpgsql
as $$
begin
  insert into public.profiles (id, name, phone, email, location)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    new.email,
    coalesce(new.raw_user_meta_data->>'location', '')
  );
  return new;
end;
$$;

-- Remover e recriar o trigger
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ---------------------------------------------------------------------
-- 2. BLOQUEIO TEMPORÁRIO DE CONTA (PROTEÇÃO CONTRA BRUTE FORCE)
-- ---------------------------------------------------------------------

create table if not exists public.login_attempts (
  email text primary key,
  attempts_count integer not null default 0,
  locked_until timestamp with time zone,
  last_attempt_at timestamp with time zone default now()
);

-- Ativar RLS (mantendo a tabela privada de acesso anon select direto)
alter table public.login_attempts enable row level security;

-- Função RPC: Verificar se o e-mail do usuário está bloqueado
create or replace function public.is_email_locked(user_email text)
returns jsonb
security definer
language plpgsql
as $$
declare
  v_locked_until timestamp with time zone;
  v_attempts integer;
  v_is_locked boolean := false;
  v_remaining_seconds integer := 0;
begin
  select locked_until, attempts_count into v_locked_until, v_attempts
  from public.login_attempts
  where email = user_email;

  if found then
    if v_locked_until is not null and v_locked_until > now() then
      v_is_locked := true;
      v_remaining_seconds := extract(epoch from (v_locked_until - now()))::integer;
    elsif v_locked_until is not null and v_locked_until <= now() then
      -- Se o bloqueio expirou, reseta os dados
      update public.login_attempts
      set attempts_count = 0, locked_until = null
      where email = user_email;
      v_attempts := 0;
    end if;
  end if;

  return jsonb_build_object(
    'is_locked', v_is_locked,
    'remaining_seconds', v_remaining_seconds,
    'attempts_count', coalesce(v_attempts, 0)
  );
end;
$$;

-- Função RPC: Registrar tentativa de login (Sucesso ou Falha)
create or replace function public.register_login_attempt(user_email text, is_success boolean)
returns jsonb
security definer
language plpgsql
as $$
declare
  v_attempts integer := 0;
  v_locked_until timestamp with time zone := null;
  v_is_locked boolean := false;
begin
  if is_success then
    -- Sucesso: reseta a contagem de tentativas e o bloqueio
    insert into public.login_attempts (email, attempts_count, locked_until, last_attempt_at)
    values (user_email, 0, null, now())
    on conflict (email) do update
    set attempts_count = 0, locked_until = null, last_attempt_at = now();
  else
    -- Falha: incrementa a contagem de tentativas inválidas
    select attempts_count, locked_until into v_attempts, v_locked_until
    from public.login_attempts
    where email = user_email;

    if not found then
      v_attempts := 1;
      insert into public.login_attempts (email, attempts_count, locked_until, last_attempt_at)
      values (user_email, v_attempts, null, now());
    else
      -- Se a conta já estiver no período de bloqueio ativo, ignora
      if v_locked_until is not null and v_locked_until > now() then
        v_is_locked := true;
      else
        v_attempts := v_attempts + 1;
        -- Se atingir 3 ou mais tentativas falhas, bloqueia por 15 minutos
        if v_attempts >= 3 then
          v_locked_until := now() + interval '15 minutes';
          v_is_locked := true;
        end if;
        
        update public.login_attempts
        set attempts_count = v_attempts,
            locked_until = v_locked_until,
            last_attempt_at = now()
        where email = user_email;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'attempts_count', v_attempts,
    'is_locked', v_is_locked,
    'locked_until', v_locked_until
  );
end;
$$;


-- ---------------------------------------------------------------------
-- 3. EXCLUSÃO SEGURA DE CONTA (DELETE OWN USER)
-- ---------------------------------------------------------------------

create or replace function public.delete_own_user()
returns void
security definer
language plpgsql
as $$
begin
  -- Exclui da tabela auth.users. Devido à chave estrangeira na tabela
  -- profiles (references auth.users(id) on delete cascade),
  -- o perfil público do usuário é removido instantaneamente.
  delete from auth.users where id = auth.uid();
end;
$$;
