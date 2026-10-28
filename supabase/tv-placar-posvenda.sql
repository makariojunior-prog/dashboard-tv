-- Placar de Pós-venda e Recompra na TV (espelha o PosVendaWidget do CRM).
-- Acrescenta 3 chaves ao snapshot, sem mexer nas existentes:
--   placar               [{tipo, atendente, hoje}]  tipo 1 = Pós-venda, 2 = Recompra
--   meta_recompra        meta diária da equipe (posvendas_metas)
--   posvendas_pendentes  total de pendentes (o bloco 'posvendas' é limitado a 50)
-- O bloco 'conversas' continua no JSON, mas a TV não o usa mais.
-- Aplicar com: npx supabase db query --linked -f supabase/tv-placar-posvenda.sql

create or replace function public.tv_dashboard_snapshot()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'varejo_hoje', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select origem, order_type, entregador, valor_liquido, status_icon
        from varejo_pedidos
        where data_entrega = (now() at time zone 'America/Sao_Paulo')::date
      ) t
    ),
    'atacado_hoje', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select valor, ignorado, tipo, data_entrega
        from atacado_pedidos
        where data_entrega = (now() at time zone 'America/Sao_Paulo')::date
          and ignorado = false
      ) t
    ),
    'fila', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select num_pedido, cliente, bairro, origem
        from varejo_pedidos
        where status_icon = '⚠️'
          and turno is null
          and origem = 'CARDAPIO WEB'
          and order_type <> 'takeout'
        order by created_at desc
        limit 50
      ) t
    ),
    'agenda', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select tipo, hora_inicio, cliente_nome, responsaveis, local, status
        from agenda_compromissos
        where data = (now() at time zone 'America/Sao_Paulo')::date
          and status <> 'CANCELADO'
        order by hora_inicio asc
        limit 8
      ) t
    ),
    'rotas', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select turno, entregador, cliente_nome, numero_pedido
        from atacado_pedidos
        where data_entrega = (now() at time zone 'America/Sao_Paulo')::date
        order by turno nulls last, entregador nulls last, cliente_nome nulls last
      ) t
    ),
    'visitas', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select visit_date, visit_type, client_name, responsible, demand, report, priority, created_at
        from visits
        where visit_date >= (now() at time zone 'America/Sao_Paulo')::date - 7
        order by visit_date desc, created_at desc
        limit 6
      ) t
    ),
    'conversas', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select categoria, nome, telefone, resumo, texto, received_at, conexao
        from crm_conversations
        where categoria in ('QUALIDADE', 'LOGÍSTICA', 'RECLAMAÇÃO')
          and visto = false
          and archived = false
        order by received_at desc
        limit 8
      ) t
    ),
    'social', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select platform, account, username, nome, mensagem, categoria, received_at
        from crm_social_comments
        where status = 'NOVO'
        order by received_at desc
        limit 4
      ) t
    ),
    'posvendas', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select nome, telefone, ult_compra, dias_pos_compra, n_pedidos
        from crm_posvendas
        where prioridade = 1
        order by dias_sem_contato desc
        limit 50
      ) t
    ),
    'recompras', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select nome, telefone, created_at, usuario_nome
        from crm_posvendas_interacoes
        where data_interacao >= (now() at time zone 'America/Sao_Paulo')::date
          and data_interacao <  (now() at time zone 'America/Sao_Paulo')::date + 1
        order by created_at desc
        limit 50
      ) t
    ),
    'placar', (
      select coalesce(jsonb_agg(t), '[]'::jsonb) from (
        select tipo, atendente, hoje from public.crm_posvendas_placar_hoje()
      ) t
    ),
    'meta_recompra', (
      select coalesce((select meta_recompra_dia from posvendas_metas where id = 1), 40)
    ),
    'posvendas_pendentes', (
      select count(*)::int from crm_posvendas where prioridade = 1
    )
  );
$$;
