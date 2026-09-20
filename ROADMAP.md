# Roadmap — Anomaly World

Histórico e próximos marcos do projeto. Cada marco tem uma pergunta central —
o critério que decide se o jogo está pronto pra seguir em frente.

## Marco 0 — Protótipo cinza ✅ concluído

**Pergunta:** o combate é divertido?

Escopo original: um personagem, uma Core (Thunder), 3 slimes, os 4 verbos do
combate. Sem arte, sem save, sem menu.

**Resultado:** sim — e o projeto já foi muito além do escopo original: mundo
construído por código (cidade nórdica, porto, floresta), boss de 4 fases,
montarias, save via DataStore, segunda Core (Frost), e um sistema de arco/gear
começado. Ver `README.md` para o estado técnico detalhado.

## Marco 1 — Fechar as pontas soltas (ATUAL)

**Pergunta:** uma sessão de jogo completa — entrar, lutar, evoluir, sair e
voltar — é coerente de ponta a ponta, sem lacunas visíveis?

Diferente do Marco 0, aqui não é sistema novo: é terminar o que já foi
começado e consertar o que ficou capenga.

### Combate e gear
- [ ] **Gear funcional** (decidido): cada arma (espada, machado, martelo, arco)
      passa a ter seus próprios dano/alcance/velocidade, em vez de tudo vir só
      das Anomaly Cores. Precisa de uma tabela de stats por arma (nos moldes
      de `CoreData.lua`) e o `CombatService`/`CombatUtil` passam a ler a arma
      equipada, não só constantes fixas.
- [ ] **Plugar o arco no gameplay real**: `BowAttack.shoot` chamado pelo
      `InputController`, validação de dano de projétil no servidor. Hoje só
      roda isolado em `LongbowSpec.lua` (teste).
- [ ] **Consertar a barra de postura no HUD**: `StateService` precisa enviar
      `posture`/`maxPosture` no payload (hoje a UI lê um dado que nunca chega).

### Persistência
- [ ] **Persistir a arma equipada** em `DataService` (hoje some ao relogar).
- [ ] **Migrar `DataService` → ProfileService** (interface já pensada pra
      essa troca).

### Economia mínima
- [ ] **Dar uso aos drops de boss** — mesmo que simples (trocar item por
      créditos, ou um NPC de troca na Tavern/Market que já existem no mundo).

### Infraestrutura
- [ ] **Backup real dos modelos 3D** (`_Criaturas`, `_Mobilia`, `_Construcoes`,
      `_Mercado`, `_Montarias`) — hoje só existem no `.rbxl`, fora do git.
      Requer exportação manual (.rbxm) no Studio; ver aviso em `README.md`.
- [ ] Atualizar este roadmap conforme os itens forem fechando.

## O mapa: como funciona hoje e como pode crescer

Isto não é um marco — é referência de design/técnica pra informar as decisões
dos marcos 1+ sempre que o assunto for "mundo".

### Como está estruturado hoje

- **Centro seguro:** a cidade murada inteira é zona segura — centro
  `(0, 0, -40)`, raio 215 studs (`ZoneData.SafeCenter`/`SafeRadius`). Nada
  nasce lá dentro, de propósito: o jogador **sai** pra caçar, em vez de ser
  emboscado no spawn (estilo Skyrim — comentário original em `ZoneData.lua`).
- **4 zonas de caça** fora da cidade, cada uma com seu centro, raio (~40
  studs) e lista de criaturas que nascem nela (`ZoneData.zones`):
  - Campos do Norte `(-250, 90)` — Draugr Menor, Lobo Corrompido
  - Bosque de Pinheiros `(60, 300)` — Lobo Corrompido, Vaettr da Névoa
  - Forte em Ruínas `(-300, -100)` — Vaettr da Névoa, Troll de Pedra
  - Túmulo Antigo `(150, -290)` — Troll de Pedra, Filho de Jötunn
- **O boss** (O Draugr-Rei) fica isolado num quinto ponto, `(-300, 300)`,
  fora das 4 zonas de caça — um destino próprio, não misturado com o
  grinding comum.
