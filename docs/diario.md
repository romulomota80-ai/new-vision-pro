# Diário de bordo

Log das mudanças e decisões. O mais recente em cima.

## 2026-06-15

### Devoluções Shopee — ETAPA 0.5 (a API DEIXA responder? SIM)

Probe `node probe-returns-write.js` — testou os endpoints de **escrita** com um
`return_sn` FALSO ("PROBE_NO_OP_000000") + corpo mínimo (zero risco: nenhuma disputa
real tocada). Detalhe: a Shopee responde **HTTP 200 com erro no corpo**, então o que
classifica é o conteúdo.

**Resultado:** todos voltaram com "Return not found / doesn't exist / param error" —
ou seja, **passaram por auth+autorização** e só recusaram o SN falso. **Nenhum** erro de
permissão/escopo. Endpoints confirmados acessíveis e autorizados:
`confirm` (aceitar), `dispute` (contestar), `offer` / `accept_offer` (compensação),
`upload_proof` (subir prova), `cancel_dispute`, e leituras `get_return_dispute_reason`
e `query_proof`.

**Conclusão:** dá pra fazer o **"Responder" NATIVO** (contestar / subir prova / ofertar
dentro do app), não só link pro Seller Center. Validação end-to-end real só quando
aparecer uma disputa em estado acionável (ou testando 1 caso real com OK do Rômulo).
→ ETAPA 1 segue com resposta nativa no escopo.

### Devoluções Shopee — ETAPA 0 (amostra REAL da API, antes de cravar)

Probe `node probe-returns.js` na loja VERSSENE (shop_id 1269418534), 60 dias,
fatiado em janelas de 15 dias (a API limita o range a 15 dias, igual a de pedidos).
Endpoints: `GET /api/v2/returns/get_return_list` (params `create_time_from/to`,
`page_no`, `page_size≤40`) e `get_return_detail` (`return_sn`).

**Volume e perfil (60d, só a 1ª página de cada janela — é PISO, há `more:true`):**
- **160+ devoluções** em 60 dias. Volume alto (bate com o crescimento das vendas).
- **Status:** ACCEPTED 93 · CANCELLED 69 · PROCESSING 2.
- **Motivos (reason):** ITEM_NOT_FIT 71 ("não serviu") · NOT_RECEIPT 44 ("não recebi")
  · WRONG_ITEM 23 · DAMAGED_OTHERS 11 · FUNCTIONAL_DMG 5 · ITEM_MISSING 5 ·
  CHANGE_MIND 4 · SUSPICIOUS_PARCEL 1.

**O que a API entrega DE VERDADE (campos):** a própria **lista** já vem rica (quase não
precisa do detail): `return_sn`, `order_sn`, `status`, `reason`, `text_reason` (texto
livre do cliente, 1x), `refund_amount`, `amount_before_discount`, `currency`,
`create_time`, `update_time`, `due_date`, `needs_logistics`, `tracking_number`, `user`
(username/email), `item[]` (item_id, name, **variation_sku** = nosso SKU, item_price,
refund_amount, images), **`image[]` e `buyer_videos[]`** (provas do CLIENTE). O **detail**
acrescenta: `negotiation` (status, latest_offer_amount, offer_due_date),
`seller_proof` (seller_proof_status, **seller_evidence_deadline**),
`seller_compensation`, `logistics_status`, `is_arrived_at_warehouse`, endereços,
`validation_type`.

**⚠️ ACHADO QUE MUDA O DESENHO — NÃO existe chat/thread de mensagens.** A comunicação
**não é conversacional** (o único `"message"` no payload é o status da resposta da API).
O fluxo é **estruturado por estado**:
- **Cliente** abre a disputa com `reason` + `text_reason` + fotos + vídeos — uma vez só.
- **Vendedor** atua por estado, não por chat:
  - `seller_proof_status` = **PENDING** → enviar prova até `seller_evidence_deadline`.
    Amostra: NOT_NEEDED 108 · "" 55 · **PENDING 1**.
  - `negotiation` → ofertas de compensação (0 negociações ativas em 60d).
  - `validation_type` = **seller_validation** em 100%.

**Prazos REAIS (não é um só):** `due_date` (principal) · `seller_evidence_deadline`
(quando proof=PENDING) · `return_seller_due_date` · `return_ship_due_date` (logística) ·
`negotiation.offer_due_date`. Retorno físico: `needs_logistics`, `tracking_number`,
`logistics_status`, `is_arrived_at_warehouse`.

