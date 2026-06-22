# Roadmap & Backlog — New Vision Pro

> Onde a gente anota o que vai construir e o que precisa corrigir. Não é o diário
> (decisões já tomadas vão pro `diario.md`); aqui é o que **ainda falta fazer**.
> Sem dados sensíveis (saldos/CNPJs/segredos).

## A tese do sistema (mapa mental)

Todo real percorre 4 perguntas, na ordem do dinheiro:

1. **Vendi?** → Vendas · Produtos
2. **Vou receber?** → Extrato · Saques & Recebíveis · Conciliação
3. **Tenho caixa pro que devo?** → Fluxo de Caixa · Boletos/PIX · Compromissos · Financiamentos · GAP · Projeção 90d
4. **Sobrou lucro?** → Lucro (→ evoluir pra DRE/Fechamento)

E uma camada que **vigia tudo e avisa antes** → IA Analista (→ evoluir pra agentes por setor).

Além das finanças, há um pilar **operação/produção** (Cortes, Estoque) e a **camada de
canal** (bot — hoje Telegram, futuro WhatsApp).

---

## Abas novas planejadas

### Ads / Marketing (ML + Shopee juntas; Meta no futuro)
- 📄 **Planta detalhada em `docs/ads.md`** (contrato de dados + backend + fases).
- Dor do usuário: **gasto com Ads muito alto** → enxergar ralo (ACOS por anúncio),
  recomendar cortes e (meta final) **automatizar** pausar/ajustar campanha.
- Uma aba só pra todos os canais de anúncio. KPIs: ACOS/ROAS por canal, campanha e
  produto; Ads vs faturamento (TACOS); joga o custo na **margem real** e na **DRE**.
- Já existe começo no código: `Margem bruta → Após ADS → Margem real` (macro, manual).
- ⚠️ Fonte do dado: ML Ads API / Shopee Marketing API (backend, pode exigir escopo
  extra). Fallback inicial: **import CSV**. Fase 0 dá pra fazer **só no front** (TACOS
  + alerta de teto) com o `receitas.ads` que já existe.

### Fatura / Custos do Mercado Livre — 🔜 PRÓXIMA (depois de fechar o Ads)
- Dor: a fatura do ML (Ads + tarifa de venda + Full/armazenagem + estoque antigo + frete)
  **acumula e vem de uma vez com vencimento** → sempre pega o usuário de surpresa no caixa.
- Objetivo: **antecipar** o valor. Mostrar o acumulado do período **em aberto** + previsão
  de fechamento + vencimento; **quebra por tipo** (quanto é Ads/Full/tarifa).
- Vira **Compromisso automático** no Fluxo de Caixa (provisão) + **alerta** antes de vencer.
  Histórico de faturas pra ver tendência.
- Fonte: backend puxa a **API de Billing/"custos e faturas" do ML** → tabelas `ml_faturas`
  (cabeçalho: período, vencimento, valor_total, status, documento_id) e `ml_fatura_itens`
  (detalhe por tipo). Esquema/brief de backend já rascunhado — incluir junto do Ads.
- Sinergia: o Ads que vamos puxar é **um pedaço dessa fatura** → dá pra conferir se bate.

### Fechamento / DRE mensal
- Resultado consolidado do mês em **regime de competência** (não caixa).
- Estrutura: Receita bruta → (−) deduções (impostos s/ venda, devoluções, taxas
  marketplace) → Receita líquida → (−) CMV → Lucro bruto → (−) despesas op. (Ads,
  frete, embalagem, fixos, pessoal) → EBITDA → (−) desp. financeiras → (−) imposto →
  **Lucro líquido**. Apresentar como **waterfall** + comparativo vs mês anterior.
- Checklist guiado de fechamento (conciliar vendas/banco/repasses, lançar CMV,
  provisões) e **travar o mês** 🔒 + snapshot congelado pra histórico.
- Insight-chave a comunicar: **Lucro ≠ Caixa**.
- ⚠️ Pré-requisito crítico: **CMV por SKU no momento da venda**.
- **Visão do usuário — DRE se monta sozinha:** puxar tudo automático em vez de digitar.
  Cada linha tem fonte: faturamento/taxas/frete/CMV → `ml_orders`; Ads (ML+Shopee) →
  `ads_metrics`; tarifa/Full → `ml_faturas`; custos op./fixos → `gastos_fixos`+
  `lancamentos`; impostos/pró-labore → itens do roadmap. O "Preencher resultados" manual
  vira **fallback**; o normal é puxado e o usuário só **confere e trava** 🔒.
  (Obs.: lucro não se "puxa", se **calcula** — o agente confere se bate com o caixa.)
- **Agentes de auditoria (ideia do usuário — mais de um, cada um com 1 função):**
  1. **Reconciliador** — vendas×repasses×banco; Ads da fatura ML × `ads_metrics`; lucro
     da DRE × variação de caixa (Lucro ≠ Caixa).
  2. **Auditor de dados (caça-bug)** — venda sem CMV, Ads sem venda, fatura sem categoria,
     lançamento duplicado, conciliação pendente, mês com dado faltando.
  3. **Revisor de fechamento** — só libera travar o mês quando tudo bate; senão lista
     pendências.
  Trava: agente **aponta e explica**, quem **fecha/congela o snapshot é o usuário**.
