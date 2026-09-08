--!strict
-- CoreData.lua
-- Dados puros de cada Anomaly Core. Adicionar uma Core nova = adicionar uma
-- tabela aqui. A lógica que executa isso vive em CoreService (servidor).

export type Ability = {
	nome: string,
	cooldown: number,
	dano: number?,
	area: number?,     -- raio de efeito (studs), se for AoE
	range: number?,    -- alcance (studs)
	buff: number?,     -- multiplicador de dano (para formas)
	duracao: number?,  -- duração do efeito (segundos)
}

export type Core = {
	id: string,
	nome: string,
	raridade: string,
	cor: Color3,
	habilidades: { [string]: Ability },
}

-- (any) porque a tabela também carrega a lista `order` além das Cores
local CoreData: { [string]: any } = {}

CoreData.Thunder = {
	id = "thunder",
	nome = "Thunder Core",
	raridade = "Rare",
	cor = Color3.fromRGB(120, 220, 255),
	habilidades = {
		Z = { nome = "Thunder Dash",     cooldown = 4,  dano = 30, range = 22 },
		X = { nome = "Lightning Strike", cooldown = 7,  dano = 80, range = 40 },
		C = { nome = "Storm",            cooldown = 12, dano = 45, area = 18 },
		V = { nome = "Thunder Form",     cooldown = 60, buff = 1.4, duracao = 8 },
	},
}

CoreData.Frost = {
	id = "frost",
	nome = "Frost Core",
	raridade = "Epic",
	cor = Color3.fromRGB(150, 225, 255),
	habilidades = {
		Z = { nome = "Glacier Step",  cooldown = 5,  dano = 22, range = 24 },
		X = { nome = "Ice Lance",     cooldown = 6,  dano = 95, range = 45 },
		C = { nome = "Frozen Field",  cooldown = 14, dano = 55, area = 22 },
		V = { nome = "Frost Armor",   cooldown = 55, buff = 1.5, duracao = 10 },
	},
}

-- ordem de troca (tecla T alterna entre elas)
CoreData.order = { "Thunder", "Frost" }

return CoreData