**Automático vs Manual (leitura do dado — a CONFIRMAR):**
- *Automático:* listar/detalhar, status, motivo, valor, SKU, prazos, provas do cliente,
  e marcar **"PRECISA RESPONDER"** = `seller_proof_status=PENDING` OU prazo vencendo
  enquanto acionável. A maioria (NOT_NEEDED) **não exige ação** — entra só como histórico.
- *Ponto de decisão:* **responder pela API** (upload_proof/dispute/offer) depende de
  endpoints de escrita + escopo do app — **ainda não probado**. Proposta v1: o sistema
  **rastreia + alerta + mostra provas/prazo** e dá **link pro Seller Center** pra
  responder; loga o resultado (recuperado/prejuízo) manualmente. Fase posterior: probar
  os endpoints de escrita e, se liberados, habilitar "Responder" no app.
- *Provas do cliente já vêm como URL da Shopee* (não precisa rebaixar). O bucket por
  devolução só faz sentido pras provas do VENDEDOR (se formos responder pela API).

**Pendente antes da ETAPA 1 (confirmar com o Rômulo):**
1. v1 = rastrear+alertar+link Seller Center (sem responder pela API), OU já probar os
   endpoints de escrita pra responder dentro do app?
2. "PRECISA RESPONDER" no v1 = `seller_proof_status=PENDING` + prazo vencendo
   (sem "mensagem nova", porque não há mensagens). Validar.
3. Só 1 loja conectada hoje; arquitetura por `shop_id` mesmo assim.

### Vendas sem custo — Shopee integrada (cadastro de CMV)

- A sub-aba **"Vendas sem custo"** agora mostra também as vendas **Shopee** sem custo
  (antes só ML), com badge 🟠 SHOPEE e opção **VERSSENE** no seletor de conta. O botão
  **+ Cadastrar** funciona igual (salva em `ml_skus_cmv` por SKU).
- Backend `GET /api/shopee/sem-custo`: vendas pagas cujo SKU não tem custo em
  `ml_skus_cmv`. `GET /api/shopee/vendas` passou a calcular **CMV/margem AO VIVO**
  (join `ml_skus_cmv` na leitura) — então **cadastrar o custo reflete na hora** na
  margem e o SKU some da lista, sem esperar re-sync.
- Lembrete: cobertura de custo Shopee ainda baixa (~11%) — agora dá pra ir preenchendo
  pela própria aba.

### Vendas — Shopee AO VIVO (igual Mercado Livre)

- Corrigido o rumo: a aba Vendas precisa das vendas **ao vivo**, não do escrow (que só
  fecha dias depois). Espelhado o mecanismo do ML.
- Nova tabela **`shopee_orders`** (formato `ml_orders`, 1 linha/pedido), alimentada por
  `get_order_list`+`get_order_detail`. `GET /api/shopee/vendas` agora lê dela (ao vivo).
- **Comissão estimada** pela tabela oficial CNPJ (o escrow real reconcilia depois por
  order_sn) + margem via `ml_skus_cmv`. Frete fica 0 ao vivo (só fecha no escrow).
- **Mantido atualizado:** cron a cada 20min (06-23h) sincroniza os últimos 3 dias;
  endpoint `POST /api/shopee/push` pronto pro **webhook em tempo real** (falta configurar
  a Push URL no painel do app → `https://newvisionpro.com.br/api/shopee/push`).
- **Escopo do backfill:** começamos **de hoje pra trás** (última ~semana já carregada:
  08–15/06) e a janela cresce sozinha daqui pra frente. Sem puxar 60d de histórico.
- `shopee_repasses` (escrow) segue intacto p/ Auditoria/Saques/Carteira/Fechamento.
- **Pendência:** configurar a Push URL no painel Shopee p/ tempo real fino; CMV ainda
  cobre só ~11% dos SKUs (margem superestimada onde falta custo).

### Vendas — Shopee integrada na aba Vendas (multi-marketplace)

- A aba **Vendas** (estilo Mercado Turbo) agora mostra **ML + Shopee juntos**, mesma lógica
  por conta, com **badge do marketplace** (🟡 ML / 🟠 SHOPEE) na coluna Conta e a opção
  **VERSSENE (Shopee)** no seletor de conta.