- (Definir nível: só DRE+lock, ou pacote completo com Balanço + DFC.)

### Precificação / Calculadora de preço por canal
- CMV → preço ideal por canal (taxa ML/Shopee + frete + imposto + margem-alvo).
- Reverso: dado um preço, qual a margem real.

### Impostos (DAS / Simples Nacional)
- Provisão automática do imposto sobre faturamento do mês; separa o dinheiro.
- Vira Compromisso automático com alerta de vencimento do DAS.

### Pró-labore (remuneração do sócio)
- Registrar o pró-labore mensal (valor fixo que o sócio se paga) — **separado do lucro**.
- Entra como **despesa** na DRE e como **saída recorrente** no Fluxo de Caixa.
- Distinguir **pró-labore** (tem INSS/IRRF) de **distribuição de lucro** (isenta no
  Simples) e de **tirada extra** — não misturar tudo em "saque".
- Disciplina-chave: **separar PF do PJ** (parar de misturar dinheiro pessoal com o da
  empresa). Casa com os saques pra conta PF no Fluxo de Caixa.
- Acompanhar: definido vs realizado no mês; INSS sobre pró-labore vira Compromisso.

### Devoluções / Reembolsos
- Lente própria: % de devolução por produto, custo das devoluções.
- **[BACKLOG] Incluir o PREJUÍZO DE FRETE por devolução** — quando o produto volta,
  o frete perdido entra como custo da devolução (afeta margem real e DRE).
- Mata produto ruim e recupera grana (volume de devolução do ML é alto).

### Curva ABC de produtos (análise — melhorar o que já existe)
- Hoje a aba Produtos é cadastro de SKU (custo/CMV + imposto%).
- Falta: Curva ABC por **lucro** (não faturamento); margem real por SKU e por canal
  (após taxa+frete+imposto+Ads); 🚨 produtos que vendem mas dão prejuízo; giro/cobertura
  (casado com Estoque Full).
- Mesmo CMV que alimenta a DRE.

### Cortes / Produção (pilar operacional — NÃO é financeiro)
- Trazer as planilhas de "cortes" pra dentro do site, pro funcionário que cuida.
- ⏳ A DEFINIR com o usuário: colunas da planilha (produto, grade/tamanho, qtd, tecido,
  data, status?) e se o corte no fim **vira entrada de estoque** ou é só controle de
  produção. Se virar estoque, conecta com a aba Estoque (entrada de mercadoria).

---

## Melhorias em abas existentes

- **Início → cockpit:** caixa hoje · a receber 7/30d · a pagar 7/30d · resultado do mês
  vs anterior · alertas (boleto vencendo, saque não conciliado, sem estoque).
- **Projeção 90d → cenários:** Shopee+MP no automático; "e se antecipar?" / "e se
  atrasar fornecedor?"; alerta de GAP futuro.
- **Boletos/PIX → recorrência** + lembrete antes de vencer.
- **Estoque Full → previsão de ruptura** (dias até acabar no giro) + capital parado.
- **Conciliação → fila de pendências** no topo + auto-match (evoluir `ebMatch`).

---

## Camada de inteligência — Agentes de IA por setor

> Ideia do usuário: sair de uma IA única ("comenta") pra **agentes especializados por
> setor** que analisam os dados, **pegam erros/inconsistências** e **tiram insights**.

- Um agente por domínio (ex.: Financeiro/Caixa, Produtos/Margem, Ads, Devoluções,
  Produção/Cortes, Conciliação).
- Funções: detectar anomalias (margem caiu, taxa subiu, produto no prejuízo, GAP de
  caixa à frente, saque não conciliado), validar consistência dos dados e gerar
  recomendações acionáveis.
- Evolução da aba IA Analista atual (que hoje só comenta compromissos).
- ⏳ A DEFINIR: modelo/provedor, como orquestrar os agentes, e como entregam (alertas
  no cockpit? chat? notificação no canal?).

---

## Integrações

- **Shopee** (em andamento): OAuth + tokens + sync de vendas/repasses + conciliação de
  saque, tudo em cron no backend (rodar sempre). Ver `diario.md`.
- **Mercado Pago via Open Finance** (regra do saldo travada): ver `diario.md`.
- **Telegram → WhatsApp:** migrar o bot que registra movimentações.
  ⚠️ Não é swap simples: WhatsApp exige API oficial (Meta Cloud API) ou gateway
  (Z-API/Twilio), com custo por conversa e templates aprovados pra mensagens iniciadas
  pelo sistema. Mensagem iniciada pelo funcionário roda na janela de 24h.
  ⏳ A DEFINIR: API oficial Meta vs gateway; uso principal (funcionário registra vs
  sistema alerta).

---

## Backlog de correções/detalhes (itens soltos pra resolver depois)

- [ ] **Devoluções:** somar o **prejuízo de frete** por devolução no custo da devolução.
