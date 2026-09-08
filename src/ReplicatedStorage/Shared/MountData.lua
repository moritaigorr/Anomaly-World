--!strict
-- MountData.lua
-- As montarias. Montaria nova = mais uma tabela aqui, sem tocar em geometria:
-- o MountService monta o corpo a partir destes números e cores.
--
-- A montaria resolve um problema concreto do mapa: a cidade tem raio 185 e as
-- zonas de caça ficam a 250-400 studs do portão. A pé, com corrida de 24, isso
-- é meio minuto de nada acontecendo entre uma caçada e outra. Montado, o mesmo
-- trajeto vira travessia — e continua sendo travessia, porque montaria não
-- luta: subir é escolher velocidade em vez de prontidão.

export type Mount = {
	id: string,
	nome: string,
	raridade: string,
	speed: number, -- WalkSpeed montado
	jump: number, -- JumpPower montado
	raise: number, -- quanto o cavaleiro sobe (altura do dorso)
	length: number, -- comprimento do corpo
	corpo: Color3,
	crina: Color3,
	casco: Color3,
	sela: Color3,
	manta: Color3,
	brilho: Color3?, -- runa/anomalia, se houver
}

local MountData = {}

MountData.list = {
	{
		id = "fjord",
		nome = "Garrano do Fiorde",
		raridade = "Common",
		speed = 46,
		jump = 58,
		raise = 3.4,
		length = 7.4,
		corpo = Color3.fromRGB(96, 74, 58),
		crina = Color3.fromRGB(74, 58, 42),
		casco = Color3.fromRGB(52, 46, 42),
		sela = Color3.fromRGB(78, 54, 36),
		manta = Color3.fromRGB(122, 52, 48),
	},
	{
		id = "inverno",
		nome = "Crina-de-Inverno",
		raridade = "Rare",
		speed = 54,
		jump = 62,
		raise = 3.6,
		length = 7.8,
		corpo = Color3.fromRGB(206, 208, 212),
		crina = Color3.fromRGB(232, 236, 240),
		casco = Color3.fromRGB(64, 68, 74),
		sela = Color3.fromRGB(58, 66, 82),
		manta = Color3.fromRGB(58, 78, 106),
	},
	{
		id = "corrompido",
		nome = "Corcel Corrompido",
		raridade = "Epic",
		speed = 60,
		jump = 70,
		raise = 3.8,
		length = 8.2,
		corpo = Color3.fromRGB(44, 44, 50),
		crina = Color3.fromRGB(20, 132, 122),
		casco = Color3.fromRGB(24, 24, 28),
		sela = Color3.fromRGB(34, 40, 44),
		manta = Color3.fromRGB(20, 96, 92),
		brilho = Color3.fromRGB(47, 212, 194),
	},
}

-- índice por id, pra buscar sem varrer a lista
local byId: { [string]: Mount } = {}
for _, m in MountData.list do
	byId[m.id] = m :: Mount
end

function MountData.get(id: string): Mount?
	return byId[id]
end

-- a montaria inicial de todo jogador
MountData.DEFAULT = "fjord"

return MountData