- Backend `GET /api/shopee/vendas` (pg, só leitura): explode cada pedido COMPLETED em
  **1 linha por item** (model_sku, qtd, preço) e normaliza no MESMO formato do `ml_orders`
  (preco_total, comissao_ml, frete_seller, cmv_total_snap, mc_valor, mc_pct…). Margem =
  líquido (escrow rateado por item) − custo (`ml_skus_cmv` por model_sku) − imposto.
- Frontend: `rVdVisao` busca a Shopee no mesmo período e mescla em `VD_DADOS`; ML marcado
  `marketplace='ML'`. Nenhuma mudança no comportamento do ML.
- **Caveat (CMV):** só **36 de 315** SKUs Shopee têm custo no `ml_skus_cmv` (~11%) — as
  outras vendas aparecem com **margem sem custo** (superestimada), igual a aba "Vendas sem
  custo" do ML. Mapear os custos restantes é a próxima parada (ver pendência de CMV).
- JS validado (`node --check`). Push na `main` → Netlify.

## 2026-06-14

### Shopee — sub-aba Saques (reconciliação com o extrato bancário)

- Nova sub-aba **🏦 Saques** na aba Shopee: mostra o que foi sacado **e se realmente
  caiu na conta**.
- Backend `GET /api/shopee/saques` (pg, só leitura): pareia `WITHDRAWAL_CREATED`
  (solicitação + valor) com `WITHDRAWAL_COMPLETED` por `withdrawal_id`, e **cruza com o
  `extrato_bancario`** — match por **valor idêntico + crédito PIX "SHPP"/Shopee** na
  janela da data. Traz `caiu_na_conta`, data e nome da conta.
- KPIs: nº de saques, total sacado, **confirmado na conta**, **não localizados**.
- **Resultado real (60d):** 9 saques, **R$268.185,77 sacado, 100% confirmado** na conta
  **ITAÚ CNPJ LAYANE** (todos batem com PIX "SHPP" no extrato), **0 não localizados**.
- JS validado (`node --check`). Push na `main` → Netlify.

### Shopee — fechamento 60d concluído + KPI de devoluções

- **Sync completo:** 19.126 pedidos COMPLETED auditados. **Total repassado
  R$670.173,09. ZERO cobranças de comissão a maior (100% OK)** — a Shopee cobrou
  conforme a tabela oficial CNPJ no período.
- **Devoluções:** novo KPI no Resumo somando o que a Shopee puxou de volta da carteira
  (estorno de repasse `ESCROW_VERIFIED_MINUS` + reembolso `ADJUSTMENT_FOR_RR…`):
  **−R$5.923,05 em 122 movimentos**. Agregado no `/repasses/resumo` (pg, só leitura).
- Rótulo `ESCROW_VERIFIED_MINUS` ficou **"Estorno de repasse (devolução)"** (era
  "Estorno de repasse") pra não confundir com o reembolso. *Estorno de repasse = venda
  já repassada que é devolvida depois e a Shopee debita de volta o líquido do pedido.*

### Shopee — Carteira: tipos de transação traduzidos pra PT

Os tipos vinham com o código cru da Shopee. Adicionado `SH_TIPO_LABEL` (mapa
frontend, só exibição — não altera o dado) + fallback que limpa qualquer código
não mapeado (`_`→espaço, Primeira maiúscula), pra **nunca** aparecer código cru.
Aplicado na **Carteira** (com ícone por categoria) e na **Auditoria**.

Tipos mapeados (lista REAL do `GROUP BY shopee_carteira`):
- `ESCROW_VERIFIED_ADD` → Repasse de venda
- `ESCROW_VERIFIED_MINUS` → Estorno de repasse
- `ADJUSTMENT_FOR_RR_AFTER_ESCROW_VERIFIED` → Reembolso (devolução)
- `WITHDRAWAL_COMPLETED` → Saque concluído
- `WITHDRAWAL_CREATED` → Saque solicitado
- `RETURN_COMPENSATION_SERVICE_ADD` → Compensação por devolução
- `ADJUSTMENT_CENTER_ADD` → Crédito por item perdido/danificado
- `SPM_DEDUCT` → Recarga de ADS (anúncios)
- `''` (vazio) → Compensação por objeto perdido
- (internos auditoria) `comissao_maior` → Comissão a maior · `ok` → OK

