--!strict
-- CreatureData.lua
-- Todas as criaturas do jogo. Adicionar uma nova = adicionar uma tabela aqui.
-- O EnemyService lê daqui: nada de código novo por criatura.

export type Creature = {
	id: string,          -- código do Anomaly Database (ANM-XXX)
	nome: string,
	raridade: string,
	health: number,
	damage: number,
	speed: number,
	posture: number,
	money: number,
	size: Vector3,
	color: Color3,
	coreColor: Color3,   -- núcleo brilhante interno
	weight: number,      -- chance relativa de aparecer no spawn
	windup: number,      -- tempo de aviso antes do golpe
}

local Creatures: { Creature } = {
	{
		id = "ANM-001",
		nome = "Draugr Menor",
		raridade = "Common",
		health = 60, damage = 8, speed = 10, posture = 45, money = 15,
		size = Vector3.new(3, 2.6, 3),
		color = Color3.fromRGB(96, 104, 92),   -- carne cinzenta de morto-vivo
		coreColor = Color3.fromRGB(140, 220, 210),
		weight = 40, windup = 0.55,
	},
	{
		id = "ANM-002",
		nome = "Lobo Corrompido",
		raridade = "Common",
		health = 80, damage = 12, speed = 14, posture = 55, money = 25,
		size = Vector3.new(3.2, 2.6, 3.2),
		color = Color3.fromRGB(72, 66, 60),
		coreColor = Color3.fromRGB(210, 150, 70),
		weight = 25, windup = 0.45,
	},
	{
		id = "ANM-003",
		nome = "Vaettr da Névoa",
		raridade = "Uncommon",
		health = 45, damage = 10, speed = 19, posture = 30, money = 30,
		size = Vector3.new(2.4, 2.6, 2.4),
		color = Color3.fromRGB(120, 140, 150),
		coreColor = Color3.fromRGB(190, 230, 255),
		weight = 18, windup = 0.4, -- rápido: aviso mais curto
	},
	{
		id = "ANM-004",
		nome = "Troll de Pedra",
		raridade = "Rare",
		health = 220, damage = 20, speed = 7, posture = 90, money = 70,
		size = Vector3.new(6, 5.4, 6),
		color = Color3.fromRGB(88, 92, 86),
		coreColor = Color3.fromRGB(150, 200, 120),
		weight = 12, windup = 0.85, -- lento e bem telegrafado
	},
	{
		id = "ANM-005",
		nome = "Filho de Jötunn",
		raridade = "Epic",
		health = 160, damage = 26, speed = 13, posture = 70, money = 150,
		size = Vector3.new(3.8, 3.4, 3.8),
		color = Color3.fromRGB(58, 48, 78),
		coreColor = Color3.fromRGB(180, 130, 255),
		weight = 5, windup = 0.5,
	},
}

local CreatureData = {}

CreatureData.list = Creatures

-- sorteia uma criatura respeitando os pesos (raras aparecem menos)
function CreatureData.roll(): Creature
	local total = 0
	for _, c in Creatures do
		total += c.weight
	end
	local pick = math.random() * total
	for _, c in Creatures do
		pick -= c.weight
		if pick <= 0 then
			return c
		end
	end
	return Creatures[1]
end

function CreatureData.byId(id: string): Creature?
	for _, c in Creatures do
		if c.id == id then
			return c
		end
	end
	return nil
end

return CreatureData
