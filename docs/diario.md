# Diário de bordo

Log das mudanças e decisões. O mais recente em cima.

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

**Validação antes de programar:** comparar o saldo disponível lido via Open Finance
com o que aparece no app do Mercado Pago do usuário (tem que bater).

**Onde fica na UI:** Fluxo de Caixa → conta Mercado Pago + aba Saques & Recebíveis
(mesmo padrão "caiu na conta?" já usado na Shopee).

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
