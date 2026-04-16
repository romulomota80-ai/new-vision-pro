# New Vision E-Commerce Pro — Frontend

Sistema financeiro web da New Vision. Single-file HTML hospedado no Netlify em [newvisionpro.com.br](https://newvisionpro.com.br).

## Estrutura

- `index.html` — aplicação completa (single file, ~1900 linhas)
- `_redirects` — proxy Netlify para `/api/*` → backend Hetzner
- `logo-nv.png` — monograma NV (sidebar)
- `favicon.png`, `apple-touch-icon.png` — ícones do browser
- `limpar-cores-categorias.sql` — script SQL utilitário do Supabase

## Deploy

Push na branch `main` → Netlify detecta e faz deploy automático.

## Identidade visual

- Fire Red `#C92127`
- Black Oyster `#000000`
- White Quartz `#FDF9F7`
- Misty Gray `#6D7078`
- Fontes: Poppins (títulos), Inter (corpo), Fira Code (valores R$)
