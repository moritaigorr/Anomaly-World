--!strict
-- Wilds.lua  (SERVIDOR)
-- Tudo fora da muralha: floresta de pinheiros, forte em ruínas na encosta,
-- túmulo antigo, pedras rúnicas que marcam as zonas de caça e o círculo ritual
-- onde o boss desperta. Referência: fortes arruinados e marcos de Skyrim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local Assets = require(script.Parent.Assets)
local Build = require(script.Parent.Build)
local Walls = require(script.Parent.Walls)
local C = Build.C

local Wilds = {}

Wilds.BOSS_POS = Vector3.new(-300, 0, 300) -- círculo ritual, longe da cidade

-- PINHEIRO.
--
-- PRIMITIVAS NÃO DERAM CONTA. Duas tentativas: quatro cilindros deitados (que
-- viravam pilha de panquecas de aresta dura) e seis elipsoides afunilados (que
-- melhoraram a silhueta mas continuavam lendo como formas empilhadas, porque é
-- o que eram). O problema não era o ajuste do perfil — era a ferramenta.
--
-- Agora é um MESH de verdade, do catálogo, com textura e neve pintada nos
-- galhos. Custa UMA peça por árvore em vez de sete, então além de ficar certo
-- ficou mais barato. As primitivas continuam aqui como plano B: se o asset não
-- carregar (conta sem acesso, rede fora), a floresta existe mesmo assim em vez
-- de o mapa aparecer pelado.
local FOLHA = Color3.fromRGB(62, 88, 66)
local FOLHA_FRIA = Color3.fromRGB(54, 82, 78)

local function pinePrimitivas(pos: Vector3, scale: number)
	local H = 20 * scale
	local R = 4.2 * scale
	Build.post(pos, H * 0.42, 1.1 * scale, C.WOOD_DARK, Enum.Material.Wood)
	local cor = Build.tint((math.random() < 0.3) and FOLHA_FRIA or FOLHA, 0.07)
	local N = 6
	for i = 0, N - 1 do
		local t = i / (N - 1)
		local f = 0.30 + t * 0.62
		local r = math.max(R * (1 - t) ^ 0.8, 0.45)
		Build.blob(CFrame.new(pos + Vector3.new(0, H * f, 0)), r * 2, 3.2 * scale, cor, Enum.Material.Grass)
	end
	if math.random() < 0.4 then
		Build.blob(CFrame.new(pos + Vector3.new(0, H * 0.84, 0)), 2.8 * scale, 1.4 * scale, C.SNOW, Enum.Material.Snow)
	end
end

local function pine(pos: Vector3, scale: number)
	-- o molde mede 15,5 de altura; scale 0.8..1.6 dá de 12 a 25 studs
	local m = Assets.spawn("PINE", pos, math.random(0, 359), scale, false)
	if not m then
		pinePrimitivas(pos, scale)
	end
end

local function forest()
	for _ = 1, 260 do
		local ang = math.random() * math.pi * 2
		local dist = Walls.RADIUS + 40 + math.random() * 240
		local x, z = math.cos(ang) * dist, math.sin(ang) * dist
		-- não planta no mar (leste) nem em cima das zonas/boss
		if x < 280 then
			-- no chão medido, não em y=0 (a superfície do terreno não está em 0)
			local p = Vector3.new(x, Build.groundY(x, z, 1), z)
			local ok = (p - Wilds.BOSS_POS).Magnitude > 70
			for _, zone in ZoneData.zones do
				if (p - zone.center).Magnitude < zone.radius + 8 then
					ok = false
				end
			end
			if ok then
				pine(p, 0.8 + math.random() * 0.8)
			end
		end
	end
end

