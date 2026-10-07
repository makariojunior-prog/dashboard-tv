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
