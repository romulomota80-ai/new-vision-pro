# Tema escuro — conserto de contraste/legibilidade

Data: 2026-06-26
Arquivo alvo: `/root/new-vision-pro/index.html` (single-file, ~677KB)

## Problema

O frontend é token-driven (tema claro minimalista + escuro grafite). No tema
escuro várias cores ficam ilegíveis e "não batem". Causa medida:

- **62 cores distintas** em `color:#hex` inline; **236 ocorrências reprovam AA**
  (<4,5:1) sobre o card escuro `#161920`; **151 dessas são praticamente
  ilegíveis** (<3,0:1) — ex.: `#1c2333` (1,12:1), `#18181b` (1,01:1),
  `#1e4880` (1,92:1), `#1e5c2a` (2,19:1).
- Essas cores foram calibradas pro tema **claro** e estão chumbadas inline, então
  **não trocam** com o tema (estilo inline vence o CSS — não dá pra corrigir por
  folha de estilo, só editando).
- Dois acentos do próprio escuro estão apagados demais: `--B` (`#3b6978`, 2,91:1)
  e `--O` (`#a0522d`, 3,13:1).

## Decisão de direção

Consertar **mantendo a identidade grafite** (fundo quase-preto + acentos sóbrios).
Sem nova paleta. Risco visual baixo: mexe só em cor de **texto**, não em
fundos/bordas, e preserva a semântica financeira (verde=positivo, vermelho=negativo).

## Abordagem

Canalizar as cores chumbadas pra **tokens semânticos** que adaptam por tema.
Para não criar novos descasamentos, reusar os tokens existentes (`--G/--Y/--B/--O`)
e adicionar só os que faltam (`--NEG`, `--PURPLE`).

### Valores dos tokens (todos verificados ≥4,5:1)

| Token | Uso | Escuro | Claro | Antes (escuro) |
|---|---|---|---|---|
| `--G` | positivo/sucesso | `#6cab4d` | `#3d6225` | `#5a8a3a` (4,30) |
| `--Y` | aviso/pendência | `#b8860b` | `#8a6408` | mantém (5,40) |
| `--B` | info/azul/links | `#5aa6cf` | `#1c5a8a` | `#3b6978` (2,91) |
| `--O` | laranja | `#d98a4a` | `#7a3e1f` | `#a0522d` (3,13) |
| `--NEG` | negativo/erro/excluir | `#ec6a6e` | `#b3261e` | (novo) |
| `--PURPLE` | acento roxo (movimentações) | `#a48ce0` | `#5b3f86` | (novo) |

`--R` (`#C92127`, marca) permanece para **fundos** de botão/avatar/spinner; só os
usos de `color:#c92127` (texto) migram para `--NEG`.

### Remapeamento (escopado a `color:#hex`, case-insensitive)

Famílias → token. Não toca em `background:`/`border:`.

- **→ --G (verde):** 5a8a3a, 3a8a4a, 1e5c2a, 3d6225, 2a8a4a, 0f4017, 27500a
- **→ --NEG (vermelho):** a04040, a32d2d, c92127, e5484d, d9534f, 791f1f, 8b2f2f
- **→ --PURPLE (roxo):** 6b4e8a, 4a4e9a, 7c5cff, 5c4d8a, 3d2d6a, 4a3a6b
- **→ --B (azul):** 3b6978, 2a5263, 2563eb, 185fa5, 1e4880, 0089b8, 0d3060
- **→ --Y (âmbar/marrom):** 854f0b, 7a5c0a, 856404, 92400e, 8a6408, a4690c,
  78350f, 633806, 5c4407, 5c3d0a, 5a3d1a
- **→ --O (laranja):** a0522d, c2410c
- **→ --TX (texto principal vazado):** 1c2333, 18181b, 292333, 2a3042, 3a4257
- **→ --MU (texto suave vazado):** 6a7289, 6b6b72, 6b7280, 5a6478, 5a5a60,
  4b5563, 6b7a8a

## Verificação

1. Re-rodar o script de contraste → meta: **0 ocorrência <4,5:1** no card escuro.
2. Conferir que o bloco `body.light` carrega os valores claros dos 2 tokens novos
   (tema claro inalterado).
3. Checagem visual nas abas principais.

## Fora de escopo

- Backgrounds/bordas hardcoded (não são problema de legibilidade de texto).
- Nova paleta / mudança de identidade.
- Cores que já passam AA no escuro (ex.: `#5a8ca8` teal).

## Deploy

Commit em `/root/new-vision-pro` → Netlify (newvisionpro.com.br).
Rollback disponível via `netlify api restoreSiteDeploy`.