-- pedra rúnica: o marco que se vê de longe e puxa o jogador pra zona
local function zoneMarkers()
	for _, z in ZoneData.zones do
		local h = 16
		Build.part({
			Size = Vector3.new(5, h, 2),
			CFrame = CFrame.new(z.center + Vector3.new(0, h / 2, 0))
				* CFrame.Angles(0, math.random() * 6, math.rad(math.random(-5, 5))),
			Color = C.STONE_DARK,
			Material = Enum.Material.Rock,
		})
		local r = Build.part({
			Size = Vector3.new(3, 6, 0.3),
			CFrame = CFrame.new(z.center + Vector3.new(0, h * 0.6, 1.15)),
			Color = C.RUNE,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		Build.light(r, C.RUNE, 1.0, 22)
		-- pedras menores em volta
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			Build.part({
				Size = Vector3.new(2.5, 4 + math.random() * 3, 2),
				CFrame = CFrame.new(z.center + Vector3.new(math.cos(a) * 11, 2, math.sin(a) * 11))
					* CFrame.Angles(0, a, math.rad(math.random(-9, 9))),
				Color = C.STONE_DARK,
				Material = Enum.Material.Rock,
			})
		end
	end
end

-- forte arruinado na encosta (ref. imagem do forte nevado)
local function ruinedFort()
	local c = Vector3.new(-320, 0, -190)
	-- base rochosa
	Build.part({
		Size = Vector3.new(120, 16, 90),
		CFrame = CFrame.new(c + Vector3.new(0, 8, 0)),
		Color = C.STONE_DARK,
		Material = Enum.Material.Rock,
	})
	-- muralhas parciais
	for i = 1, 7 do
		local h = 16 + math.random() * 20
		Build.part({
			Size = Vector3.new(8, h, 22),
			CFrame = CFrame.new(c + Vector3.new(-45 + i * 14, 16 + h / 2, -32))
				* CFrame.Angles(0, math.rad(math.random(-4, 4)), 0),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
		})
	end
	-- torre principal quebrada
	Build.part({
		Size = Vector3.new(26, 54, 26),
		CFrame = CFrame.new(c + Vector3.new(28, 16 + 27, 14)),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	Build.part({ -- topo desabado
		Size = Vector3.new(28, 8, 28),
		CFrame = CFrame.new(c + Vector3.new(28, 16 + 56, 14)) * CFrame.Angles(math.rad(9), 0, math.rad(6)),
		Color = C.STONE_DARK,
		Material = Enum.Material.Rock,
	})
	-- arcos
	for i = 0, 4 do
		local a = (i / 4) * math.pi
		Build.part({
			Size = Vector3.new(3.5, 3.5, 14),
			CFrame = CFrame.new(c + Vector3.new(-22 + math.cos(a) * 11, 16 + 8 + math.sin(a) * 11, 24)),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	for _, sx in { -33, -11 } do
		Build.part({
			Size = Vector3.new(3.5, 18, 14),
			CFrame = CFrame.new(c + Vector3.new(sx, 16 + 9, 24)),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
		})
	end
end

-- túmulo antigo (montículo com entrada de pedra)
local function barrow()
	local zone
	for _, z in ZoneData.zones do
		if z.id == "barrow" then
			zone = z
		end
	end
	if not zone then
		return
	end
	local c = zone.center
	-- O MONTÍCULO ERA UMA BOLA. Part com Shape = Ball ignora escala não uniforme
	-- e desenha ESFERA: pedir 56 x 26 x 56 dava um domo branco de 56 studs
	-- plantado na planície, visível de longe como uma bola de golfe gigante.
	-- Agora é a mesma malha de penhasco dos maciços, achatada e branca — tem
	-- aresta, face e sombra, que é o que faz ler como terra amontoada.
	if not Assets.spawnRelief(c, 58, 22, 54, math.random(0, 359), C.SNOW) then
		Build.part({
			Size = Vector3.new(50, 20, 50),
			CFrame = CFrame.new(c + Vector3.new(0, 6, 0)),
			Color = C.SNOW,
			Material = Enum.Material.Snow,
		})
	end
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(3.5, 12, 3.5),
			CFrame = CFrame.new(c + Vector3.new(sx * 5, 6, 26)),
			Color = C.STONE_DARK,
			Material = Enum.Material.Rock,
		})
	end
	Build.part({
		Size = Vector3.new(16, 3.5, 4),
		CFrame = CFrame.new(c + Vector3.new(0, 13.5, 26)),
		Color = C.STONE_DARK,
		Material = Enum.Material.Rock,
	})
	local r = Build.part({
		Size = Vector3.new(9, 1.2, 0.4),
		CFrame = CFrame.new(c + Vector3.new(0, 13.5, 28.2)),
		Color = C.RUNE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	Build.light(r, C.RUNE, 0.9, 18)
	-- boca escura da entrada
	Build.part({
		Size = Vector3.new(9, 11, 2),
		CFrame = CFrame.new(c + Vector3.new(0, 5.5, 25)),
		Color = Color3.fromRGB(12, 14, 16),
		Material = Enum.Material.Slate,
	})
end

-- círculo ritual do boss
local function bossCircle()
	local c = Wilds.BOSS_POS
	Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 116, 116),
		CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.DIRT,
		Material = Enum.Material.Ground,
	})
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		local h = 18 + math.random() * 9
		Build.part({
			Size = Vector3.new(6, h, 3),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 50, h / 2, math.sin(a) * 50))
				* CFrame.Angles(0, -a, math.rad(math.random(-6, 6))),
			Color = C.STONE_DARK,
			Material = Enum.Material.Rock,
		})
		local r = Build.part({
			Size = Vector3.new(2.4, 4, 0.3),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 48.2, h * 0.6, math.sin(a) * 48.2))
				* CFrame.Angles(0, -a, 0),
			Color = C.RUNE,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		if i % 3 == 0 then
			Build.light(r, C.RUNE, 0.9, 24)
		end
	end
	-- estrada do portão até o círculo
	Build.part({
		Size = Vector3.new(14, 0.5, 300),
		CFrame = CFrame.lookAt(
			Vector3.new(c.X / 2 - 40, 0.25, c.Z / 2 - 60),
			c
		),
		Color = C.DIRT,
		Material = Enum.Material.Ground,
		CanCollide = false,
	})
end

function Wilds.build()
	forest()
	zoneMarkers()
	ruinedFort()
	barrow()
	bossCircle()
end

return Wilds
