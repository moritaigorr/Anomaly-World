--!strict
-- Forge.lua  (SERVIDOR)
-- A FERRARIA.
--
-- Substitui o modelo de Toolbox que ocupava este papel. Aquele entrava como UM
-- MeshPart de 34x29x26 studs com TextureID vazio e material Plastic: um blob
-- cinza chapado, mais alto que qualquer casa, com colisão ligada, plantado duas
-- vezes dentro da cidade. Era o "modelo gigante sem textura" atrapalhando
-- movimento e leitura — e ainda por cima 3 dos 4 IDs do catálogo nem carregavam.
--
-- Construída com o mesmo kit das casas, ela é coerente com a cidade por
-- construção: mesma pedra, mesma madeira, mesmas fiadas de telha, mesma neve.
--
-- Leitura da ferraria à distância, em ordem: chaminé alta com fumaça, baia
-- aberta com o brilho laranja da forja, bigorna. Um jogador reconhece o ofício
-- antes de ler qualquer placa — que é o mesmo princípio da cor do toldo das
-- barracas.

local Build = require(script.Parent.Build)
local C = Build.C

local Forge = {}

local W, D = 18, 14 -- planta do corpo fechado
local WALL_H = 9.5
local BAY = 9 -- profundidade da baia aberta na frente

-- ---------------------------------------------------------------- TELHADO
-- Mesmas fiadas das casas: laje inclinada lisa é uma rampa; o que faz ler telha
-- é a sombra fina que cada fiada projeta na de baixo.
local function roof(base: CFrame, w: number, d: number, topY: number, col: Color3)
	local over = 1.6
	local rw, rd = w + over * 2, d + over * 2
	local rh = rw * 0.42
	local half = rw / 2
	local slope = math.sqrt(half * half + rh * rh)
	local pitch = math.atan2(rh, half)

	for _, s in { -1, 1 } do
		local rcf = base * CFrame.new(s * (rw / 4), topY + rh / 2, 0) * CFrame.Angles(0, 0, -s * pitch)
		Build.part({
			Size = Vector3.new(slope, 0.7, rd),
			CFrame = rcf,
			Color = col,
			Material = Enum.Material.Slate,
		})
		local courses = 4
		local cLen = slope / courses
		for ci = 0, courses - 1 do
			Build.part({
				Size = Vector3.new(cLen * 1.05, 0.28, rd + 0.12),
				CFrame = rcf * CFrame.new(-s * (slope / 2) + s * cLen * (ci + 0.5), 0.4 + (courses - ci) * 0.05, 0),
				Color = col:Lerp(Color3.fromRGB(20, 16, 14), 0.05 + (ci % 2) * 0.06),
				Material = Enum.Material.Slate,
				CanCollide = false,
				CastShadow = false,
			})
		end
		Build.roofSnow(rcf, slope, rd - 1.2, s)
	end

	-- cumeeira
	Build.part({
		Size = Vector3.new(1.2, 0.7, rd + 0.5),
		CFrame = base * CFrame.new(0, topY + rh + 0.1, 0),
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
		CastShadow = false,
	})
end

