# Diário de bordo

Log das mudanças e decisões. O mais recente em cima.

## 2026-06-21

### Romaneio por pedido (Fornecedores)
- Cada **pedido** (card no detalhe do fornecedor, aba Fornecedores) ganhou botão
  **📎 Anexar romaneio** / **📷 Ver romaneio** (foto). Upload pro Supabase Storage
  (bucket `comprovantes`, prefixo `romaneios/`), grava a URL em `pedidos.romaneio_url`
  e abre no viewer existente (`abrirViewer`). Funções: `pedRomaneioUpload` /
  `_pedRomaneioEnviar`. `PEDIDOS` agora carrega `romaneio` de `romaneio_url`.
- ⚠️ **Requer rodar no Supabase** (ALTER aditivo, não destrutivo):
  `alter table pedidos add column if not exists romaneio_url text;`
- **Adiado (a pedido do usuário):** tirar a criação de pedido da aba Boletos/PIX e
  deixar só na aba Fornecedores. Mapeado mas não feito agora — hoje o form de pedido
  parcelado mora na aba Boletos/PIX e Fornecedores só tem um atalho que redireciona
  pra lá (`foNovoPedidoParcelado` → `goTab('bo')`).

## 2026-06-20

### Plano: Mercado Pago no Fluxo de Caixa (resolver o double-count da antecipação)

**Contexto do problema.** A integração atual do MP puxa recebíveis da API
(`/v1/payments/search` → `mp_releases` → `recebiveis_programados`). A antecipação no
MP é **nível conta**, não nível pagamento: quando o lojista antecipa, o dinheiro vira
"disponível" na carteira, mas o `money_release_date` de cada pagamento continua no
futuro/pending. Resultado: o sistema conta **a mesma grana duas vezes** (no disponível
real **e** como "a receber"). A API de saldo do MP está bloqueada (403/404).

**Descoberta (2026-06-20).** Conectamos o **Mercado Pago Empresas via Open Finance**
(conector mcp.ai/Pluggy id **665**). O que o Open Finance entrega:
- A **conta carteira (pré-paga)** com o **saldo disponível real** — verdade lida da
  fonte (resolve o 403 da API de saldo).
- O **extrato detalhado** da carteira, incluindo eventos **"Liberação de dinheiro"**
  (cada recebível que vira disponível — inclusive via antecipação), além de
  reembolsos, "dinheiro retido", Pix de entrada/saída. Volume altíssimo (dezenas de
  milhares de transações/mês, muito ruído de devolução do ML).
- **NÃO entrega** uma linha separada de "a receber" (agenda de recebíveis futuros) —
  esse número continua tendo que vir da API do MP.

**Fluxo real do dinheiro (confirmado com o usuário):** venda cai no MP →
(opcional) antecipa, movendo "a receber" → "disponível" dentro do MP → o lojista
**paga fornecedores (Pix) e saca pra outras contas** a partir do MP. O saldo
disponível do Open Finance já reflete todas essas saídas — é a foto real da carteira.

**Modelo escolhido (mata o double-count, tudo dentro do MP — sem depender de banco):**
- **"Quanto eu tenho" no MP = saldo disponível REAL do Open Finance**, não mais a soma
  da API.
- **"Quanto vou receber" = "a receber" da API**, porém só o que **ainda não virou
  "Liberação de dinheiro"** no extrato. Antecipou → libera → sai da fila de "a receber".

#### Escopo desta entrega (apenas 1 e 2; o 3 fica pra depois)

**1) Mercado Pago como CONTA no Fluxo de Caixa**
- Espelhar o MP como uma "conta" (igual Itaú/Nubank) usando a conexão Open Finance
  já criada (conector 665). Usar o **saldo disponível da carteira (pré-paga)** como
  `saldo_atual` real da conta MP.
- O card mostra: saldo disponível (real, Open Finance) + "a receber" (API, ver item 2).
- Backend: ler o saldo da conta carteira do MP via Open Finance (mesma camada que já
  traz Itaú/Nubank) e gravar/atualizar a conta MP no Supabase. Pegar os ids reais da
  conexão em runtime (`list_connections`/`list_accounts`) — **não hardcodar** ids.
- ⚠️ Há **2 conexões duplicadas** do MP (o usuário conectou 2x). Manter **uma só** e
  remover a duplicata antes de ligar a sync, pra não dobrar saldo.

