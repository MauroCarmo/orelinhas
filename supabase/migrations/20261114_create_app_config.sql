-- Tabela de configurações remotas (Remote Config) para resolução dinâmica do endpoint de IA
create table if not exists public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

create policy "Permitir leitura pública de app_config"
  on public.app_config
  for select
  to anon, authenticated
  using (true);

insert into public.app_config (key, value)
values ('AI_VISION_ENDPOINT', 'http://localhost:8000')
on conflict (key) do nothing;