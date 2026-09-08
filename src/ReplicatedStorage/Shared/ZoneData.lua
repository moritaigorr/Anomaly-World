--!strict
-- ZoneData.lua
-- Regiões do mapa e o que aparece em cada uma. Nada nasce perto do vilarejo:
-- o jogador SAI pra caçar, em vez de ser emboscado no spawn (estilo Skyrim).
--
-- Zona nova = só uma tabela aqui.

export type Zone = {
	id: string,
	nome: string,
	center: Vector3,
	radius: number,
	creatures: { string }, -- ids do CreatureData que aparecem aqui
	maxAlive: number,
}

local ZoneData = {}

-- ponto seguro: o vilarejo. Nenhuma criatura nasce dentro deste raio.
-- a cidade murada inteira é zona segura: nada nasce lá dentro
ZoneData.SafeCenter = Vector3.new(0, 0, -40)
ZoneData.SafeRadius = 215

ZoneData.zones = {
	{
		id = "outskirts",
		nome = "Campos do Norte",
		center = Vector3.new(-250, 0, 90),
		radius = 40,
		creatures = { "ANM-001", "ANM-002" },
		maxAlive = 4,
	},
	{
		id = "pinewood",
		nome = "Bosque de Pinheiros",
		center = Vector3.new(60, 0, 300),
		radius = 45,
		creatures = { "ANM-002", "ANM-003" },
		maxAlive = 4,
	},
	{
		id = "stoneruins",
		nome = "Forte em Ruínas",
		center = Vector3.new(-300, 0, -100),
		radius = 40,
		creatures = { "ANM-003", "ANM-004" },
		maxAlive = 3,
	},
	{
		id = "barrow",
		nome = "Túmulo Antigo",
		center = Vector3.new(150, 0, -290),
		radius = 38,
		creatures = { "ANM-004", "ANM-005" },
		maxAlive = 3,
	},
} :: { Zone }

-- ponto aleatório dentro da zona (sempre fora da área segura)
function ZoneData.randomPointIn(zone: Zone): (number, number)
	for _ = 1, 12 do
		local ang = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * zone.radius
		local x = zone.center.X + math.cos(ang) * dist
		local z = zone.center.Z + math.sin(ang) * dist
		local dx, dz = x - ZoneData.SafeCenter.X, z - ZoneData.SafeCenter.Z
		if math.sqrt(dx * dx + dz * dz) > ZoneData.SafeRadius then
			return x, z
		end
	end
	return zone.center.X, zone.center.Z
end

return ZoneData
