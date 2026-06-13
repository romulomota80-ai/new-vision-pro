# Diário de bordo

Log das mudanças e decisões. O mais recente em cima.

## 2026-06-12/13

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
