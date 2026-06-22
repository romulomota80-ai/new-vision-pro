# Ads / Marketing — planta da capacidade

> Objetivo do usuário: **gasto com Ads está muito alto**. Quer (1) enxergar onde o
> dinheiro vaza, (2) receber recomendação de onde cortar e (3) poder **automatizar**
> (pausar/ajustar campanha). Plataformas: **Mercado Livre Ads** e **Shopee Ads**
> (Meta/Google ficam pra depois).
>
> Este doc é o **contrato** entre frontend (`new-vision-pro`) e backend
> (`new-vision-backend`). Sem segredos aqui (partner keys / tokens só no `.env` do
> servidor — ver regra de ouro nº 3 do CLAUDE.md).

## Onde estamos hoje
- Ads é um **número digitado à mão**: `receitas.ads`, lançado por mês/conta em
  "Preencher resultados". Aparece só no **Lucro** (`Margem bruta → Após ADS →
  Margem real`) e no insight *"ADS representa X% do faturamento"* (`index.html` ~5917).
- **Não existe** nada por anúncio, por campanha, nem ACOS. Hoje dá pra ver a dor no
  total, mas não **onde** cortar.

## O conceito que destrava tudo
- **ACOS** = investimento em Ads ÷ faturamento gerado *por aquele Ads*. ACOS alto +
  pouca venda atribuída = dinheiro no lixo. É a métrica que aponta o ralo.
- **TACOS** = Ads ÷ faturamento **total** (macro). É o que dá pra calcular **hoje** com
  o dado manual. Útil pra teto/tendência, mas não diz qual anúncio cortar.
- A economia real está em **ACOS por anúncio/campanha** → e isso só vem das APIs de
  publicidade (ML Ads / Shopee Marketing).

---

## Contrato de dados (Supabase) — a fonte da verdade do front

O backend sincroniza e grava; o front só lê (chave publishable). Grão **diário** por
anúncio/campanha pra permitir qualquer recorte de período.

### Tabela `ads_metrics` (unificada ML + Shopee)
| coluna | tipo | nota |
|---|---|---|
| id | bigserial pk | |
| marketplace | text | `'ml'` \| `'shopee'` |
| conta_interna_id | text | mesmo padrão do resto (`moda_mix` / `look_store`) |
| campaign_id | text | id da campanha na plataforma |
| campaign_nome | text | |
| campaign_tipo | text | ex.: product_ads, brand, search… (o que a plataforma der) |
| anuncio_id | text | item_id ML / item_id Shopee (nulo se métrica só de campanha) |
| sku | text | quando a plataforma associar (liga com `produto_variacoes.sku`) |
| titulo | text | título do anúncio |
| data | date | **grão diário** |
| impressoes | int | |
| cliques | int | |
| investimento | numeric | gasto em R$ no dia |
| vendas_valor | numeric | faturamento atribuído (direto + indireto) |
| vendas_qtd | numeric | unidades atribuídas |
| acos | numeric | pode vir calculado pela plataforma ou derivado (investimento/vendas_valor) |
| cpc | numeric | custo por clique |
| moeda | text | default `'BRL'` |
| atualizado_em | timestamptz | |

**Único:** `unique(marketplace, campaign_id, anuncio_id, data)` (use string vazia, não
NULL, em `anuncio_id` pra métrica só-de-campanha, pra o unique funcionar).

### Tabela `ads_campanhas` (estado atual — necessária pra automação)
Snapshot do estado vigente de cada campanha (não é série temporal):
`marketplace, conta_interna_id, campaign_id, campaign_nome, status` (active/paused),
`orcamento_diario, estrategia_lance, lance_valor, atualizado_em`.
Único: `unique(marketplace, campaign_id)`.

> Observação: usar `ads_metrics` (unificada) deixa o front agnóstico de marketplace —
> a tela e a IA tratam ML e Shopee no mesmo código, só filtrando por `marketplace`.

---

## O que o BACKEND precisa fazer (`new-vision-backend`)

> Não fabricar endpoint aqui — mapear para a doc oficial vigente de cada API. Abaixo, o
> **nível de capacidade** exigido. Auth/segredos só no `.env` do servidor.

