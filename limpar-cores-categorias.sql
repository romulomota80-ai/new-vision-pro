-- ════════════════════════════════════════════════════════════════
-- LIMPAR CORES NEON DAS CATEGORIAS — NEW VISION
-- Substitui cores neon salvas no banco pela paleta sóbria do brandbook
-- Rodar no SQL Editor do Supabase
-- ════════════════════════════════════════════════════════════════

-- 1) Ver cores atuais antes de mudar (confere o estado)
SELECT nome, cor, is_movimentacao
FROM categorias
ORDER BY is_movimentacao DESC, nome;

-- 2) Substituir cores neon conhecidas pela paleta sóbria
-- Verde neon → verde oliva
UPDATE categorias SET cor = '#5a8a3a' WHERE cor IN ('#10b981', '#22c55e', '#16a34a', '#14b8a6', '#06b6d4');

-- Laranja neon → terracota
UPDATE categorias SET cor = '#a0522d' WHERE cor IN ('#f97316', '#fb923c', '#ea580c', '#f59e0b');

-- Amarelo neon → âmbar queimado
UPDATE categorias SET cor = '#b8860b' WHERE cor IN ('#eab308', '#facc15', '#fbbf24');

-- Azul neon → azul petróleo
UPDATE categorias SET cor = '#3b6978' WHERE cor IN ('#3b82f6', '#60a5fa', '#2563eb', '#0ea5e9');

-- Rosa/magenta → vinho
UPDATE categorias SET cor = '#a04966' WHERE cor IN ('#ec4899', '#f472b6', '#db2777', '#e11d48');

-- Roxo neon → roxo sóbrio
UPDATE categorias SET cor = '#6b4e8a' WHERE cor IN ('#a855f7', '#c084fc', '#8b5cf6', '#9333ea', '#6366f1', '#818cf8');

-- Vermelho pânico → Fire Red oficial
UPDATE categorias SET cor = '#C92127' WHERE cor IN ('#ef4444', '#dc2626', '#b91c1c', '#C41830');

-- 3) Conferir resultado após atualização
SELECT nome, cor, is_movimentacao
FROM categorias
ORDER BY is_movimentacao DESC, nome;

-- ════════════════════════════════════════════════════════════════
-- PALETA SÓBRIA DE REFERÊNCIA (12 cores)
-- ════════════════════════════════════════════════════════════════
-- #C92127  Fire Red (operacional / alerta / marca)
-- #a0522d  Terracota (custos secundários)
-- #b8860b  Âmbar queimado (movimentações / entradas de controle)
-- #5a8a3a  Verde oliva (positivo / lucro / bonificação)
-- #3b6978  Azul petróleo (faturamento / neutro informativo)
-- #6b4e8a  Roxo sóbrio (categorias auxiliares)
-- #2c7a7b  Teal escuro (mkt / misc)
-- #a04966  Vinho rosado (rh / pessoal)
-- #8b2f2f  Bordô (impostos / obrigações)
-- #4a4e9a  Índigo (tecnologia / plataforma)
-- #2a7a6e  Verde petróleo (logística)
-- #8a6708  Dourado escuro (financeiro interno)
-- ════════════════════════════════════════════════════════════════
