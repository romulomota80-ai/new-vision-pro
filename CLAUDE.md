# CLAUDE.md — New Vision E-Commerce Pro

> Contexto permanente do projeto. Leia isto antes de qualquer alteração.

## O que é
App web de **gestão financeira** do e-commerce da New Vision (marca Verssene; lojas em
Mercado Livre, Mercado Pago, Shopee). Single-page application: um único `index.html`
(~8.300 linhas, HTML+CSS+JS inline), sem build.

## Arquitetura (resumo)
- **Frontend:** `index.html` hospedado na **Netlify** → site em **newvisionpro.com.br**.
- **Banco de dados:** **Supabase** (PostgreSQL). O front fala direto via supabase-js
  com a chave *publishable* (anon) que está no `index.html`.
- **Backend:** Node/Express no **Hetzner**, exposto em `https://api.newvisionpro.com.br`.
  A Netlify faz proxy de `/api/*` pra ele (ver `netlify.toml`). Repositório separado:
  `romulomota80-ai/new-vision-backend` (privado).
- **Open Finance:** o backend puxa saldos/extrato dos bancos (Itaú) e grava no Supabase.
- Detalhes em `docs/arquitetura.md`.

## Deploy (IMPORTANTE)
- **Push na branch `main` → a Netlify publica automaticamente.** Não há build.
- Fluxo: editar `index.html` → commit → push `main` → ~1 min no ar.
- O GitHub é a **fonte oficial** do site. Sempre trabalhe a partir do código do repo.

## Regras de ouro
1. **NUNCA dropar/recriar tabelas do Supabase sem confirmar com o usuário.** Use
   `ALTER`/`UPDATE` aditivos. (Já houve incidente por `drop table` — ver `docs/diario.md`.)
2. **Antes de qualquer SQL destrutivo, explique o que vai fazer e peça OK.**
3. **Segredos NUNCA no repositório** (é/era público): nada de service-role key, Shopee
   Partner Key, senhas. Só a chave *publishable* do Supabase (que é pública por design).
4. **Dados sensíveis** (nomes/CNPJs/saldos de contas) não vão pra docs versionadas.
5. Valide o JS antes de publicar (extrair `<script>` e `node --check`).
6. Mudou algo relevante? Atualize `docs/diario.md`.

## Convenções do código
- JS "vanilla" (sem framework), funções globais. Helpers comuns: `ge(id)` =
  getElementById, `fv(v)` = formata R$, `fd(d)` = formata data, `toast(msg, ok)`.
- Estado em variáveis globais (`EXT`, `BOL`, `CONTAS_BANC`, `EXTRATO_BANC`, etc.),
  carregadas em `carregarTudo()` via um `Promise.all` de queries Supabase.
- Render por aba: `rDB`, `rEx`, `rLu`, `rBo`, `rContas`/`rBancos` (Fluxo de Caixa), etc.
- Categorias de "movimentação/controle" (não afetam lucro): array `MOV` + `isMov(cat)`.

## Telas principais
Início · Vendas · Extrato · Lucro · Boletos/PIX · **Fluxo de Caixa** (Contas, Bancos,
Saques & Recebíveis, Movimentações, Compromissos, Financiamentos, GAP, Projeção 90d) ·
Produtos · Estoque Full · Fornecedores · Conciliação · IA Analista · Config.

## Em andamento
- **Extrato bancário por conta** (botão 📄 Extrato no card da conta) — ver `docs/diario.md`.
- **Integração API Shopee** (Open Platform) — espelhar o padrão de Mercado Livre/Pago.
