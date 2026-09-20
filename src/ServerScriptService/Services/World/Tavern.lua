--!strict
-- Tavern.lua  (SERVIDOR)
-- AS CONSTRUÇÕES EM QUE O JOGADOR ENTRA: a taverna e as casas habitadas.
--
-- POR QUE ELA NÃO É UMA CASA DO KIT. As casas da cidade são malhas prontas:
-- ótimas de fora, mas são cascas fechadas — a parede é uma Union só, não dá pra
-- abrir um vão nela em tempo de execução sem CSG, que é caro e falha. Então a
-- taverna é construída aqui, parede por parede, justamente pra ter um VÃO DE
-- PORTA de verdade e um volume interno onde cabe gente.
--
-- O que é asset e o que é construído:
--   · casca (alicerce, paredes, vigas, telhado, chaminé) — construída, porque
--     precisa do buraco da porta e das janelas no lugar certo
--   · recheio (balcão, mesas, bancos, lustre, baús, tapetes, bandeiras) — kit
--     de mobília medieval, em ServerStorage._Mobilia
--
-- LUZ. Taverna é o ponto quente da cidade: lareira acesa, lustre e velas. É o
-- contraste com a rua nevada que faz o jogador querer entrar.

local ServerStorage = game:GetService("ServerStorage")

local Build = require(script.Parent.Build)
local C = Build.C

local Tavern = {}

-- onde ela fica e quanto ocupa (o Town usa isto pra não plantar casa em cima)
Tavern.POS = Vector3.new(-96, 0, -112)
Tavern.ROT = math.rad(12)
Tavern.W = 34 -- largura (X)
Tavern.D = 26 -- profundidade (Z)
Tavern.CLEAR = 30 -- raio livre em volta

local WALL_H = 14
local T = 1.0 -- espessura da parede
local DOOR_W = 8
local DOOR_H = 11

-- ---------------------------------------------------------------- mobília
local function mob(nome: string, cf: CFrame, escala: number?): Model?
	local pasta = ServerStorage:FindFirstChild("_Mobilia")
	local molde = pasta and pasta:FindFirstChild(nome)
	if not (molde and molde:IsA("Model")) then
		return nil
	end
	local copia = molde:Clone()
	if escala and math.abs(escala - 1) > 0.01 then
		pcall(function()
			copia:ScaleTo(escala)
		end)
	end
	-- o molde está guardado com o pivô na BASE, então o CFrame pedido é o chão
	copia:PivotTo(cf)
	for _, d in copia:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			-- móvel pequeno não precisa de casco de colisão nem de sombra:
			-- são dezenas deles dentro de uma sala fechada
			local maior = math.max(d.Size.X, d.Size.Y, d.Size.Z)
			d.CanCollide = maior >= 2
			d.CastShadow = maior >= 2.5
		end
	end
	copia.Parent = Build.getRoot()
	return copia
end

-- peça decorativa presa na parede (bandeira, escudo)
local function naParede(nome: string, cf: CFrame): BasePart?
	local pasta = ServerStorage:FindFirstChild("_Mobilia")
	local molde = pasta and pasta:FindFirstChild(nome)
	if not (molde and molde:IsA("BasePart")) then
		return nil
	end
	local copia = molde:Clone()
	copia.Anchored = true
	copia.CanCollide = false
	copia.CastShadow = false
	copia.CFrame = cf
	copia.Parent = Build.getRoot()
	return copia
end

-- ---------------------------------------------------------------- a casca
-- Parede com um VÃO no meio. É isto que uma malha pronta não permite: em vez de
-- uma peça só, são três (esquerda, direita e verga), e o buraco entre elas é a
-- porta. Trivial de fazer aqui, impossível de abrir num Union em runtime.
local function paredeComVao(base: CFrame, largura: number, altura: number, vaoW: number, vaoH: number, cor: Color3, mat: Enum.Material)
	local lado = (largura - vaoW) / 2
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(lado, altura, T),
			CFrame = base * CFrame.new(sx * (vaoW / 2 + lado / 2), altura / 2, 0),
			Color = cor,
			Material = mat,
		})
	end
	-- verga sobre o vão
	Build.part({
		Size = Vector3.new(vaoW, altura - vaoH, T),
		CFrame = base * CFrame.new(0, vaoH + (altura - vaoH) / 2, 0),
		Color = cor,
		Material = mat,
	})
end