**2) "A receber" reconciliado pelas "Liberações de dinheiro" (anti-double-count)**
- Continuar puxando `recebiveis_programados` da API do MP (previsão).
- Cruzar com o extrato Open Finance da carteira: todo evento **"Liberação de dinheiro"**
  (CREDIT, categoria Investments) = recebível que já caiu na carteira → **dar baixa**
  no "a receber" correspondente (marcar como liberado/realizado).
- Como casar (uma antecipação libera muitos pagamentos de uma vez): casar por
  **agregado** (valor/bloco/data), não 1-a-1. Filtrar o ruído (reembolso, dinheiro
  retido, débito por dívida de devolução) — só "Liberação de dinheiro" abate recebível.
- Efeito no Fluxo de Caixa: o "a receber" exibido passa a ser só o que **realmente**
  ainda não liberou. Disponível (real) + a-receber (líquido) deixam de se sobrepor.

**Fora de escopo agora (item 3, depois):** saídas do MP (Pix) alimentando
fornecedores/custos automaticamente; separar "Pix pra fornecedor" de "saque pra conta
própria".

**Validação com o app + decisão (2026-06-20).** O usuário leu os 3 baldes do app do
MP. Isso revelou um **terceiro balde** que o modelo de 2 baldes não tratava:
- **Disponível** — dá pra sacar/Pix agora (hoje estava zerado).
- **Retido / a liberar** — dinheiro que já caiu na carteira mas está preso por alguns
  dias. Não é parcela futura, mas também não dá pra usar hoje.
- **A receber** — agenda de parcelas futuras (vem da API do MP).

**Regra final travada com o usuário:**
- **Fluxo de Caixa → conta MP mostra APENAS o SALDO** (= saldo disponível real do Open
  Finance). Retido e a-receber **não** entram no saldo da conta.
- **Aba "Recebíveis"** concentra **tudo que ainda vai cair das plataformas** = retido +
  a-receber (e, depois, o mesmo padrão pra Shopee/ML/TikTok). Cada item só vira saldo
  quando **cair de verdade**. Encaixa na aba já existente "💸 Saques & Recebíveis"
  (sub-abas por plataforma, lendo `recebiveis_programados`).

**A validar ao programar (factual, precisa rodar o backend):** o "saldo disponível" que
o Open Finance devolve para a carteira MP vem **só com o disponível** ou **disponível +
retido**? Se vier só o disponível, o retido precisa ser somado à aba Recebíveis a partir
dos eventos de "dinheiro retido" do extrato — não do saldo da conta.
## 2026-06-18

### Mercado Pago — ANTECIPAÇÃO no Fluxo de Caixa (investigação / ETAPA 0)

**Problema:** quando se ANTECIPA recebíveis na MP (saca antes da data), a projeção de
"dinheiro a cair" não desconta — o fluxo conta **em dobro** (o valor antecipado que já
caiu no banco + a projeção futura do mesmo recebível).

**O que olhei na API REAL** (contas LOOK e MODA, tokens `MP_*_ACCESS_TOKEN` no `.env`):

- **(a) O que vai cair:** vem de `GET /v1/payments/search` → tabela `mp_releases` →
  `recebiveis_programados` (via `/api/mp/aggregate-releases`). Cada pagamento aprovado
  traz `money_release_date` (data futura) e `money_release_status`. Na amostra recente
  (LOOK, abril+) **todos `pending`**, `money_release_schema=null`, com data futura.
- **(b) O que já foi liberado:** o sync já **pula** pagamentos com
  `money_release_date < hoje` (linha "pulados_ja_caiu" em `mercadopago.js`). Ou seja, o
  sistema só projeta o que ainda não liberou — **no nível do pagamento**.
- **(c) A antecipação — causa-raiz:** a antecipação é um evento **de CONTA**, não do
  pagamento. Ao antecipar, o `money_release_date` de cada pagamento **continua na data
  futura original** e o status segue `pending`. Logo `recebiveis_programados` fica
  **cego à antecipação** e segue projetando "vai cair", mesmo o dinheiro já tendo saído
  via antecipação → **contagem em dobro**.

**Endpoints testados (token de pagamentos):**
- `GET /v1/account/balance` → **404**; `GET /users/me/.../balance` → **403 forbidden**.
  → **Não dá pra ler "saldo disponível vs a liberar" pela API** com esse token.
