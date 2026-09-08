# Anomaly World — Marco 0 (protótipo cinza)

O objetivo deste marco é uma coisa só: **provar que o combate é divertido.**
Um personagem, uma Core (Thunder), 3 slimes que aparecem sozinhos por código, e os
4 verbos do combate. Sem arte, sem save, sem menu — de propósito.

## Controles
| Input | Ação |
|---|---|
| **M1** (clique) | Golpe leve (combo de 4, o 4º dá knockback) |
| **F** | Ataque pesado — lento, forte, quebra a guarda do inimigo |
| **Botão direito** (segurar) | Bloquear. Soltar+apertar no tempo do golpe = **PARRY** |
| **G** | Ultimate (quando a barra encher) |
| **R** | Lock-on no inimigo |
| **Q** | Esquiva com i-frames (gasta stamina) |
| **T** | Trocar de Anomaly Core (Thunder ⇄ Frost) |
| **B** | Abrir o Anomaly Database |
| **Z** | Thunder Dash — impulso + dano em linha |
| **X** | Lightning Strike — nuke no alvo à frente (sempre crita) |
| **C** | Storm — dano em área ao redor |
| **V** | Thunder Form — buff de dano por 8s |

## Como rodar (primeira vez)

1. **Instale o Rojo**
   - Recomendado: instale o [Aftman](https://github.com/LPGhatguy/aftman), depois na pasta do projeto rode `aftman install`.
   - Ou instale o Rojo direto: https://rojo.space/docs/v7/getting-started/installation/
   - No VS Code, instale a extensão **Rojo**.
2. **Inicie o servidor Rojo** na pasta do projeto:
   ```bash
   rojo serve
   ```
3. **No Roblox Studio**: crie um lugar novo (ou abra um Baseplate), abra o plugin
   **Rojo** → **Connect**. O código vai sincronizar para dentro do jogo.
4. Aperte **Play**. Os 3 slimes aparecem sozinhos e o HUD surge no canto. Após ~5s,
   **THE EXPERIMENT** (o boss) aparece ao norte (Z≈90) com aviso na tela.

> Não precisa montar nada no Studio: a **área** (vilarejo nórdico), as
> criaturas e o boss são criados por código ao dar Play. Tudo o que o WorldService
> constrói fica em `workspace.AnomalyWorld` — é só apagar essa pasta (ou desligar o
> serviço no `Main.server.lua`) quando vocês tiverem um mapa feito à mão no Studio.
>
> Como isso roda em tempo de execução, **o arquivo do seu lugar não é alterado**:
> ao dar Stop, tudo some.

### Para o save funcionar
O progresso (créditos, mastery, drops, abates de boss) usa DataStore. No Studio,
ative **Game Settings → Security → Enable Studio Access to API Services**. Sem isso o
jogo roda normal, só não salva (avisa no output). Em produção, considere trocar o
`DataService` por **ProfileService** — a interface já foi feita pra essa troca.

### O boss THE EXPERIMENT
4 fases que mudam comportamento conforme o HP: 100% forma normal → 70% mutação
(mais rápido/forte) → 40% arena instável (ataque de área telegrafado) → 10% TRUE FORM.
Drops com as chances da bíblia (Claw 15% … Corrupted Core 0,05%). Ele é marcado com
a tag `Enemy`, então seus golpes e poderes já o acertam sem código extra.

## Arquitetura (resumo)

```
src/
├─ ReplicatedStorage/Shared/   -- código puro compartilhado
│  ├─ Constants.lua            -- TODO o tuning (mexa aqui pra balancear)
│  ├─ CoreData.lua             -- dados das Anomaly Cores
│  ├─ BossData.lua             -- fases + drops dos bosses
│  ├─ CombatFormula.lua        -- fórmula de dano
│  └─ Net.lua                  -- cria/localiza os RemoteEvents
├─ ServerScriptService/        -- AUTORIDADE (valida e aplica tudo)
│  ├─ Main.server.lua          -- bootstrap do servidor
│  └─ Services/
│     ├─ PlayerState.lua       -- estado em memória por jogador
│     ├─ CombatUtil.lua        -- mira + aplicação de dano
│     ├─ CombatService.lua     -- golpe M1
│     ├─ MovementService.lua   -- esquiva + stamina
│     ├─ CoreService.lua       -- poderes Z/X/C/V
│     ├─ WorldService.lua      -- constrói a área + iluminação/atmosfera
│     ├─ EnemyService.lua      -- spawn + IA das criaturas (data-driven)
│     ├─ BossService.lua       -- THE EXPERIMENT (fases + drops)
│     ├─ DataService.lua       -- persistência (save/load)
│     └─ StateService.lua      -- envia estado pro HUD
└─ StarterPlayerScripts/       -- CLIENTE (input + feedback + HUD)
   ├─ Main.client.lua          -- bootstrap do cliente
   └─ Controllers/
      ├─ InputController.lua    -- captura input, pede ao servidor
      ├─ CombatController.lua   -- game feel: dano flutuante, shake, VFX
      └─ HudController.lua      -- HP/stamina/cooldowns
```

## Princípio inquebrável

**O cliente pede, o servidor decide.** Nenhum dano é calculado no cliente. O cliente
só dispara `RemoteEvent`s de intenção e mostra feedback; o servidor valida cooldown,
alcance e mira e aplica o resultado. É isso que segura o jogo contra cheat.

## Onde mexer primeiro

- **Sensação ruim?** → `Constants.lua` (dano, alcance, cooldowns, velocidade dos slimes)
  e `CombatController.lua` (shake, hit-stop, números).
- **Nova Core?** → só adicione uma tabela em `CoreData.lua`. A lógica genérica de
  Z/X/C/V já lê de lá (o passo seguinte é generalizar efeitos por dados).

## A pergunta do Marco 0

Depois de brincar 5 minutos: **isso é divertido?** Se sim, seguimos pro Marco 1
(1 área bonita, save com ProfileService, boss). Se não, o conserto é aqui.