### Leitura (sync) — Fase 1 e 2
- **Mercado Livre — Mercado Ads / Product Ads:** OAuth do anunciante (pode exigir escopo
  extra de publicidade). Puxar campanhas, anúncios e **métricas diárias** (impressões,
  cliques, custo, vendas/unidades atribuídas diretas+indiretas, ACOS, CPC) → grava em
  `ads_metrics` + estado em `ads_campanhas`. Cron diário (fuso America/Sao_Paulo),
  espelhando o padrão das outras integrações.
- **Shopee — Marketing/Ads API:** mesma ideia (partner key é segredo; Shopee já está
  "em andamento" no projeto). Gasto, GMV/ROI atribuído, cliques, impressões por
  campanha/produto → mesma tabela `ads_metrics` com `marketplace='shopee'`.
- **Fallback inicial (se a API demorar):** **import CSV** dos relatórios de Ads (igual
  ao fluxo de custo por SKU). Permite começar a análise sem esperar a integração.

### Escrita (automação) — Fase 3/4, atrás do proxy `/api/*`
Endpoints que o front chama (todos **logam** em `historico_alteracoes` e exigem
confirmação no front):
- `POST /api/ads/campanha/pausar` · `POST /api/ads/campanha/ativar`
- `POST /api/ads/campanha/orcamento` (novo orçamento diário)
- `POST /api/ads/campanha/lance` (ajuste de lance/estratégia)
- (consulta) `GET /api/ads/overview`, `/api/ads/anuncios`, `/api/ads/campanhas` — opcional
  se o front já lê direto do Supabase; útil pra dados que não cabem em tabela.

---

## O que o FRONT + IA fazem (`new-vision-pro`, eu faço)

### Fase 0 — Painel macro, **sem backend** (dá pra fazer já)
Com o `receitas.ads` que já existe:
- **TACOS** (Ads ÷ faturamento) mês a mês, por conta e total, com tendência.
- Quanto o Ads **come do lucro** (já temos faturamento/lucro/ads por mês).
- **Teto/alerta:** definir meta de % (ex.: "Ads ≤ 12% do faturamento") e acender
  alerta quando estourar.
- (Opcional) separar a entrada manual de Ads por **marketplace** (ML vs Shopee), hoje
  é um número só.

### Fase 1/2 — Painel ACOS (depois que `ads_metrics` existir)
- **Aba Ads** dedicada (entra no `goTab`, padrão `rAds`): KPIs (investimento, vendas
  atribuídas, ACOS médio, TACOS), filtros por marketplace/conta/período.
- **Ranking de ralos:** anúncios/campanhas ordenados por pior ACOS / maior gasto sem
  retorno — "gastou R$ X, retornou R$ Y, ACOS Z%".
- **Drill-down por anúncio:** série diária de gasto × vendas atribuídas, ACOS no tempo,
  liga com margem real do produto (CMV) pra ver se o Ads ainda deixa lucro.
- **Simulador de economia:** "cortando estes N anúncios, economia ~R$ M/mês com perda
  de venda estimada baixa".

### Camada IA (casa com "agentes por setor" do roadmap)
- **Agente de Ads:** revisa periodicamente e entrega recomendações acionáveis —
  o que pausar, onde baixar lance, o que reforçar (ACOS bom + escala).

### Fase 3 — Execução assistida (write)
- Botões na tela: **Pausar / Ajustar orçamento / Ajustar lance**, chamando os endpoints
  do backend. **Sempre com confirmação** e log.

### Fase 4 — Automação por regras (opcional, último passo)
- Motor de regras: "auto-pausar se ACOS > X% por N dias **e** < Y vendas".
- **Travas de segurança obrigatórias:**
  - **Modo recomendação por padrão** (dry-run) — só sugere até o usuário ligar o auto.
  - **Aprovação manual** antes de executar (no início).
  - **Guardrails:** nunca pausar campeão de vendas; limites de variação de orçamento.
  - **Log de auditoria** de toda ação + **kill switch** global.

---

## Sequência recomendada
1. **Fase 0** (front, já): painel macro de TACOS + alerta de teto. Valor imediato.
2. **Fase 1** (backend ML + front): `ads_metrics` do ML → painel ACOS + IA recomenda.
3. **Fase 2** (backend Shopee): mesma tabela, tela já agnóstica.
4. **Fase 3** (backend write + front): execução assistida com confirmação.
5. **Fase 4**: automação por regras, com as travas acima.

> Para eu construir o backend, é preciso **adicionar o repo `new-vision-backend`** à
> sessão (ele é privado e fora do escopo atual). Enquanto isso, eu toco a Fase 0 e deixo
> o front pronto pro contrato acima.
