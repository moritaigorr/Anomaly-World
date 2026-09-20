# Anomaly World

Um vilarejo nórdico gerado por código, combate corpo a corpo servidor-autoritativo,
um boss de 4 fases, montarias e um jogador com Anomaly Cores trocáveis (Thunder,
Frost). O README anterior descrevia o "Marco 0" (protótipo cinza); o jogo já foi
muito além disso — este documento reflete o estado atual.

## Controles

| Input | Ação |
|---|---|
| **M1** (clique) | Golpe leve (combo de 4, o 4º dá knockback) |
| **F** | Ataque pesado — lento, forte, quebra a guarda do inimigo |
| **G** | Ultimate (quando a barra encher, carrega batendo) |
| **R** | Lock-on no inimigo |
| **Q** | Esquiva com i-frames (gasta stamina) |
| **Shift** (segurar) | Correr (gasta a mesma stamina da esquiva) |
| **T** | Trocar de Anomaly Core (Thunder ⇄ Frost) |
| **B** | Abrir o Anomaly Database |
| **H** | Montar/desmontar |
| **Z** | Thunder Dash — impulso + dano em linha |
| **X** | Lightning Strike — nuke no alvo à frente (sempre crita) |
| **C** | Storm — dano em área ao redor |
| **V** | Thunder Form — buff de dano por 8s |

> **Bloqueio e parry foram removidos.** O botão direito do mouse não faz mais
> nada — fica livre para a câmera padrão do Roblox. A guarda que existe hoje é
> só do **inimigo** (quebrada por F ou pelo ultimate), não do jogador.

## Como rodar (primeira vez)

