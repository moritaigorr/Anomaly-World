--!strict
-- Walls.lua  (SERVIDOR)
-- A muralha que cerca a cidade. É o elemento de silhueta mais forte do mapa
-- (ref. Attack on Titan e Whiterun): alta, contínua, com ameias, torres
-- regulares e um portão monumental ao sul por onde o jogador sai pra caçar.

local Build = require(script.Parent.Build)
local Town = require(script.Parent.Town)
local C = Build.C

local Walls = {}

Walls.RADIUS = 185
-- 34 studs lia como um muro baixo de vista aérea. A referência (AoT / Whiterun)
-- é uma parede que DOMINA a cidade — 54 muda completamente a silhueta.
Walls.HEIGHT = 54

local SEGMENTS = 64

-- ameias (crenelagem) no topo de um trecho
local function crenellation(cf: CFrame, length: number)
	local n = math.floor(length / 5)
	for i = 0, n - 1 do
		local off = -length / 2 + 2.5 + i * 5
        Build.part({
			Size = Vector3.new(3, 3.2, 6.5),
			CFrame = cf * CFrame.new(0, 0, off),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
end

local function tower(pos: Vector3, ang: number)
	local h = Walls.HEIGHT + 14
	Build.part({
		Size = Vector3.new(18, h, 18),
		CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, ang, 0),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	-- ameias da torre
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		Build.part({
			Size = Vector3.new(3.4, 3.4, 3.4),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 7.6, h + 1.7, math.sin(a) * 7.6)),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	-- telhado cônico estilizado (camadas)
	for i = 0, 3 do
		local s = 16 - i * 3.6
		Build.part({
			Size = Vector3.new(s, 3, s),
			CFrame = CFrame.new(pos + Vector3.new(0, h + 4.5 + i * 2.8, 0)) * CFrame.Angles(0, ang, 0),
			Color = C.ROOF_SHINGLE,
			Material = Enum.Material.WoodPlanks,
			CastShadow = false,
		})
	end
	-- braseiro no topo: pontinho quente na silhueta
	local fire = Build.part({
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, h + 18, 0)),
		Color = C.FIRE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Build.light(fire, C.FIRE, 2, 40)
end

-- portão monumental ao sul: duas torres, arco e portas de madeira
local function gatehouse()
	local z = Town.GATE_Z - 25
	local h = Walls.HEIGHT

	for _, sx in { -1, 1 } do
		Build.part({ -- torres do portão (mais grossas)
			Size = Vector3.new(22, h + 20, 24),
			CFrame = CFrame.new(sx * 24, (h + 20) / 2, z),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
		})
		for i = 0, 5 do -- ameias
			Build.part({
				Size = Vector3.new(3.4, 3.4, 3.4),
				CFrame = CFrame.new(sx * 24 + (i - 2.5) * 5, h + 21.7, z + 10),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
		end
		Build.banner(CFrame.new(sx * 24, h * 0.62, z - 12.2), 16, C.BANNER)
	end

	-- travessa por cima da passagem
	Build.part({
		Size = Vector3.new(28, 16, 24),
		CFrame = CFrame.new(0, h + 12, z),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	-- arco (degraus de pedra formando a curva)
	for i = 0, 6 do
		local a = (i / 6) * math.pi
		Build.part({
			Size = Vector3.new(3, 3, 24),
			CFrame = CFrame.new(math.cos(a) * 13, h + 4 + math.sin(a) * 9, z),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	-- portas abertas
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(11, 22, 1.2),
			CFrame = CFrame.new(sx * 8, 11, z - 11) * CFrame.Angles(0, math.rad(sx * 62), 0),
			Color = C.WOOD_DARK,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- estrada saindo do portão pro mundo
	Build.part({
		Size = Vector3.new(20, 0.5, 120),
		CFrame = CFrame.new(0, 0.25, z - 70),
		Color = C.DIRT,
		Material = Enum.Material.Ground,
		CanCollide = false,
	})
end

function Walls.build()
	local R = Walls.RADIUS
	local H = Walls.HEIGHT
	-- comprimento do arco entre segmentos + folga, pra eles se sobreporem e a
	-- muralha ler como parede contínua (com o giro certo: veja CFrame.Angles(0,-ang,0))
	local segLen = (2 * math.pi * R) / SEGMENTS + 3

	for i = 1, SEGMENTS do
		local ang = (i / SEGMENTS) * math.pi * 2
		local x, z = math.cos(ang) * R, math.sin(ang) * R
		-- abertura do portão ao sul (onde fica o gatehouse)
		local isGate = math.abs(x) < 40 and z < -R * 0.8
		if not isGate then
			-- IRREGULARIDADE: altura, espessura e inclinação variam um pouco por
			-- segmento. Muralha com todos os blocos idênticos e perfeitamente
			-- alinhados grita "gerado por código".
			local hVar = H + (math.random() - 0.5) * 3.5
			local tilt = math.rad((math.random() - 0.5) * 1.6)
			local cf = CFrame.new(x, hVar / 2, z)
				* CFrame.Angles(0, -ang, 0)
				* CFrame.Angles(tilt, 0, 0)
			Build.part({
				Size = Vector3.new(9 + (math.random() - 0.5) * 1.2, hVar, segLen),
				CFrame = cf,
				Color = Build.tint((i % 3 == 0) and C.STONE_DARK or C.STONE, 0.05),
				Material = Enum.Material.Cobblestone,
			})
			-- faixa de sujeira na base da muralha
			Build.part({
				Size = Vector3.new(9.4, 7, segLen),
				CFrame = CFrame.new(x, 3.5, z) * CFrame.Angles(0, -ang, 0),
				Color = Color3.fromRGB(70, 68, 62),
				Material = Enum.Material.Cobblestone,
				CanCollide = false,
			})
			crenellation(CFrame.new(x, hVar + 1.6, z) * CFrame.Angles(0, -ang, 0), segLen)
			-- passarela interna no topo (acompanha a altura variável do segmento)
			Build.part({
				Size = Vector3.new(5, 1, segLen),
				CFrame = cf * CFrame.new(6, hVar / 2 - 0.5, 0),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
		end
	end

	-- torres a cada 8 segmentos
	for i = 1, SEGMENTS, 8 do
		local ang = (i / SEGMENTS) * math.pi * 2
		local x, z = math.cos(ang) * R, math.sin(ang) * R
		if not (math.abs(x) < 60 and z < -R * 0.75) then
			tower(Vector3.new(x, 0, z), -ang)
		end
	end

	gatehouse()
end

return Walls
