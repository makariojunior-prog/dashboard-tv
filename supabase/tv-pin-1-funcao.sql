-- PIN da Cantina TV: conferência no banco, sem expor o PIN ao navegador.
-- Parte 1 (aditiva): função + registro de tentativas. Pode ser aplicada antes de publicar a TV nova.
-- Aplicar com: npx supabase db query --linked -f supabase/tv-pin-1-funcao.sql  (nunca db push; o banco é compartilhado)

create table if not exists public.tv_pin_attempts (
  id bigserial primary key,
  ok boolean not null,
  at timestamptz not null default now()
);
create index if not exists idx_tv_pin_attempts_at on public.tv_pin_attempts (at);

-- Sem policies: ninguém lê ou grava direto; só a função (security definer).
alter table public.tv_pin_attempts enable row level security;

create or replace function public.tv_verify_pin(p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_real text;
  v_falhas int;
  v_ok boolean;
begin
  -- Trava global contra força bruta: 20 erros no último minuto bloqueiam novas tentativas por um instante.
  select count(*) into v_falhas from public.tv_pin_attempts where not ok and at > now() - interval '1 minute';
  if v_falhas >= 20 then
    return false;
  end if;

  select value into v_real from public.crm_config where key = 'tv_dashboard_pin';
  v_ok := v_real is not null and p_pin is not null and p_pin = v_real;

  insert into public.tv_pin_attempts (ok) values (v_ok);
  delete from public.tv_pin_attempts where at < now() - interval '1 day';

  return v_ok;
end;
$$;

revoke all on function public.tv_verify_pin(text) from public;
grant execute on function public.tv_verify_pin(text) to anon, authenticated;
