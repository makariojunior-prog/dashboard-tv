# CLAUDE.md

**Comercial TV** (`tv.cantinaemcasa.com`) — painel em TV do Comercial da Cantina em Casa / Lumar.
Página estática única (`index.html`, ~70 KB), servida pelo GitHub Pages (`CNAME`). Sem build.
Acesso por **PIN**, fora do SSO do Portal (de propósito). Português (BR).

- **Repositório público**: nunca coloque senha, token ou chave de serviço no código. Só a chave
  `anon` do Supabase fica no HTML. (Já houve vazamento de credencial do Velotrack; por isso o
  rastreamento passa pela edge function.)
- Dados: RPC `tv_dashboard_snapshot` (Supabase `taicaxtjtikdajmhtsxc`, projeto compartilhado com
  RH/CRM/Compras/Portal — não altere tabelas de outros domínios).
- PIN: conferido no banco por `public.tv_verify_pin` (sem expor o PIN ao navegador; trava contra
  força bruta em `tv_pin_attempts`). O PIN é gerenciado no Portal (`/admin/apps/tv`, aba PIN).
  SQL em `supabase/tv-pin-1-funcao.sql` e `tv-pin-2-fechar-leitura-anonima.sql`.
- Rastreamento: edge function `supabase/functions/vt-positions` (proxy do Velotrack; segredos
  `VT_USER`/`VT_PASS` nos Secrets do Supabase). Deploy:
  `npx supabase functions deploy vt-positions --project-ref taicaxtjtikdajmhtsxc --use-api`.
- **Nunca use `supabase db push`** (histórico de migrations compartilhado); aplique SQL com
  `npx supabase db query --linked -f arquivo.sql` ou o MCP do Supabase.
- A TV recarrega sozinha quando sai versão nova (já implementado) — mexer no `index.html` vai ao ar
  no merge para `main`.

## Supabase: GRANT explícito em tabelas novas (desde 30/10/2026)

O Supabase deixou de conceder acesso à API de Dados (supabase-js, PostgREST, GraphQL) automaticamente a tabelas novas em `public`. Sem GRANT a API devolve "permission denied". Tabelas anteriores a essa data não mudam. Vale também para migrations que recriam o schema (projeto novo, branch de preview, `supabase db reset`).

**Regra:** toda migration que cria tabela ou view em `public` traz os GRANTs na mesma migration.

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON public.minha_tabela TO authenticated, service_role;
-- view: GRANT SELECT ON public.minha_view TO authenticated, service_role;
-- só backend: REVOKE ALL ON public.minha_tabela FROM PUBLIC, anon, authenticated;
--             GRANT ALL ON public.minha_tabela TO service_role;
```

- Não conceder nada a `anon`, a menos que a leitura pública seja intencional (a RLS continua sendo a proteção de linha).
- Funções: `REVOKE ALL ... FROM PUBLIC` e `GRANT EXECUTE` só a quem precisa.
- Se a migration antiga foi escrita sem GRANT e o schema for recriado, rode um GRANT em lote nas tabelas existentes.