- Zona nova = só uma tabela a mais em `ZoneData.zones`; é data-driven, no
  mesmo espírito de `CoreData.lua`/`CreatureData.lua`.

### Pipeline técnico: gerado por código × mapa fixo

O mundo (`WorldService` + `World/*.lua`) é construído **inteiramente em
runtime**, toda vez que o jogo dá Play — não existe hoje um mapa desenhado à
mão no Studio. Isso tem um trade-off direto:

- **Enquanto não for "assado"**: qualquer alteração em `World/*.lua` muda o
  mapa pra todo mundo automaticamente no próximo Play. Bom pra iterar rápido
  no código do mundo; ruim se alguém quiser decorar/ajustar algo à mão, porque
  o próximo Play apaga a edição manual.
- **`WorldService.Bake()`**: comando (barra de comandos do Studio, jogo
  parado) que gera o mundo uma vez e marca a pasta `AnomalyWorld` com o
  atributo `Baked = true`. A partir daí o `WorldService.Start()` detecta o
  atributo e **para de reconstruir** — o mapa vira geometria fixa, editável à
  mão no Studio como qualquer outro lugar. Pra voltar ao modo gerado, é só
  apagar a pasta `AnomalyWorld` e dar Play de novo.
- Isso é relevante pro Marco 1 (item de backup dos modelos) e também é o
  caminho natural pra quando o mapa estiver "bom o suficiente": assar,
  parar de regenerar, e passar a editar/decorar manualmente por cima.

### Navegação do jogador

Hoje só existem duas formas de se mover: **a pé** (andar/correr) e
**montaria** (tecla H). Não há fast travel nem teleporte — as zonas de caça
ficam a 250–400 studs do centro da cidade, distância pensada pra ser sentida
(ver comentários de `Constants.Sprint`: o ritmo da corrida é parte do design,
não só velocidade).

Isso funciona bem com o tamanho atual do mapa (tudo cabe numa caminhada/
cavalgada razoável). Se o mapa crescer bastante (mais zonas, mais longe),
vira uma decisão de design explícita a tomar, não algo pra resolver de
passagem:

- manter o mundo pequeno e denso, sem fast travel, de propósito; ou
- introduzir pontos de viagem rápida quando o número de zonas justificar.

### Ganchos pro Marco 2 (mundo maior)

Se "mais zonas/mundo maior" entrar no Marco 2, os pontos técnicos que isso
esbarra:

- Zona nova é barata (tabela em `ZoneData.zones`), mas biomas/regiões novas
  (fora do raio atual de ~400 studs do centro) pedem trabalho equivalente ao
  que já foi feito em `Terra.lua`/`Wilds.lua` — não é só dado, é geometria.
- Com mundo maior, decidir se continua tudo num único espaço contínuo
  carregado de uma vez (como hoje) ou se algumas áreas viram zonas separadas
  (streaming/instâncias) por custo de performance.
- O Porto (`Harbor.lua`) já existe fisicamente no mapa mas não tem conteúdo
  de gameplay próprio (nem zona de caça, nem quest, nem NPC) — é um POI
  "vazio" que poderia ganhar propósito antes de novas áreas serem criadas.

## Marco 2 — Motivo pra voltar

**Pergunta:** depois de zerar o boss uma vez, o jogador tem razão pra jogar de
novo?

Ainda não detalhado — candidatos a entrar aqui (não comprometidos):
- Mais criaturas/zonas de caça, ou um segundo boss
- Mais Anomaly Cores além de Thunder/Frost
- Loja/crafting real usando os drops (além do "dar uso" mínimo do Marco 1)
- Progressão de mastery com efeito real no personagem (hoje é salvo mas não
  investigado se afeta algo)

## Marco 3 — Pronto pra outros jogadores

**Pergunta:** dá pra soltar um link e um estranho entender e curtir o jogo
sem alguém do time do lado explicando?

Ainda não detalhado — candidatos: menu/onboarding real (hoje não há UI de
início, o jogo cai direto no mundo), balanceamento multiplayer, testes de
carga, e decisão sobre monetização se houver.

---

Este arquivo é a fonte de verdade de prioridade — quando uma decisão de
escopo for tomada em conversa, ela deve ser refletida aqui, não só na memória
da conversa.