### Shopee — aba no app (frontend) PRONTA

- Nova aba **🛒 Shopee** no menu lateral (padrão das outras: `.scr` + sub-abas
  `.lbar/.ltab`, registrada no `goTab`), com seletor de loja no topo.
- **5 sub-abas**, lendo dos endpoints REAIS `/api/shopee/*` (sem schema novo):
  - **Resumo** — KPIs do fechamento (período, nº pedidos, total repassado, **cobrado a
    maior**, divergências, % OK). Mostra "⏳ sincronizando…" com parciais se o sync roda.
  - **Repasses** — lista por pedido (order_sn, data, valor, comissão, taxa serviço,
    frete, líquido) + filtro de período.
  - **Auditoria** (prioridade) — divergências ordenadas por **delta desc**, ESPERADO ×
    REAL × DELTA (vermelho), badge de severidade, filtros (período, toggle "só com
    divergência") e **Exportar CSV**.
  - **Carteira** — movimentos do wallet (`shopee_carteira`); **Taxas** — tabela oficial
    CNPJ (leitura; edição em breve).
- Backend ganhou os GET de leitura (`/repasses/resumo|/repasses|/repasses/auditoria|
  /carteira|/taxas`) — **somente leitura**, sem mexer no schema nem no job de sync.
- JS validado (`node --check` em todos os `<script>`). Deploy: push na `main` → Netlify.
- **Pendências:** validar no navegador (guia anônima); sync de 60d ainda finalizando
  (parcial: ~8,5k pedidos, R$460k repassado, **0 cobranças a maior até agora**); edição
  da aba Taxas e re-sync completo da Carteira ficam pra próxima.

### Shopee — go-live + auditoria de repasses (Claude Code terminal)

**Captura (Fase 1) — CONCLUÍDA.**
- App **aprovado/Online** → viramos pra **produção (live)**: Partner ID `2036729`,
  host `partner.shopeemobile.com`, `SHOPEE_ENV=live` (segredo só no `.env`).
- Assinatura HMAC validada no live (auth_partner → HTTP 302 login). **Loja Verssene
  conectada** (`shop_id 1269418534`, conta `verssene_shopee`); token com refresh automático.

**Auditoria de comissão — REGRA DEFINIDA E VALIDADA.**
- Fonte da verdade: `get_escrow_detail` (por pedido) traz a comissão real + a quebra por regra.
- "Esperado" = **tabela oficial CNPJ**: `comissão = %faixa × valor_item + taxa_fixa × qtd`
  (faixa pelo preço **unitário**). Gravada em `shopee_taxas_esperadas` (editável).
- **Validada contra ~200 pedidos reais: bateu 99,5%.** 3 descobertas que evitam falso-positivo:
  1. o "%" da tabela = `commission_fee + service_fee` **somados** (não a comissão isolada);
  2. a **taxa fixa é por unidade** (×quantidade), não por pedido;
  3. **subsídio PIX** (`pix_discount`) é do lado do comprador (bancado pela Shopee) — **não**
     reduz a comissão do vendedor; base da comissão é **só o item** (sem frete).

**Schema criado (DDL aditivo, sem drop):** `shopee_repasses` (1 linha/pedido, ~30 campos do
escrow + `comissao_esperada`/`divergencia_comissao`), `shopee_carteira` (wallet/saldo),
`shopee_taxas_esperadas` (config de taxas).

**Decisões.**
- Auditar **só vendas reais (COMPLETED)** — ~19,1 mil em 60 dias (~320/dia). Cancelados (4 mil)
  não têm repasse/comissão → fora; estornos pós-repasse vêm da carteira
  (`ADJUSTMENT_FOR_RR_AFTER_ESCROW_VERIFIED`).
- `data_pedido` sai do prefixo `YYMMDD` do `order_sn` (== create_time, confirmado) — sem chamada extra.

**Pendências.**
- 🔄 **Fechamento (Fase 3):** sync dos 19,1k repasses **rodando** — publicar aqui o total
  repassado (escrow) + nº e valor das cobranças de comissão a maior quando concluir.
- Carteira: re-rodar os 60 dias completos (parcial gravado: ~4,1k transações).
- Frontend: aba Shopee (repasses + auditoria) — backend já expõe `GET /api/shopee/repasses/auditoria`.

## 2026-06-12/13

### Shopee — app criado e submetido pra produção (2026-06-13)
- App **"New Vision Financeiro"** criado no Shopee Open Platform. Categoria
  "Sistema interno do vendedor"; **acesso a dados sensíveis liberado**; API **V2**.
- Domínio de redirecionamento (teste e produção): `https://newvisionpro.com.br`.
- **Callback de produção (no backend):** `https://newvisionpro.com.br/api/shopee/callback`
  — **Opção A**, mesmo padrão do Mercado Livre (já comprovado em produção).
- **IP allowlist:** IP do backend Hetzner (resolve de `api.newvisionpro.com.br` → `5.75.186.38`).
- **Credenciais de TESTE** disponíveis (Partner ID de teste `1235756` + chave de teste)
  → usar pra construir o scaffolding no **sandbox** enquanto a produção é aprovada.
- **Produção:** pedido "em análise" — resultado por e-mail em até 24h. As credenciais
  **LIVE** (partner_id + key de produção) só saem **após a aprovação**.
- 🔒 **Partner Key NUNCA no repo/chat** — vai só no `.env` do servidor.

### Sincronização do GitHub com o site real
- Descoberto que o repositório estava parado em **8 de maio**, enquanto o site em
  produção evoluiu muito (Fluxo de Caixa, Vendas, Produtos, Estoque, Conciliação…).
  O deploy vinha sendo feito fora do GitHub.
- Trazido o **código real do site** (`index.html`, ~8.300 linhas) pro repositório.
- Confirmado que a **Netlify publica automaticamente no push da `main`** → GitHub
  voltou a ser a fonte oficial.

### Feature: Extrato bancário por conta
- Novo botão **📄 Extrato** no card de cada conta (Fluxo de Caixa → Contas), ao lado
  do 📋 Histórico.
- Abre um modal com as transações do banco agrupadas por dia; cada uma com badge de
  vínculo: ✅ **custo** / 🔄 **movimentação** / ⚠️ **sem vínculo**.
- Casamento (transação ↔ lançamento) por **valor + data + nome** (função `ebMatch`).
- Dados em `extrato_bancario`. O vínculo conta↔banco usa `openfinance_account_id`.
- **Pendente:** o modal ainda abre vazio porque o `account_id` que o backend grava ao
  "Vincular" pode não bater com o `account_id` carregado em `extrato_bancario`.
  Próximo passo: comparar os ids reais (`GET /api/bancos/conexoes` × `extrato_bancario`)
  e gerar o UPDATE que liga as transações às contas certas.

### Feature: titular nos cards
- Card de **Conta** e de **Banco** agora mostram 👤 titular (PF vem do banco; PJ puxa
  da conta vinculada ou mostra o CNPJ).

### ⚠️ Incidente (lição aprendida)
- Um SQL com `drop table contas_bancarias` recriou a tabela num formato antigo (sem a
  coluna `nome`/`openfinance_account_id`), quebrando a aba **Bancos** e o **Capital**.
- **Causa raiz:** agir sobre suposições do schema em vez de ler o código real; e mandar
  vários arquivos SQL parecidos (virou campo minado no editor).
- **Recuperação:** reconstruídas as contas originais (ids 1-8) a partir do
  `historico_caixa` (nomes) e `historico_alteracoes` (últimos saldos). Renomeada a
  coluna `account_id` → `openfinance_account_id` (o backend exige esse nome).
- **Regras que ficam (ver CLAUDE.md):** não dropar tabelas sem OK; explicar SQL
  destrutivo antes; um arquivo único por vez; sempre apagar o editor antes de colar.

### Próximas paradas
- Resolver o vínculo do Extrato (ids do backend × extrato_bancario).
- **Integração API Shopee** (Open Platform): criar o app (Partner ID + Partner Key),
  Callback `https://newvisionpro.com.br/api/shopee/callback`, módulos Order/Logistics/
  Payment/Product/Shop. Espelhar o padrão de Mercado Livre/Pago (OAuth → tokens →
  sync de repasses → vendas/comissões/CMV). Plano detalhado feito no Claude Code do
  terminal.
- Sync automático diário do extrato.
- Revisar segurança: RLS do Supabase e repositório privado.