-- ---------------------------------------------------------------- FORJA
-- A lareira: onde nasce a luz laranja que identifica o prédio de longe.
local function hearth(base: CFrame, at: CFrame)
	local cf = base * at

	-- boca de pedra
	Build.part({
		Size = Vector3.new(6.5, 3.4, 4.4),
		CFrame = cf * CFrame.new(0, 1.7, 0),
		Color = Build.tint(C.STONE_DARK, 0.04),
		Material = Enum.Material.Cobblestone,
	})
	-- carvão brilhando dentro
	Build.part({
		Size = Vector3.new(4.4, 0.5, 2.8),
		CFrame = cf * CFrame.new(0, 3.35, 0),
		Color = Color3.fromRGB(120, 40, 18),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	Build.fire((cf * CFrame.new(0, 3.9, 0)).Position, 1.1, 26)

	-- campânula da chaminé, estreitando
	for i = 0, 3 do
		local f = i / 4
		Build.part({
			Size = Vector3.new(6.5 - f * 3.2, 1.0, 4.4 - f * 2.0),
			CFrame = cf * CFrame.new(0, 4.4 + i * 0.95, 0),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
end

-- ---------------------------------------------------------------- PROPS
local function anvil(base: CFrame, at: CFrame)
	local cf = base * at
	-- cepo
	Build.post((cf * CFrame.new(0, 0, 0)).Position, 2.2, 2.4, C.WOOD_DARK, Enum.Material.Wood)
	-- corpo da bigorna: base, cintura e mesa (a silhueta que diz "bigorna")
	Build.part({
		Size = Vector3.new(2.4, 0.45, 1.3),
		CFrame = cf * CFrame.new(0, 2.4, 0),
		Color = Color3.fromRGB(58, 58, 62),
		Material = Enum.Material.Metal,
	})
	Build.part({
		Size = Vector3.new(1.1, 0.55, 0.9),
		CFrame = cf * CFrame.new(0, 2.9, 0),
		Color = Color3.fromRGB(52, 52, 56),
		Material = Enum.Material.Metal,
	})
	Build.part({
		Size = Vector3.new(3.0, 0.5, 1.25),
		CFrame = cf * CFrame.new(0, 3.4, 0),
		Color = Color3.fromRGB(70, 70, 74),
		Material = Enum.Material.Metal,
	})
	-- bico cônico de um lado
	Build.part({
		Size = Vector3.new(1.5, 0.42, 0.6),
		CFrame = cf * CFrame.new(2.0, 3.4, 0),
		Color = Color3.fromRGB(70, 70, 74),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	-- martelo largado em cima
	Build.part({
		Size = Vector3.new(0.4, 0.4, 1.6),
		CFrame = cf * CFrame.new(-0.6, 3.85, 0) * CFrame.Angles(0, math.rad(24), 0),
		Color = C.WOOD,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	Build.part({
		Size = Vector3.new(0.75, 0.7, 0.7),
		CFrame = cf * CFrame.new(-0.6, 3.9, -0.85) * CFrame.Angles(0, math.rad(24), 0),
		Color = Color3.fromRGB(60, 60, 64),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
end

local function trough(base: CFrame, at: CFrame)
	local cf = base * at
	-- gamela de têmpera: madeira escura com água dentro
	for _, o in
		{
			{ Vector3.new(4.6, 1.6, 0.4), CFrame.new(0, 1.1, 1.3) },
			{ Vector3.new(4.6, 1.6, 0.4), CFrame.new(0, 1.1, -1.3) },
			{ Vector3.new(0.4, 1.6, 2.6), CFrame.new(2.3, 1.1, 0) },
			{ Vector3.new(0.4, 1.6, 2.6), CFrame.new(-2.3, 1.1, 0) },
			{ Vector3.new(4.6, 0.4, 2.6), CFrame.new(0, 0.2, 0) },
		}
	do
		Build.part({
			Size = o[1] :: Vector3,
			CFrame = cf * (o[2] :: CFrame),
			Color = C.WOOD_DARK,
			Material = Enum.Material.Wood,
		})
	end
	Build.part({
		Size = Vector3.new(4.2, 0.12, 2.2),
		CFrame = cf * CFrame.new(0, 1.55, 0),
		Color = Color3.fromRGB(58, 84, 96),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.2,
		CanCollide = false,
		CastShadow = false,
	})
end

local function weaponRack(base: CFrame, at: CFrame)
	local cf = base * at
	for _, sx in { -1, 1 } do
		Build.post((cf * CFrame.new(sx * 1.9, 0, 0)).Position, 5.2, 0.45, C.TIMBER, Enum.Material.Wood)
	end
	for _, y in { 2.2, 4.6 } do
		Build.part({
			Size = Vector3.new(4.4, 0.32, 0.32),
			CFrame = cf * CFrame.new(0, y, 0),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
	end
	-- lâminas encostadas, em ângulos ligeiramente diferentes
	for i = -1, 1 do
		if math.random() < 0.85 then
			local tilt = math.rad((math.random() - 0.5) * 14)
			Build.part({
				Size = Vector3.new(0.28, 4.2, 0.9),
				CFrame = cf * CFrame.new(i * 1.3, 2.6, -0.3) * CFrame.Angles(0, 0, tilt),
				Color = Color3.fromRGB(150, 152, 158),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			Build.part({ -- guarda
				Size = Vector3.new(1.1, 0.28, 0.3),
				CFrame = cf * CFrame.new(i * 1.3, 0.9, -0.3) * CFrame.Angles(0, 0, tilt),
				Color = C.TIMBER,
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
		end
	end
end

-- ---------------------------------------------------------------- FERRARIA
function Forge.build(pos: Vector3, yRot: number)
	local y = Build.groundY(pos.X, pos.Z, 2)
	local base = CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.rad(yRot), 0)
	local stone = Build.tint(C.STONE, 0.04)

	-- soleira: chão de pedra da oficina, nivelado, pra não ficar meia parede
	-- enterrada na neve
	Build.paintGround(pos.X, pos.Z, math.max(W, D) + BAY, Enum.Material.Cobblestone)

	-- ---- corpo fechado (fundo) ----
	for _, o in
		{
			{ Vector3.new(W, WALL_H, 1.2), CFrame.new(0, WALL_H / 2, -D / 2) }, -- fundo
			{ Vector3.new(1.2, WALL_H, D), CFrame.new(-W / 2, WALL_H / 2, 0) }, -- lateral
			{ Vector3.new(1.2, WALL_H, D), CFrame.new(W / 2, WALL_H / 2, 0) },
		}
	do
		Build.part({
			Size = o[1] :: Vector3,
			CFrame = base * (o[2] :: CFrame),
			Color = stone,
			Material = Enum.Material.Cobblestone,
		})
	end
	-- soco saliente: dá peso e "planta" o prédio
	Build.part({
		Size = Vector3.new(W + 1.4, 1.2, D + 1.4),
		CFrame = base * CFrame.new(0, 0.6, 0),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})
	-- faixa de fuligem na base: ferraria é suja de carvão
	Build.part({
		Size = Vector3.new(W + 0.1, 2.6, D + 0.1),
		CFrame = base * CFrame.new(0, 2.0, 0),
		Color = stone:Lerp(Color3.fromRGB(28, 24, 22), 0.5),
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	})

	roof(base, W, D, WALL_H, Build.tint(C.ROOF_SHINGLE, 0.04))

	-- ---- baia aberta na frente: quatro postes e um telhado mais baixo ----
	local bayZ = D / 2 + BAY / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Build.post(
				(base * CFrame.new(sx * (W / 2 - 0.8), 0, bayZ + sz * (BAY / 2 - 0.8))).Position,
				7.6,
				0.85,
				C.TIMBER,
				Enum.Material.Wood
			)
		end
	end
	-- viga corrida ligando os postes
	for _, sz in { -1, 1 } do
		Build.part({
			Size = Vector3.new(W - 0.6, 0.7, 0.7),
			CFrame = base * CFrame.new(0, 7.6, bayZ + sz * (BAY / 2 - 0.8)),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
			CastShadow = false,
		})
	end
	roof(base * CFrame.new(0, 0, bayZ), W - 1, BAY, 7.6, Build.tint(C.ROOF_SHINGLE, 0.04))

	-- ---- forja, encostada na parede do fundo ----
	hearth(base, CFrame.new(-W / 4, 0, -D / 2 + 3))

	-- CHAMINÉ: a leitura de longe. Alta o bastante pra aparecer sobre o telhado.
	local chimX = -W / 4
	Build.part({
		Size = Vector3.new(4.6, WALL_H + 12, 4.0),
		CFrame = base * CFrame.new(chimX, (WALL_H + 12) / 2, -D / 2 + 1.4),
		Color = Build.tint(C.STONE_DARK, 0.03),
		Material = Enum.Material.Cobblestone,
	})
	Build.part({ -- coroamento
		Size = Vector3.new(5.6, 0.9, 5.0),
		CFrame = base * CFrame.new(chimX, WALL_H + 12.2, -D / 2 + 1.4),
		Color = C.STONE_LIGHT,
		Material = Enum.Material.Cobblestone,
		CastShadow = false,
	})
	-- fumaça saindo
	local smokeAt = Build.part({
		Size = Vector3.new(1, 1, 1),
		CFrame = base * CFrame.new(chimX, WALL_H + 13, -D / 2 + 1.4),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Fumaca"
	smoke.Rate = 7
	smoke.Lifetime = NumberRange.new(3.5, 6)
	smoke.Speed = NumberRange.new(3.5, 6)
	smoke.SpreadAngle = Vector2.new(9, 9)
	smoke.Acceleration = Vector3.new(1.2, 2.2, 0)
	smoke.LightInfluence = 1
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 11),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.35, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(96, 96, 100), Color3.fromRGB(150, 152, 156))
	smoke.Parent = smokeAt

	-- ---- oficina ----
	anvil(base, CFrame.new(2.5, 0, D / 2 + 2.5))
	trough(base, CFrame.new(-W / 2 + 3.5, 0, D / 2 + 5.5))
	weaponRack(base, CFrame.new(W / 2 - 2.6, 0, D / 2 + 1.5) * CFrame.Angles(0, math.rad(-90), 0))

	Build.barrel((base * CFrame.new(W / 2 - 1.8, 0, -D / 2 + 2.5)).Position)
	Build.barrel((base * CFrame.new(W / 2 + 2.2, 0, D / 2 + 6.5)).Position)
	Build.crate((base * CFrame.new(-W / 2 + 2.0, 0, D / 2 + 8.0)).Position, 2.2)

	-- pilha de carvão ao lado da forja
	for i = 1, 7 do
		local a = math.random() * math.pi * 2
		local r = math.random() * 1.7
		Build.part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1) * (0.7 + math.random() * 0.8),
			CFrame = base * CFrame.new(-W / 4 + 4.4 + math.cos(a) * r, 0.45, -D / 2 + 4 + math.sin(a) * r),
			Color = Color3.fromRGB(32, 30, 30),
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
	end

	-- placa pendurada na viga da frente
	local sign = Build.part({
		Size = Vector3.new(5.4, 1.7, 0.28),
		CFrame = base * CFrame.new(0, 6.4, bayZ + BAY / 2 - 0.9),
		Color = C.WOOD_DARK,
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
		CastShadow = false,
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 40
	sg.Parent = sign
	local st = Instance.new("TextLabel")
	st.Size = UDim2.fromScale(1, 1)
	st.BackgroundTransparency = 1
	st.Font = Enum.Font.Code
	st.Text = "FERRARIA"
	st.TextColor3 = Color3.fromRGB(238, 210, 160)
	st.TextScaled = true
	st.Parent = sg

	-- lanterna na entrada
	Build.lantern((base * CFrame.new(W / 2 + 1.6, 0, bayZ + BAY / 2 - 1)).Position, true)
end

return Forge
