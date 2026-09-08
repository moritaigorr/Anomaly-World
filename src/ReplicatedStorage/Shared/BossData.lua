--!strict
-- BossData.lua
-- Dados puros dos bosses (fases + drops). Adicionar boss novo = nova tabela.

export type Drop = { item: string, chance: number }
export type Phase = { at: number, speed: number, damage: number, slam: boolean, name: string }

export type Boss = {
	id: string,
	nome: string,
	health: number,
	baseSpeed: number,
	baseDamage: number,
	attackRange: number,
	attackCooldown: number,
	moneyReward: number,
	color: Color3,
	trueFormColor: Color3,
	phases: { Phase }, -- em ordem decrescente de HP (o primeiro cujo 'at' >= frac vale)
	drops: { Drop },
}

local BossData: { [string]: Boss } = {}

BossData.Experiment = {
	id = "draugr_king",
	nome = "O DRAUGR-REI",
	health = 1200,
	baseSpeed = 12,
	baseDamage = 16,
	attackRange = 9,
	attackCooldown = 1.4,
	moneyReward = 250,
	color = Color3.fromRGB(84, 88, 78),        -- carne morta e armadura enferrujada
	trueFormColor = Color3.fromRGB(150, 220, 255), -- runa acesa na TRUE FORM
	-- fases avaliadas de cima pra baixo: usa a primeira cujo 'at' <= fração de HP
	phases = {
		{ at = 1.00, speed = 12, damage = 16, slam = false, name = "Desperto" },
		{ at = 0.70, speed = 16, damage = 20, slam = false, name = "Furia Antiga" },
		{ at = 0.40, speed = 18, damage = 26, slam = true,  name = "Chamado das Runas" },
		{ at = 0.10, speed = 26, damage = 34, slam = true,  name = "REI IMORTAL" },
	},
	drops = {
		{ item = "Garra do Draugr", chance = 0.15 },
		{ item = "Lamina Rúnica", chance = 0.05 },
		{ item = "Coroa do Rei", chance = 0.01 },
		{ item = "Coroa Amaldicoada", chance = 0.0005 },
	},
}

return BossData
