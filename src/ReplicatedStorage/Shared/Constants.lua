--!strict
-- Constants.lua
-- Todos os números de tuning do Marco 0 num lugar só.
-- Ajustar o jogo = mexer aqui, nunca espalhado pelo código.

local Constants = {}

-- Carimbo de versão. Mude isto sempre que quiser confirmar, DENTRO DO JOGO, que
-- o código novo realmente chegou ao Studio (aparece no cantinho do HUD).
Constants.BUILD_ID = "B16-sprint-servidor"

Constants.Player = {
	MaxHealth = 100,
	MaxStamina = 100,
	StaminaRegenPerSec = 22,
	HealthRegenPerSec = 6,   -- cura passiva fora de combate
	RegenDelay = 4,          -- segundos sem tomar dano até começar a curar
	LifestealOnKill = 12,    -- cura ao matar um inimigo
}

Constants.Melee = {
	BaseDamage = 10,
	Range = 9,            -- studs de alcance do golpe
	Arc = 0.35,          -- dot mínimo (frente do personagem). 1 = só reto, 0 = 180°
	CooldownPerHit = 0.28, -- ritmo do combo
	ComboWindow = 0.9,   -- tempo pra encadear o próximo golpe
	ComboMult = { 1.0, 1.0, 1.35, 1.6 }, -- multiplicador por passo do combo
	KnockbackFinal = 45, -- knockback no último golpe do combo
}

Constants.Dash = {
	StaminaCost = 25,
	Speed = 70,
	IFrames = 0.25,      -- segundos de invulnerabilidade
	Cooldown = 0.6,
}

Constants.Combat = {
	CritChance = 0.12,
	CritMult = 1.75,
	HitStop = 0.06,      -- segundos de congelamento no impacto (feedback)
}

Constants.Block = {
	ParryWindow = 0.45,  -- segundos após iniciar o bloqueio em que um hit vira parry
	ParryStun = 1.5,     -- por quanto tempo o inimigo fica atordoado ao ser defletido
	ParryPostureDamage = 45, -- guarda que o parry arranca do inimigo
	BlockChip = 0.15,    -- fração do dano que ainda passa segurando o bloqueio (0 = zero)
}

-- POSTURE (guarda): bloquear gasta; zerou = quebra de guarda e você fica exposto.
Constants.Posture = {
	Max = 100,
	RegenPerSec = 14,
	RegenDelay = 1.5,     -- segundos sem apanhar até a guarda voltar a recuperar
	BlockCost = 18,       -- posture perdida ao aparar um golpe segurando o bloqueio
	BreakStun = 2.0,      -- tempo atordoado quando sua guarda quebra
}

-- ATAQUE PESADO (F): lento, forte, e quebra a guarda do inimigo.
Constants.Heavy = {
	Damage = 26,
	Cooldown = 1.1,
	Range = 10,
	Arc = 0.25,
	PostureDamage = 45,   -- dano na guarda do inimigo
	Knockback = 60,
}

-- ULTIMATE (G): enche batendo e defletindo; solta um estouro em área.
Constants.Ultimate = {
	Max = 100,
	GainPerDamage = 0.30, -- carga por ponto de dano causado
	GainPerParry = 25,
	Damage = 180,
	Radius = 26,
}

Constants.Enemy = {
	Count = 7,           -- quantas criaturas vivas ao mesmo tempo
	Health = 60,
	Damage = 8,
	MoveSpeed = 10,
	AggroRange = 45,
	AttackRange = 6,
	AttackCooldown = 1.2,
	RespawnDelay = 3,
	SpawnRadius = 40,    -- raio ao redor da origem onde nascem
	MoneyReward = 15,
	Posture = 45,        -- guarda do inimigo (1 parry já quebra a do slime)
	BreakStun = 3,       -- tempo atordoado quando a guarda dele quebra
	Windup = 0.55,       -- AVISO antes do golpe: é a janela pra você defender/esquivar
}

-- MOVIMENTO base. As velocidades vivem todas aqui porque o MovementService e a
-- UNICA autoridade que escreve WalkSpeed -- se houver outro escritor, os dois
-- brigam e o jogador sente a velocidade "pular".
Constants.Move = {
	Walk = 16,     -- caminhada normal
	Blocking = 8,  -- de guarda alta: o peso do souls-like
}

-- CORRIDA (segurar Shift). Divide a MESMA stamina da esquiva: correr o mapa
-- inteiro custa a sua proxima esquiva. Essa tensao e o ponto.
Constants.Sprint = {
	Speed = 24,          -- 1.5x a caminhada: perceptivel sem virar patinete
	StaminaPerSec = 12,  -- ~8s de corrida cheia; so cobra enquanto anda de verdade
	MinToStart = 12,     -- stamina minima pra comecar a correr
}

return Constants
