# Diário de bordo

Log das mudanças e decisões. O mais recente em cima.

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