1. **Instale o Rojo**
   - Recomendado: instale o [Aftman](https://github.com/LPGhatguy/aftman), depois na pasta do projeto rode `aftman install`.
   - Ou instale o Rojo direto: https://rojo.space/docs/v7/getting-started/installation/
   - No VS Code, instale a extensão **Rojo**.
2. **Inicie o servidor Rojo** na pasta do projeto:
   ```bash
   rojo serve
   ```
3. **No Roblox Studio**: abra o lugar do projeto, abra o plugin **Rojo** →
   **Connect**. O código vai sincronizar para dentro do jogo.
4. Aperte **Play**. O vilarejo, as criaturas e o boss já existem no lugar (o
   grosso da geometria foi "assada" no Studio — ver seção **Mundo** abaixo).

### Modelos que NÃO estão no Rojo/git (risco conhecido)

As malhas de criaturas, boss, mobília, construções, banca do mercado e a
montaria vivem hoje **só dentro do arquivo `.rbxl` do Studio**, em pastas
soltas dentro de `ServerStorage` (`_Criaturas`, `_Mobilia`, `_Construcoes`,
`_Mercado`, `_Montarias`). Rojo **não sincroniza `ServerStorage`** neste
projeto (não está mapeado em `default.project.json`) justamente para não
sobrescrever essas pastas com sync automático.

**Isso significa que esses modelos não estão versionados.** Se o arquivo
`.rbxl` local se perder ou corromper, essas malhas somem e o `WorldService`
cai nos fallbacks primitivos (esferas/formas antigas) para criaturas e boss.

Enquanto não exportamos isso para o git, faça backup manual do `.rbxl`
regularmente (cópia fora do OneDrive/nuvem síncrona, ou um `.zip` versionado
à parte). O plano para versionar de verdade está anotado como pendência do
projeto (ver `AGENTS`/memória do projeto) — resumo: exportar cada pasta via
**Explorer → botão direito → Save to File (.rbxm)** no Studio, guardar em uma
pasta do repositório fora do `$path` do Rojo (para não conflitar com o mapa
atual), e só depois decidir como fazer o Rojo consumir isso automaticamente.

### Para o save funcionar
O progresso (créditos, mastery, drops, abates de boss, Anomaly Database,
Core equipada) usa DataStore direto. No Studio, ative **Game Settings →
Security → Enable Studio Access to API Services**. Sem isso o jogo roda
normal, só não salva (avisa no output). Em produção, considere trocar o
`DataService` por **ProfileService** — a interface já foi feita pra essa
troca, mas ela ainda não aconteceu.

### O boss O Draugr-Rei
4 fases que mudam comportamento conforme o HP: Desperto → Fúria Antiga →
Chamado das Runas (slam de área telegrafado) → Rei Imortal. Drops com
chances reais (Garra do Draugr, Lâmina Rúnica, Coroa do Rei, Coroa
Amaldiçoada). Arena com raio limitado e respawn de 20s.

## Arquitetura (resumo)

```
src/
├─ ReplicatedStorage/Shared/   -- código puro compartilhado
│  ├─ Constants.lua            -- TODO o tuning (mexa aqui pra balancear)
│  ├─ CoreData.lua             -- dados das Anomaly Cores
│  ├─ WeaponData.lua           -- dados das armas (dano/alcance/velocidade)
│  ├─ BossData.lua             -- fases + drops do boss
│  ├─ CreatureData.lua         -- criaturas comuns data-driven
│  ├─ MountData.lua            -- montarias
│  ├─ ZoneData.lua             -- zonas de caça / marcos do mundo
│  ├─ CombatFormula.lua        -- fórmula de dano
│  ├─ CombatStance.lua         -- poses de arma no personagem (visual)
│  ├─ Bow*.lua                 -- mira/pose/projétil do arco (ver status abaixo)
│  └─ Net.lua                  -- cria/localiza os RemoteEvents
├─ ServerScriptService/        -- AUTORIDADE (valida e aplica tudo)
│  ├─ Main.server.lua          -- bootstrap do servidor
│  └─ Services/
│     ├─ PlayerState.lua       -- estado em memória por jogador
│     ├─ CombatUtil.lua        -- mira + aplicação de dano
│     ├─ CombatService.lua     -- golpe M1 / F / ultimate
│     ├─ MovementService.lua   -- esquiva + corrida + stamina
│     ├─ CoreService.lua       -- poderes Z/X/C/V
│     ├─ GearService.lua       -- dono da arma equipada (EquipWeaponRequest)
│     ├─ WorldService.lua      -- constrói a área + iluminação/atmosfera
│     ├─ World/*.lua           -- muralha, cidade, porto, floresta, terreno...
│     ├─ EnemyService.lua      -- spawn + IA das criaturas (data-driven)
│     ├─ BossService.lua       -- O Draugr-Rei (fases + drops)
│     ├─ MountService.lua      -- montar/desmontar, galope
│     ├─ DataService.lua       -- persistência (save/load)
│     └─ StateService.lua      -- envia estado pro HUD
└─ StarterPlayerScripts/       -- CLIENTE (input + feedback + HUD)
   ├─ Main.client.lua          -- bootstrap do cliente
   └─ Controllers/
      ├─ InputController.lua    -- captura input, pede ao servidor
      ├─ CombatController.lua   -- game feel: dano flutuante, shake, VFX
      ├─ CameraController.lua   -- terceira pessoa + lock-on
      ├─ HudController.lua      -- HP/stamina/cooldowns/database
      ├─ MountController.lua    -- animação da montaria
      ├─ AuraController.lua     -- efeito visual por Core equipada
      └─ InventoryController.lua-- UI de troca de arma (pede ao servidor)
```

## Princípio inquebrável

**O cliente pede, o servidor decide.** Nenhum dano é calculado no cliente. O cliente
só dispara `RemoteEvent`s de intenção e mostra feedback; o servidor valida cooldown,
alcance e mira e aplica o resultado. É isso que segura o jogo contra cheat.

## Status por sistema

| Sistema | Estado |
|---|---|
| Combate corpo a corpo (M1/F/Ultimate) | ✅ maduro, autoritativo no servidor |
| Anomaly Cores (Thunder/Frost + Z/X/C/V) | ✅ maduro, data-driven |
| Mundo (cidade, porto, floresta, terreno) | ✅ construído por código, bem trabalhado |
| Boss O Draugr-Rei | ✅ maduro, 4 fases |
| Criaturas comuns | ✅ funcional, IA simples |
| Montarias | ✅ maduro |
| Save (DataStore) | ⚠️ funcional, salva a arma equipada; ainda não sobrevive à falta de ProfileService |
| Gear (espada/adaga/machado/martelo) | ✅ funcional — dano/alcance/velocidade próprios por arma, servidor-autoritativo |
| Arco | ⚠️ cadastrado em `WeaponData.lua`, módulos de mira/pose/projétil prontos, **ainda sem disparo real** |
| Barra de postura no HUD | 🐛 existe na UI, mas o servidor não envia esse dado — nunca atualiza |
| Drops de boss | ⚠️ coletados e salvos, sem uso (sem loja/crafting) |
| Backup dos modelos 3D | 🐛 só existem no `.rbxl`, fora do git (ver seção acima) |

## Roadmap

Ver `ROADMAP.md` para os marcos do projeto e o que falta pra fechar o atual.

## Onde mexer primeiro

- **Sensação ruim?** → `Constants.lua` (fallback desarmado, cooldowns,
  velocidade dos slimes) e `CombatController.lua` (shake, hit-stop, números).
- **Balancear uma arma?** → `WeaponData.lua` (dano/alcance/velocidade por
  arma). Arma nova = só adicionar uma tabela lá, nos moldes das que já
  existem.
- **Nova Core?** → só adicione uma tabela em `CoreData.lua`. A lógica genérica de
  Z/X/C/V já lê de lá.
- **Terminar o arco?** → plugar `BowAttack.shoot` no `InputController` e criar
  validação de dano de projétil no servidor (`CombatUtil`). Os stats já têm
  lugar reservado em `WeaponData.bow`.
