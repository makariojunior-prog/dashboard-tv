// Proxy do rastreamento Velotrack para o painel da Cantina TV.
//
// Por quê: este repositório é PÚBLICO no GitHub e o HTML tinha o usuário e a senha do
// Velotrack fixos no código, visíveis para qualquer pessoa (a senha já foi trocada).
// Esta função faz o login e a consulta no servidor; o navegador da TV só chama esta
// função, nunca vê a senha.
//
// Segredos (Deno.env), configurados no dashboard do Supabase (Edge Functions → Secrets),
// nunca no código: VT_USER, VT_PASS
//
// Deploy (projeto compartilhado taicaxtjtikdajmhtsxc):
//   npx supabase functions deploy vt-positions --project-ref taicaxtjtikdajmhtsxc --use-api
// (--use-api empacota sem precisar do Docker)

import md5 from "npm:blueimp-md5@2.19.0";

const VT_BASE = "https://track.velotrack.com.br/api/index.php";
const VT_USER = Deno.env.get("VT_USER");
const VT_PASS = Deno.env.get("VT_PASS");

const ALLOWED_ORIGINS = new Set([
  "https://tv.cantinaemcasa.com",
  "http://localhost:5599",
  "http://localhost:3000",
]);

type VtSession = { uid: string; browser: string; idcustomer: string };
let sess: VtSession | null = null;

// Cache curto: a TV consulta a cada 30s; várias TVs/abas não precisam gerar
// uma chamada nova ao Velotrack cada uma.
let cache: { vehicles: unknown; at: number } | null = null;
const CACHE_MS = 15_000;

async function vtLogin(): Promise<VtSession> {
  if (!VT_USER || !VT_PASS) {
    throw new Error("VT_USER/VT_PASS não configurados nos secrets da função.");
  }
  const ts = Date.now();
  const passHash = md5(VT_PASS);
  const uidHash = md5(`${VT_USER}:${passHash}:${ts}`);
  const ua = "cantina-tv-proxy/1.0";
  const res = await fetch(`${VT_BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ desc_uid: uidHash, desc_useragent: ua, desc_data: ts }),
  });
  if (!res.ok) throw new Error(`VT login HTTP ${res.status}`);
  const d = await res.json();
  sess = { uid: d.desc_uid_retorno, browser: ua, idcustomer: d.idcustomer };
  return sess;
}

async function fetchPositions(): Promise<unknown> {
  if (!sess) await vtLogin();
  const res = await fetch(`${VT_BASE}/mobile/${sess!.idcustomer}/positionv2`, {
    headers: { uid: sess!.uid, browser: sess!.browser },
  });
  if (res.status === 401) {
    sess = null;
    await vtLogin();
    return fetchPositions();
  }
  if (!res.ok) throw new Error(`VT positions HTTP ${res.status}`);
  return await res.json();
}

function corsHeaders(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin && ALLOWED_ORIGINS.has(origin) ? origin : "https://tv.cantinaemcasa.com",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
  };
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get("origin"));

  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "method not allowed" }), {
      status: 405,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  try {
    if (cache && Date.now() - cache.at < CACHE_MS) {
      return new Response(JSON.stringify(cache.vehicles), {
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    const vehicles = await fetchPositions();
    cache = { vehicles, at: Date.now() };
    return new Response(JSON.stringify(vehicles), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[vt-positions]", e);
    return new Response(JSON.stringify({ error: "Falha ao consultar o rastreamento." }), {
      status: 502,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
