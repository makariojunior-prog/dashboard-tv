-- PIN da Cantina TV, parte 2: fechar a leitura anônima de public.crm_config.
-- APLICAR SOMENTE DEPOIS de publicar a versão da TV que valida o PIN por tv_verify_pin
-- (a versão antiga ainda lê o PIN direto da tabela como anônimo).
-- Aplicar com: npx supabase db query --linked -f supabase/tv-pin-2-fechar-leitura-anonima.sql  (nunca db push)
--
-- Efeito: a chave anon (pública) deixa de conseguir ler crm_config. A administração do PIN continua
-- no Comercial (Configurações) e no Portal, que usam usuário autenticado / service role.

drop policy if exists "anon_read" on public.crm_config;