- Endpoints de antecipação direta (`/anticipations`, `/withdrawals`, variações asgard)
  → todos **404/403**. → A API pública **não expõe a antecipação como recurso próprio**.
- `GET /v1/account/settlement_report/*` → **funciona**. Config: `format=CSV`,
  `separator=";"`, **`include_withdraw=true`** (inclui saques/antecipações). É o
  relatório **de conta** — única fonte na API onde a antecipação aparece explícita.
  Geração é assíncrona/manual e estava **lenta** (>8 min `pending`); captura da linha
  real de antecipação (type/description/taxa/data) **em andamento**.

**Conclusão preliminar (a validar com a sessão web da MP):**
- A antecipação **não dá pra abater pela API per-payment** (o recebível não muda) nem
  pelo saldo (403).
- **Fonte da verdade = o que JÁ CAIU no banco** (Open Finance / extrato Itaú):
  já caiu = recebido, **não** conta como "a cair"; só entra como recebível futuro o que
  ainda não caiu. Espelha a reconciliação "caiu na conta?" já feita na Shopee.
- O settlement report serve como **confirmação secundária** (mostra a antecipação
  explícita), mas por ser manual/assíncrono não é a fonte primária.

> ⏸️ **NÃO construir a lógica final** até o Rômulo confirmar a amostra real na sessão
> web da MP. Esta entrada é só o levantamento (ETAPA 0).

## 2026-06-17

### Devoluções Shopee — aba "Recebidas" + fix do falso "precisa responder"

Rômulo notou que "Precisa responder" mostrava devoluções que **não** precisavam de
resposta: o produto ainda estava **em trânsito** (a caminho), só faltava chegar — e só
então, se quiser, ele disputa. Causa: `devPrecisaAcao` marcava `precisa_acao=true` para
qualquer `return_seller_due_date` aberto, mesmo com a logística pendente.

**Correções (`routes/shopee.js`):**
- `precisa_acao` **não** dispara mais pelo prazo enquanto o produto está `a_caminho` ou
  `aguardando` postagem — só na **chegada** (`fase=chegou`) ou quando não há logística
  pendente. Corrigiu 25 falsos positivos (migraram pra "A caminho").
- Nova aba **📥 Recebidas** (`filtro=recebidas` = `precisa_acao=true` e `fase=chegou`):
  produto chegou, conferir e aceitar/disputar. "Precisa responder" passou a conter só
  reclamações/negociações novas aguardando resposta. Ficou 13 + 13 (antes 26 juntos).
- Doc de referência: `new-vision-backend/docs/devolucoes-abas.md` (regra de buckets
  disjuntos por precedência: recebidas > precisa_acao > logística > status).

**Frontend:** aba Recebidas antes de Precisa responder; badge da sidebar soma
`recebidas + precisa_acao`; texto da Logística aponta pra Recebidas na chegada.

## 2026-06-16

### Devoluções Shopee — custo real de caixa + culpa (quem paga o frete)

Pergunta do Rômulo: "nem toda devolução eu pago — preciso ver quando pago frete e
quanto." Investigado no escrow real (`get_escrow_detail` → `shopee_repasses`) e
**confirmado na web** (política Shopee BR + docs internacionais FSF/RSF).

**Mecânica descoberta (e provada nos dados):**
- Em **venda normal**, `shopee_shipping_rebate = actual_shipping_fee` → o vendedor paga
  **R$0** de frete (a Shopee subsidia 100%; o "grátis" do cliente é a Shopee pagando).
- Em **devolução**, a Shopee às vezes **cancela o subsídio** (`rebate → 0`) e joga o
  frete de ida (FSF) + o reverso (RSF) no vendedor. O `valor_liquido` (escrow_amount_
  after_adjustment) negativo é o caixa que de fato saiu.
- **Cruzamento motivo × pagamento (prova):** culpa do vendedor (WRONG_ITEM 46% paga
  ~R$9, FUNCTIONAL_DMG 60% paga ~R$12, ITEM_MISSING) concentra o custo; arrependimento
  (ITEM_NOT_FIT, CHANGE_MIND) quase nunca paga (centavos). **89% do que o Rômulo pagou
  de frete foi em devolução de culpa dele.**

**Totais reais (histórico):** de R$83,7k reembolsados aos clientes, só **R$2.558 saíram
do caixa** (frete ida R$1.977 + volta R$650); 157 devoluções custaram, **1.034 a Shopee
cobriu**, 159 pendentes de repasse.