function Tavern.build()
	local pos = Tavern.POS
	local W, D = Tavern.W, Tavern.D
	local piso = Build.GROUND_LEVEL
	local base = CFrame.new(pos.X, piso, pos.Z) * CFrame.Angles(0, Tavern.ROT, 0)
	local pedra = Build.tint(C.STONE, 0.04)

	-- terreno nivelado sob a construção e na soleira
	Build.paintGround(pos.X, pos.Z, math.max(W, D) + 8, Enum.Material.Cobblestone)

	-- ---- alicerce e piso ----
	Build.part({
		Size = Vector3.new(W + 2.4, 1.6, D + 2.4),
		CFrame = base * CFrame.new(0, -0.3, 0),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})
	Build.part({ -- piso interno de tábua
		Size = Vector3.new(W - T * 2, 0.4, D - T * 2),
		CFrame = base * CFrame.new(0, 0.7, 0),
		Color = C.WOOD_DARK,
		Material = Enum.Material.WoodPlanks,
	})

	-- ---- paredes ----
	-- frente (+Z): entrada
	paredeComVao(base * CFrame.new(0, 0, D / 2), W, WALL_H, DOOR_W, DOOR_H, pedra, Enum.Material.Cobblestone)
	-- fundo (-Z): fechado
	Build.part({
		Size = Vector3.new(W, WALL_H, T),
		CFrame = base * CFrame.new(0, WALL_H / 2, -D / 2),
		Color = pedra,
		Material = Enum.Material.Cobblestone,
	})
	-- laterais, cada uma com uma janela alta (luz entra, ninguém passa)
	for _, sx in { -1, 1 } do
		paredeComVao(
			base * CFrame.new(sx * W / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			D,
			WALL_H,
			7,
			0,
			pedra,
			Enum.Material.Cobblestone
		)
		-- a janela é o vão da parede lateral, fechado só na parte de baixo
		Build.part({
			Size = Vector3.new(7, 6, T),
			CFrame = base * CFrame.new(sx * W / 2, 3, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = pedra,
			Material = Enum.Material.Cobblestone,
		})
		Build.part({ -- vidro quente
			Size = Vector3.new(6.6, 4.6, 0.2),
			CFrame = base * CFrame.new(sx * W / 2, 8.4, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = C.WINDOW,
			Material = Enum.Material.Glass,
			Transparency = 0.45,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- ---- enxaimel: vigas aparentes quebrando a parede de pedra ----
	-- PULA O VÃO DA PORTA. O laço ia de -2 a 2 e a viga i = 0 caía exatamente no
	-- meio da entrada: de fora parecia enfeite, mas era uma barra sólida de 14
	-- studs atravessando a porta. A taverna tinha interior e ninguém conseguia
	-- entrar. Pego por raycast na validação, não a olho nu.
	for i = -2, 2 do
		local vx = i * (W / 5.2)
		if math.abs(vx) > DOOR_W / 2 + 0.8 then
			Build.part({
				Size = Vector3.new(0.7, WALL_H, 0.7),
				CFrame = base * CFrame.new(vx, WALL_H / 2, D / 2 + 0.5),
				Color = C.TIMBER,
				Material = Enum.Material.Wood,
				CanCollide = false,
			})
		end
	end

	-- ---- telhado de duas águas ----
	local rh = 8
	local half = W / 2 + 1.2
	local slope = math.sqrt(half * half + rh * rh)
	local pitch = math.atan2(rh, half)
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(slope, 0.7, D + 3),
			CFrame = base
				* CFrame.new(s * (half / 2), WALL_H + rh / 2, 0)
				* CFrame.Angles(0, 0, -s * pitch),
			Color = Build.tint(C.ROOF_SHINGLE, 0.04),
			Material = Enum.Material.Slate,
		})
		-- neve na água do telhado
		Build.part({
			Size = Vector3.new(slope * 0.88, 0.32, D + 2.2),
			CFrame = base
				* CFrame.new(s * (half / 2), WALL_H + rh / 2 + 0.5, 0)
				* CFrame.Angles(0, 0, -s * pitch),
			Color = C.SNOW,
			Material = Enum.Material.Snow,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- OITÃO: a parede triangular entre o topo da parede e a cumeeira.
	-- Sem ela o telhado fica uma tampa apoiada em quatro paredes: de fora
	-- enxerga-se o vão do telhado e de dentro enxerga-se o céu. Montado em
	-- faixas horizontais que estreitam — degrau pequeno o bastante pra ler como
	-- triângulo e barato o bastante pra não pesar.
	local faixas = 7
	for _, sz in { -1, 1 } do
		for i = 0, faixas - 1 do
			local t0 = i / faixas
			local t1 = (i + 1) / faixas
			local larguraMedia = W * (1 - (t0 + t1) / 2)
			Build.part({
				Size = Vector3.new(larguraMedia, rh / faixas + 0.05, T),
				CFrame = base * CFrame.new(0, WALL_H + rh * (t0 + t1) / 2, sz * D / 2),
				Color = pedra,
				Material = Enum.Material.Cobblestone,
			})
		end
	end

	-- cumeeira
	Build.part({
		Size = Vector3.new(1.6, 1.0, D + 3.4),
		CFrame = base * CFrame.new(0, WALL_H + rh, 0),
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
	})

	-- ---- chaminé ----
	Build.part({
		Size = Vector3.new(3.2, WALL_H + rh + 5, 3.2),
		CFrame = base * CFrame.new(-W / 2 + 4, (WALL_H + rh + 5) / 2, -D / 2 + 3),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})

	-- ---- placa pendurada na frente ----
	Build.part({
		Size = Vector3.new(4.5, 0.4, 0.4),
		CFrame = base * CFrame.new(DOOR_W / 2 + 2.6, DOOR_H + 1.6, D / 2 + 2.2),
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	-- A placa tem que olhar pra QUEM CHEGA, ou seja, pro +Z da taverna. Sem o
	-- giro ela ficava de perfil e o letreiro não aparecia de lugar nenhum.
	local placa = Build.part({
		Size = Vector3.new(6.5, 3.6, 0.35),
		CFrame = base * CFrame.new(DOOR_W / 2 + 4.2, DOOR_H - 0.6, D / 2 + 2.2),
		Color = C.WOOD_DARK,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
	local letreiro = Instance.new("SurfaceGui")
	letreiro.Face = Enum.NormalId.Front
	letreiro.CanvasSize = Vector2.new(260, 140)
	letreiro.Parent = placa
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBlack
	txt.Text = "O CORVO\nDE INVERNO"
	txt.TextColor3 = Color3.fromRGB(232, 206, 150)
	txt.TextScaled = true
	txt.Parent = letreiro

	-- ================================================ INTERIOR
	local dentro = base * CFrame.new(0, 0.9, 0) -- em cima do assoalho

	-- LAREIRA: o ponto quente. Fica no canto da chaminé, pra fumaça fazer sentido.
	local lx, lz = -W / 2 + 4, -D / 2 + 3
	Build.part({
		Size = Vector3.new(6.4, 5.2, 4.4),
		CFrame = dentro * CFrame.new(lx, 2.6, lz + 1.6),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})
	Build.part({ -- boca escura da lareira
		Size = Vector3.new(4.2, 3.2, 1.2),
		CFrame = dentro * CFrame.new(lx, 1.7, lz + 3.6),
		Color = Color3.fromRGB(14, 12, 11),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	Build.fire((dentro * CFrame.new(lx, 1.2, lz + 3.4)).Position, 1.0, 26)

	-- BALCÃO no fundo, virado pra porta
	mob("Counter", dentro * CFrame.new(-2, 0, -D / 2 + 4) * CFrame.Angles(0, math.pi, 0), 1.1)
	mob("Cabinet", dentro * CFrame.new(8, 0, -D / 2 + 3) * CFrame.Angles(0, math.pi, 0), 1.0)
	mob("Barrel Suport", dentro * CFrame.new(13, 0, -D / 2 + 4), 1.0)

	-- MESAS com bancos, deixando o corredor da porta livre
	for _, m in
		{
			{ x = -9.5, z = 2.5, r = 0 },
			{ x = 9.5, z = 2.5, r = 0 },
			{ x = -9.5, z = -5.5, r = 0 },
		}
	do
		mob("Table", dentro * CFrame.new(m.x, 0, m.z) * CFrame.Angles(0, m.r, 0), 0.95)
		for _, sz in { -1, 1 } do
			mob(
				"Smal Seat",
				dentro * CFrame.new(m.x - 3, 0, m.z + sz * 3.2) * CFrame.Angles(0, math.random() * 0.4, 0),
				1.0
			)
			mob(
				"Smal Seat",
				dentro * CFrame.new(m.x + 3, 0, m.z + sz * 3.2) * CFrame.Angles(0, math.random() * 0.4, 0),
				1.0
			)
		end
	end
	mob("Round Table", dentro * CFrame.new(9.5, 0, -6), 0.8)
	mob("WIde Seat", dentro * CFrame.new(9.5, 0, -10) * CFrame.Angles(0, math.pi, 0), 1.0)

	-- LUSTRE no meio do salão
	mob("Chandelier", dentro * CFrame.new(0, WALL_H - 6.2, 0), 1.1)
	-- e uma luz quente onde ele está, senão o teto fica preto
	local brilho = Build.part({
		Size = Vector3.new(0.6, 0.6, 0.6),
		CFrame = dentro * CFrame.new(0, WALL_H - 4.2, 0),
		Color = C.FIRE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Transparency = 0.4,
	})
	Build.light(brilho, Color3.fromRGB(255, 205, 145), 2.4, 44)

	-- TAPETES, BAÚS e velas
	mob("Carpet", dentro * CFrame.new(0, 0, 6), 2.2)
	mob("Carpet_2", dentro * CFrame.new(-6, 0, -9), 1.6)
	mob("Chest", dentro * CFrame.new(-W / 2 + 3.5, 0, 7) * CFrame.Angles(0, math.pi / 2, 0), 1.0)
	mob("Round Chest", dentro * CFrame.new(W / 2 - 3.5, 0, -2) * CFrame.Angles(0, -math.pi / 2, 0), 1.0)
	mob("Candles", dentro * CFrame.new(-2, 3.2, -D / 2 + 4), 0.9)
	mob("Vase", dentro * CFrame.new(W / 2 - 3, 0, 8), 1.0)

	-- BANDEIRAS na parede do fundo
	for i, nome in { "Banner", "Banner_2", "Shield" } do
		naParede(nome, dentro * CFrame.new(-8 + (i - 1) * 8, 9.5, -D / 2 + T + 0.2))
	end

	-- luz de apoio junto ao balcão, pra silhueta do taberneiro não sumir
	local velaBalcao = Build.part({
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = dentro * CFrame.new(-2, 5.2, -D / 2 + 5),
		Color = C.FIRE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Transparency = 0.5,
	})
	Build.light(velaBalcao, Color3.fromRGB(255, 196, 130), 1.8, 30)

	-- SOLEIRA limpa na frente: quem entra não escala neve
	local soleira = base * Vector3.new(0, 0, D / 2 + 4)
	Build.paintGround(soleira.X, soleira.Z, 12, Enum.Material.Cobblestone)
end

-- ================================================================ CASA HABITADA
-- Mesma ideia da taverna, em escala de moradia: casca construída (pra ter o vão
-- da porta) e recheio de asset. São poucas no mapa de propósito — a maioria das
-- casas continua sendo a malha do kit, que é mais bonita de fora e mais barata.
-- Estas existem pra o jogador poder ENTRAR em alguma coisa no bairro, não só na
-- taverna.
Tavern.CASA_W = 22
Tavern.CASA_D = 18
Tavern.CASA_CLEAR = 22

function Tavern.buildCasa(pos: Vector3, rotGraus: number, quente: boolean)
	local W, D = Tavern.CASA_W, Tavern.CASA_D
	local H = 11
	local portaW, portaH = 6, 9
	local base = CFrame.new(pos.X, Build.GROUND_LEVEL, pos.Z) * CFrame.Angles(0, math.rad(rotGraus), 0)
	local pedra = Build.tint(C.STONE, 0.05)
	local reboco = Build.tint(C.PLASTER, 0.05)

	Build.paintGround(pos.X, pos.Z, math.max(W, D) + 6, Enum.Material.Cobblestone)

	-- alicerce e assoalho
	Build.part({
		Size = Vector3.new(W + 1.8, 1.4, D + 1.8),
		CFrame = base * CFrame.new(0, -0.25, 0),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})
	Build.part({
		Size = Vector3.new(W - T * 2, 0.4, D - T * 2),
		CFrame = base * CFrame.new(0, 0.65, 0),
		Color = C.WOOD_DARK,
		Material = Enum.Material.WoodPlanks,
	})

	-- paredes: pedra até a cintura, reboco acima (leitura de enxaimel)
	paredeComVao(base * CFrame.new(0, 0, D / 2), W, H, portaW, portaH, pedra, Enum.Material.Cobblestone)
	Build.part({
		Size = Vector3.new(W, H, T),
		CFrame = base * CFrame.new(0, H / 2, -D / 2),
		Color = reboco,
		Material = Enum.Material.Plaster,
	})
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(D, H, T),
			CFrame = base * CFrame.new(sx * W / 2, H / 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
			Color = reboco,
			Material = Enum.Material.Plaster,
		})
		-- janelinha acesa
		Build.part({
			Size = Vector3.new(3.4, 2.8, 0.25),
			CFrame = base * CFrame.new(sx * (W / 2 + 0.1), 6.2, 2) * CFrame.Angles(0, math.pi / 2, 0),
			Color = C.WINDOW,
			Material = Enum.Material.Glass,
			Transparency = 0.4,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- soco escuro na base, como nas casas do kit
	Build.part({
		Size = Vector3.new(W + 0.3, 2.2, D + 0.3),
		CFrame = base * CFrame.new(0, 1.1, 0),
		Color = pedra,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	})

	-- telhado + oitão
	local rh = 6
	local half = W / 2 + 1.0
	local slope = math.sqrt(half * half + rh * rh)
	local pitch = math.atan2(rh, half)
	for _, s2 in { -1, 1 } do
		Build.part({
			Size = Vector3.new(slope, 0.6, D + 2.4),
			CFrame = base * CFrame.new(s2 * (half / 2), H + rh / 2, 0) * CFrame.Angles(0, 0, -s2 * pitch),
			Color = Build.tint(C.ROOF_TILE, 0.05),
			Material = Enum.Material.Slate,
		})
		Build.part({
			Size = Vector3.new(slope * 0.86, 0.3, D + 1.8),
			CFrame = base * CFrame.new(s2 * (half / 2), H + rh / 2 + 0.45, 0) * CFrame.Angles(0, 0, -s2 * pitch),
			Color = C.SNOW,
			Material = Enum.Material.Snow,
			CanCollide = false,
			CastShadow = false,
		})
	end
	local faixas = 5
	for _, sz in { -1, 1 } do
		for i = 0, faixas - 1 do
			local t0, t1 = i / faixas, (i + 1) / faixas
			Build.part({
				Size = Vector3.new(W * (1 - (t0 + t1) / 2), rh / faixas + 0.05, T),
				CFrame = base * CFrame.new(0, H + rh * (t0 + t1) / 2, sz * D / 2),
				Color = reboco,
				Material = Enum.Material.Plaster,
			})
		end
	end
	-- chaminé
	Build.part({
		Size = Vector3.new(2.4, H + rh + 4, 2.4),
		CFrame = base * CFrame.new(-W / 2 + 3, (H + rh + 4) / 2, -D / 2 + 2.6),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})

	-- ---- interior ----
	local dentro = base * CFrame.new(0, 0.85, 0)
	local lx, lz = -W / 2 + 3, -D / 2 + 2.6
	Build.part({ -- boca da lareira
		Size = Vector3.new(3.4, 2.6, 1.0),
		CFrame = dentro * CFrame.new(lx, 1.4, lz + 1.6),
		Color = Color3.fromRGB(14, 12, 11),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	if quente then
		Build.fire((dentro * CFrame.new(lx, 1.0, lz + 1.5)).Position, 0.75, 18)
	end

	mob("Smal Round Table", dentro * CFrame.new(2, 0, -1), 1.0)
	mob("Smal Seat", dentro * CFrame.new(-1.4, 0, -1) * CFrame.Angles(0, math.pi / 2, 0), 1.0)
	mob("Smal Seat", dentro * CFrame.new(5.4, 0, -1) * CFrame.Angles(0, -math.pi / 2, 0), 1.0)
	mob("Cabinet", dentro * CFrame.new(W / 2 - 3, 0, -D / 2 + 3) * CFrame.Angles(0, -math.pi / 2, 0), 0.9)
	mob("Chest", dentro * CFrame.new(W / 2 - 3.5, 0, 4) * CFrame.Angles(0, -math.pi / 2, 0), 0.9)
	mob("Carpet_3", dentro * CFrame.new(1, 0, 3), 1.6)
	mob("Candles", dentro * CFrame.new(2, 2.1, -1), 0.7)

	-- luz interna quente
	local vela = Build.part({
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = dentro * CFrame.new(1, 6.4, 0),
		Color = C.FIRE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
		Transparency = 0.5,
	})
	Build.light(vela, Color3.fromRGB(255, 198, 138), 1.7, 26)

	-- soleira limpa
	local soleira = base * Vector3.new(0, 0, D / 2 + 3)
	Build.paintGround(soleira.X, soleira.Z, 9, Enum.Material.Cobblestone)
end

return Tavern
