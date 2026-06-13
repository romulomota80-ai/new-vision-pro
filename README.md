# New Vision E-Commerce Pro — Frontend

Sistema financeiro web da New Vision. Single-page application (um único `index.html`)
hospedado no Netlify em **[newvisionpro.com.br](https://newvisionpro.com.br)**.

## Documentação
- **[CLAUDE.md](./CLAUDE.md)** — visão geral + regras de ouro (leia antes de mexer).
- **[docs/arquitetura.md](./docs/arquitetura.md)** — como tudo se conecta.
- **[docs/diario.md](./docs/diario.md)** — log de mudanças e decisões.

## Estrutura
- `index.html` — aplicação completa (HTML/CSS/JS inline, sem build).
- `netlify.toml` / `_redirects` — deploy e proxy `/api/*` → backend Hetzner.
- `logo-nv.png`, `favicon.png`, `apple-touch-icon.png`, `manifest.json` — assets/PWA.

## Deploy
**Push na branch `main` → a Netlify publica automaticamente.** Sem build.

## Identidade visual
- Fire Red `#C92127` · Black Oyster `#000000` · White Quartz `#FDF9F7` · Misty Gray `#6D7078`
- Fontes: Poppins (títulos), Inter (corpo), Fira Code (valores R$)

## Stack
- Frontend: HTML/CSS/JS puro.
- Dados: Supabase (Postgres).
- Backend: Node/Express no Hetzner (`api.newvisionpro.com.br`), repo separado e privado.
- Integrações: Mercado Livre, Mercado Pago, Open Finance (bancos), Shopee (em andamento).