**Backend (`routes/shopee.js`):** `GET /devolucoes` e `/devolucoes/metricas` agora fazem
LEFT JOIN em `shopee_repasses` por `order_sn` e devolvem por item `custo_caixa`,
`frete_ida`, `frete_volta`, `culpa` (vendedor/comprador/neutro via motivo) e
`repasse_pendente`; métricas somam tudo + quebra por culpa. Fonte da verdade = escrow,
não chute.

**Frontend (`index.html`):** badge de **culpa** (🔴 sua / 🟢 cliente / ⚪ neutro) e de
**custo** (💸 Você pagou R$X / 🟢 Sem custo / 💰 pendente) em cada card; bloco de custo
de caixa no modal (ida/volta); seção nas Métricas com "frete que você pagou" + quebra
por culpa. JS validado (7 blocos).

## 2026-06-15

### Devoluções Shopee — FASE 5 (responder nativo pela API + provas + Telegram)

A devolução deixou de ser só leitura: agora dá pra **responder direto pelo app**.

**Descoberta segura da API (probes):** os 8 endpoints de escrita da Shopee Returns v2
existem e o app tem acesso (confirmado com `return_sn` falso — recusa só por "não
existe", nunca por permissão). Shapes travados rodando READs num return real + body
incompleto (erro de "param faltando" sem efetivar):
- `confirm` / `accept_offer` / `cancel_dispute` → `{return_sn}`
- `dispute` → `{return_sn, email, dispute_reason (int do enum), dispute_text_reason}`
- `offer` → `{return_sn, proposed_solution (ex.: RETURN_REFUND/REFUND), proposed_compensation_amount?}`
- `upload_proof` → `{return_sn, proof_image[], proof_video[]}`
- `get_return_detail` traz `negotiation` (oferta do comprador + `counter_limit`) e
  `seller_proof` — **fonte autoritativa do estado**, usada pra decidir os botões.

**Backend (`routes/shopee.js`):** 8 endpoints novos. Cada ação chama a API → grava
evento na timeline (`autor=vendedor`) → re-busca `get_return_detail` e re-mapeia a linha
(status_interno/precisa_acao autoritativos; preserva resultado_valor/resolvida_em/
responsavel) → seta campos manuais. Erro soft da Shopee (HTTP 200 + `{error}`) **não**
altera o banco. READs auxiliares: `/devolucoes/detalhe`, `/devolucoes/motivos-disputa`.

**Provas do vendedor (5C):** `POST /devolucoes/upload` (base64 → Supabase Storage,
bucket público `devolucoes-provas`, arquivos em `{return_sn}/`) → URLs públicas que
alimentam o `upload_proof`. Limpeza automática 30 dias após a devolução resolver.

**Alerta Telegram (5E):** ao sincronizar, devoluções **novas que já precisam de resposta**
disparam mensagem (HTTP direto, sem instanciar 2º bot). Idempotente → sem repetição.

**Cron (`server.js`):** sync de devoluções a cada 2h (mantém prazos frescos — antes o
badge contava devoluções **já vencidas**, pois o sync era manual) + limpeza de provas 04h.

**Frontend (`index.html`, namespace `dv*`):** o modal de detalhe ganhou painel de ações
dirigido pelo `/detalhe` — Aceitar devolução / Aceitar oferta (R$ X) / Contraproposta /
Disputar (com dropdown de motivos + texto) / Enviar provas (upload) / Cancelar disputa.
Thread (timeline) com ícones por tipo de evento; prazo com alerta visual (já existia).
Após cada ação: recarrega estado, timeline e badge. JS validado (7 blocos, `node --check`).

### Devoluções Shopee — FASE 4 (polimento do frontend + produção)

Sub-aba **Devoluções** dentro da aba Shopee finalizada e publicada em produção
(`netlify deploy --prod`):
- **Namespace próprio** pra não colidir com o código de repasses da Shopee:
  `shAPI`→`dvAPI`, container `sh-dv-body`→`dv-body`, estado `SH_CONTA`→`DV_CONTA`
  (mais `DV_VIEW`/`DV_MES`/`DV_ROWS`/`DV_LOJAS`). O bloco de devoluções (≈8621-8780)
  ficou independente; só compartilha utilitários (`shEsc`).
- **Badge no boot:** `rShopee()` agora chama `dvAtualizaBadge()`, então o número de
  devoluções que "precisa responder" (`?filtro=precisa_acao`) já aparece no chip
  `sb-badge-dv` assim que a aba Shopee abre — espelhando o badge de Boletos. O badge
  também atualiza ao trocar de loja e ao abrir a sub-aba.
- JS validado (extração dos 7 blocos `<script>` inline + `node --check`, 0 erros).

**Em aberto (plano de devoluções):** thread de mensagens + galeria de provas
(Supabase Storage, expira 30d após resolver), prazo+alerta visual, responder nativo
pela API (Fase 5), notificação Telegram (opcional).

### Devoluções Shopee — FASE 3 (endpoints de leitura)

`routes/shopee.js`, via `pgPool` (agregação):
- `GET /devolucoes?conta=&filtro=&busca=&limit=` — filtros precisa_acao (default) |
  novas | em_disputa | favor | contra | todas; precisa_acao ordena por prazo (urgência).
- `GET /devolucoes/produtos?conta=&mes=` — ranking por SKU: qtd, **% devolução**
  (devoluções ÷ vendas do SKU em `shopee_orders`), motivo top, prejuízo.
- `GET /devolucoes/metricas?conta=&mes=` — favor/contra, R$ recuperado/prejuízo, taxa de
  sucesso, motivo top, tempo médio (data_status − data_solicitacao).

**Insights que já saltaram (60d):** taxa de sucesso **42%** · R$ 32.507 recuperado vs
**R$ 45.937 de prejuízo** · motivo top "não serviu". **CAL-CAR-PRETO-GG com 19,9% de
devolução** (54/271) e -G 17,8% — calça cargo preta tem taxa altíssima por modelagem.

Próximo: Fase 4 (frontend — sub-aba Devoluções no padrão visual novo).

### Devoluções Shopee — FASE 2 (sync por loja, idempotente)

`POST /api/shopee/devolucoes/sync` (body `{conta, dias=60}`) + `GET /devolucoes/status`
no `routes/shopee.js`. Pagina `get_return_list` em janelas de 15d (todas as páginas),
dedupe por `return_sn` (Map), `upsert` por PK → **idempotente** (re-sync não duplica;
não mexe em resultado_valor/resolvida_em/responsavel). Seed de evento `abertura` só pras
novas.

- **1.343 devoluções/60d** carregadas, 0 erros (volume bem maior que a amostra de página
  única sugeria — a loja tem MUITA devolução).
- **status_interno** (terminal tem prioridade): ACCEPTED→contra, CANCELLED→favor, senão
  proof PENDING/negociação→em_disputa, senão nova. **precisa_acao**: proof PENDING OU
  negociação OU prazo <48h — **nunca** em status terminal (corrigido um edge case de
  CANCELLED com prova velha que vinha marcado como ação).
- Distribuição: **contra 749 · favor 542 · nova 35 · em_disputa 17**; **21 precisam de
  ação**. 1.043 com retorno físico; 194 SKUs distintos.

Próximo: Fase 3 (endpoints de leitura: lista filtrada + produtos + métricas).

### Devoluções Shopee — FASE 1 (DDL aditivo)

`sql/devolucoes.sql` aplicado via `run-sql.js` (a SERVICE_KEY não roda DDL). Aditivo,
sem drops:
- **`devolucoes`** — PK natural `return_sn` (sync idempotente por upsert). Campos: loja,
  order_sn, sku/produto, valor/valor_antes_desc, motivo/motivo_texto, data_solicitacao,
  status_shopee, **status_interno** (nova|em_disputa|favor|contra), prazo_resposta,
  seller_proof_status, needs_logistics/tracking/logistics_status, **precisa_acao**,
  comprador, **provas_cliente** (jsonb, URLs Shopee), responsavel (opcional),
  resultado_valor (recuperado/prejuízo), resolvida_em, raw_json. Índices por shop,
  status_interno, precisa_acao, data, sku, order, prazo.
- **`devolucoes_eventos`** — timeline estruturada (abertura|status|prova_cliente|
  prova_vendedor|oferta|disputa|nota), FK `return_sn` on delete cascade. Substitui o
  "chat" que a API não tem.

Próximo: Fase 2 (sync por loja, idempotente, janelas de 15d + mapeamento de status).

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
