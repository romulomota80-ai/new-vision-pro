# Arquitetura — New Vision

## Visão geral

```
┌────────────┐   push main   ┌─────────┐   serve    ┌──────────────────────┐
│  GitHub    │ ────────────▶ │ Netlify │ ─────────▶ │ newvisionpro.com.br  │
│ (index.html)│              └─────────┘            │  (index.html / SPA)  │
└────────────┘                    │                 └──────────┬───────────┘
                                  │ proxy /api/*               │ supabase-js (chave publishable)
                                  ▼                            ▼
                        ┌───────────────────┐        ┌────────────────────┐
                        │ Backend (Hetzner) │        │ Supabase (Postgres)│
                        │ api.newvisionpro  │ ─────▶ │  tabelas do app    │
                        │  Express + crons  │  grava └────────────────────┘
                        └─────────┬─────────┘
                                  │ Open Finance (Pluggy/agregador)
                                  ▼
                        ┌───────────────────┐
                        │  Bancos (Itaú…)   │
                        └───────────────────┘
```

## Componentes

### Frontend — `index.html`
- Single-page, sem build. Tudo (HTML/CSS/JS) em um arquivo.
- Lê/escreve no Supabase direto pelo navegador com a chave **publishable (anon)**.
- Chamadas `fetch('/api/...')` vão pro backend via proxy da Netlify.

### Netlify (`netlify.toml`)
- `publish = "."`, sem comando de build.
- Redirect `/api/*` → `https://api.newvisionpro.com.br/api/:splat`.
- SPA fallback `/*` → `/index.html`.
- Deploy automático no push da `main`.

### Backend — Hetzner (repo `new-vision-backend`, privado)
- Node/Express. Rotas por integração: `routes/mercadolivre.js`, `routes/mercadopago.js`,
  (futuro) `routes/shopee.js`. Crons em `server.js` (fuso America/Sao_Paulo).
- Padrão de integração: OAuth → tabela de tokens com refresh → sync em job de background
  + cron → grava nas tabelas genéricas do Supabase.
- Open Finance: sincroniza saldos e extrato dos bancos pra dentro do Supabase.

### Supabase
- Postgres. O front usa a chave publishable; as policies de RLS hoje são abertas
  (`using(true)`) — ver "Pendências de segurança".
- Tabelas principais: `lancamentos`, `boletos`, `marketplaces`, `contas`, `receitas`,
  `gastos_fixos`, `categorias`, `fornecedores`, `pedidos`, `pedido_pagamentos`,
  `produtos`, `produto_variacoes`, `saques`, `recebiveis_programados`,
  `historico_caixa`, `historico_alteracoes`, `historico_notas`,
  `contas_bancarias`, `extrato_bancario`, e tabelas `ml_*` (Mercado Livre).

## Fluxo de Caixa — contas e bancos
- **Contas** (`contas_bancarias`, ids 1-8): contas/carteiras cadastradas no app
  (PJ, PF, Marketplace Wallet). Campos-chave: `id`, `nome`, `banco`, `tipo`,
  `saldo_atual`, `titular`, `cnpj`, `numero_conta`, `agencia`, `openfinance_account_id`.
- **Bancos** (aba): conexões Open Finance vindas do backend (`/api/bancos/conexoes`).
  O usuário "Vincula" um banco a uma conta → backend grava `openfinance_account_id`
  na conta correspondente.
- **Extrato** (`extrato_bancario`): transações do banco. Campos: `id` (id da transação),
  `account_id` (id Open Finance), `conta_id`, `data`, `descricao`, `valor`, `tipo`,
  `categoria_banco`, `operacao`, `contraparte`. O botão 📄 Extrato no card casa
  transações com lançamentos (custo/movimentação/sem vínculo).

## Endpoints do backend (relevantes)
- `GET /api/bancos/conexoes` — lista conexões Open Finance + contas do app.
- `GET /api/bancos/link-conexao` — link da tela do Open Finance.
- `POST /api/bancos/vincular` — vincula `account_id` (banco) a `conta_id` (app).
- `POST /api/bancos/criar-conta` — cria conta no app a partir de um banco.
- `POST /api/bancos/sync` + `GET /api/bancos/sync/status` — sincroniza saldos.
- `POST /api/chat` — IA Analista (pode estar offline conforme o estado do backend).

## Pendências de segurança (revisar)
- **RLS aberta:** as policies do Supabase são `using(true)`. Como a chave publishable
  está no `index.html` (público), qualquer um poderia ler/escrever o banco. Avaliar
  RLS por usuário/autenticação real.
- **Repositório:** avaliar deixar **privado** (app financeiro de negócio).
- **Segredos** só em gerenciador de senhas / `.env` no servidor — nunca no repo.
