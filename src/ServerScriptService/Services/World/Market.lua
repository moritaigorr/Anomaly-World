--!strict
-- Market.lua  (SERVIDOR)
-- A PRAÇA. É o hub social da cidade, no molde de praça de MMORPG: banco,
-- mercadores de arma, armadura, comida e poção, braseiros, e NPCs atrás de cada
-- balcão. É onde o jogador volta entre caçadas, então precisa ser grande o
-- bastante pra caber gente parada e legível o bastante pra achar o vendedor
-- certo de longe — pela COR do toldo, antes de ler qualquer placa.
--
-- Decisões que vieram de referência de feira real (e não de "mais um quadrado"):
--   · toldo LISTRADO, feito de tiras alternadas. Uma lona de cor sólida é a
--     leitura mais barata que existe; a listra é o que diz "mercado" em 1 frame.
--   · barraca GRANDE (16x11): dá pra entrar embaixo, tem balcão e prateleira.
--   · chão PELADO no miolo e em volta do fogo — neve não fica onde há gente e
--     brasa o dia inteiro. A neve sobra só na borda da praça.
--   · varal de luzes ligando os postes: amarra a praça como um espaço só.

local Build = require(script.Parent.Build)
local C = Build.C

local Market = {}

export type Vendor = {
	id: string,
	nome: string,
	papel: string,
	corA: Color3,
	corB: Color3,
	tunica: Color3,
}

-- Cada barraca é uma entrada aqui. Barraca nova = mais uma linha, sem tocar em
-- geometria. A cor do toldo é a identidade do comerciante à distância.
local VENDORS: { Vendor } = {
	{
		id = "ferreiro",
		nome = "Hulda Mão-de-Ferro",
		papel = "FERREIRO",
		corA = Color3.fromRGB(150, 58, 52),
		corB = Color3.fromRGB(232, 226, 214),
		tunica = Color3.fromRGB(74, 60, 50),
	},
	{
		id = "armeiro",
		nome = "Sveinn Escudo-Longo",
		papel = "ARMADURAS",
		corA = Color3.fromRGB(56, 78, 112),
		corB = Color3.fromRGB(232, 226, 214),
		tunica = Color3.fromRGB(58, 66, 82),
	},
	{
		id = "taberneiro",
		nome = "Gerda Pão-Quente",
		papel = "MANTIMENTOS",
		corA = Color3.fromRGB(168, 122, 52),
		corB = Color3.fromRGB(238, 231, 214),
		tunica = Color3.fromRGB(112, 84, 48),
	},
	{
		id = "alquimista",
		nome = "Yrsa da Bruma",
		papel = "ALQUIMIA",
		corA = Color3.fromRGB(74, 60, 96),
		corB = Color3.fromRGB(226, 224, 232),
		tunica = Color3.fromRGB(62, 52, 84),
	},
	{
		id = "anomalias",
		nome = "O Catalogador",
		papel = "ANOMALIAS",
		corA = Color3.fromRGB(20, 132, 122),
		corB = Color3.fromRGB(222, 232, 232),
		tunica = Color3.fromRGB(34, 62, 64),
	},
	{
		id = "peleiro",
		nome = "Ketil Pele-Grossa",
		papel = "PELES E PANOS",
		corA = Color3.fromRGB(122, 96, 60),
		corB = Color3.fromRGB(236, 230, 216),
		tunica = Color3.fromRGB(88, 72, 52),
	},
}

Market.vendors = VENDORS

-- =================================================================== NPC
-- Vendedor estilizado. Não é um R15 nem um boneco genérico: é uma silhueta
-- encapuzada, que é o que precisa ser reconhecível de longe atrás do balcão.
local function vendorNPC(cf: CFrame, v: Vendor): Model
	local model = Instance.new("Model")
	model.Name = "Vendedor_" .. v.id

	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local p = Build.part({
			Size = size,
			CFrame = cf * offset,
			Color = color,
			Material = material,
			CanCollide = false,
			Parent = model,
		})
		return p
	end

	local skin = Color3.fromRGB(206, 170, 138)

	-- pernas curtas: o balcão esconde da cintura pra baixo, então não vale
	-- gastar peça em detalhe que ninguém vê
	piece(Vector3.new(0.85, 2.4, 0.85), CFrame.new(-0.55, 1.2, 0), Color3.fromRGB(52, 44, 38), Enum.Material.Fabric)
	piece(Vector3.new(0.85, 2.4, 0.85), CFrame.new(0.55, 1.2, 0), Color3.fromRGB(52, 44, 38), Enum.Material.Fabric)

	-- túnica (tronco) — cor do ofício
	local torso = piece(Vector3.new(2.5, 3.0, 1.5), CFrame.new(0, 3.9, 0), v.tunica, Enum.Material.Fabric)
	-- cinto
	piece(Vector3.new(2.62, 0.42, 1.62), CFrame.new(0, 2.7, 0), Color3.fromRGB(58, 42, 30), Enum.Material.Fabric)
	-- braços
	piece(Vector3.new(0.8, 2.6, 0.8), CFrame.new(-1.62, 3.9, 0), v.tunica, Enum.Material.Fabric)
	piece(Vector3.new(0.8, 2.6, 0.8), CFrame.new(1.62, 3.9, 0), v.tunica, Enum.Material.Fabric)
	-- mãos
	piece(Vector3.new(0.7, 0.6, 0.7), CFrame.new(-1.62, 2.5, 0), skin, Enum.Material.Plastic)
	piece(Vector3.new(0.7, 0.6, 0.7), CFrame.new(1.62, 2.5, 0), skin, Enum.Material.Plastic)

	-- cabeça e capuz
	piece(Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, 6.1, 0), skin, Enum.Material.Plastic)
	piece(Vector3.new(1.75, 1.1, 1.75), CFrame.new(0, 6.75, 0), v.tunica, Enum.Material.Fabric)
	-- ombro do capuz caindo nas costas
	piece(Vector3.new(2.1, 1.2, 1.0), CFrame.new(0, 5.6, -0.5), v.tunica, Enum.Material.Fabric)

	model.PrimaryPart = torso

	-- placa com nome e ofício, pra achar o vendedor certo de longe
	local tag = Instance.new("BillboardGui")
	tag.Name = "Placa"
	tag.Size = UDim2.new(0, 210, 0, 42)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 90
	tag.Parent = torso

	local role = Instance.new("TextLabel")
	role.Size = UDim2.new(1, 0, 0.44, 0)
	role.BackgroundTransparency = 1
	role.Font = Enum.Font.Code
	role.Text = v.papel
	role.TextColor3 = Color3.fromRGB(47, 212, 194)
	role.TextScaled = true
	role.Parent = tag

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.56, 0)
	name.Position = UDim2.new(0, 0, 0.44, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamMedium
	name.Text = v.nome
	name.TextColor3 = Color3.fromRGB(226, 232, 238)
	name.TextScaled = true
	name.Parent = tag

	-- interação. O ShopService escuta por este prompt (CollectionService), então
	-- geometria e comércio ficam desacoplados: dá pra mover a praça inteira sem
	-- tocar em uma linha de lógica de loja.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Negociar"
	prompt.ObjectText = v.nome
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	model:SetAttribute("VendorId", v.id)
	model:AddTag("Vendor")
	model.Parent = Build.getRoot()
	return model
end

-- =================================================================== BARRACA
-- Toldo listrado: tiras alternadas em vez de uma lona sólida. É a diferença
-- entre "pano colorido" e "mercado".
local function stripedAwning(ridge: CFrame, width: number, slopeLen: number, a: Color3, b: Color3)
	local PITCH = math.rad(28)
	local stripeW = 1.5
	local n = math.floor(width / stripeW)
	local used = n * stripeW

	for _, s in { -1, 1 } do
		local slope = ridge * CFrame.Angles(s * PITCH, 0, 0) * CFrame.new(0, 0, s * slopeLen / 2)
		for i = 0, n - 1 do
			local x = -used / 2 + stripeW * (i + 0.5)
			Build.part({
				Size = Vector3.new(stripeW * 1.02, 0.3, slopeLen),
				CFrame = slope * CFrame.new(x, 0, 0),
				Color = (i % 2 == 0) and a or b,
				Material = Enum.Material.Fabric,
				CanCollide = false,
				CastShadow = false,
			})
		end
		-- barra da beirada: fecha a lona e projeta sombra no balcão
		Build.part({
			Size = Vector3.new(used + 0.4, 0.42, 0.42),
			CFrame = slope * CFrame.new(0, 0, s * slopeLen / 2),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- cumeeira
	Build.part({
		Size = Vector3.new(used + 0.6, 0.5, 0.5),
		CFrame = ridge,
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
		CastShadow = false,
	})
end

local function stall(cf: CFrame, v: Vendor)
	local W, D = 16, 11
	local POST_H = 8.2

	-- 4 postes de canto
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = (cf * CFrame.new(sx * (W / 2 - 0.6), 0, sz * (D / 2 - 0.6))).Position
			Build.post(p, POST_H, 0.62, C.TIMBER, Enum.Material.Wood)
		end
	end

	stripedAwning(cf * CFrame.new(0, POST_H + 1.5, 0), W, D * 0.72, v.corA, v.corB)

	-- BALCÃO na frente (+Z), com tampo saliente e painel fechando embaixo
	Build.part({
		Size = Vector3.new(W - 1.4, 0.5, 3.0),
		CFrame = cf * CFrame.new(0, 4.0, D / 2 - 1.6),
		Color = C.WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	Build.part({
		Size = Vector3.new(W - 2.2, 3.5, 0.5),
		CFrame = cf * CFrame.new(0, 2.2, D / 2 - 0.4),
		Color = C.WOOD_DARK,
		Material = Enum.Material.WoodPlanks,
	})

	-- PRATELEIRA no fundo, com mercadoria: é o que faz a barraca parecer cheia
	for shelf = 0, 1 do
		Build.part({
			Size = Vector3.new(W - 3, 0.35, 1.6),
			CFrame = cf * CFrame.new(0, 3.4 + shelf * 2.2, -D / 2 + 1.2),
			Color = C.WOOD_DARK,
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
		})
		for i = -3, 3 do
			if math.random() < 0.72 then
				local h = 0.7 + math.random() * 0.9
				Build.part({
					Size = Vector3.new(0.7 + math.random() * 0.5, h, 0.7),
					CFrame = cf
						* CFrame.new(i * 1.9 + (math.random() - 0.5), 3.4 + shelf * 2.2 + h / 2 + 0.2, -D / 2 + 1.2)
						* CFrame.Angles(0, math.random() * 2, 0),
					Color = Build.tint(v.tunica, 0.12),
					Material = Enum.Material.Fabric,
					CanCollide = false,
					CastShadow = false,
				})
			end
		end
	end

	-- mercadoria no balcão
	for i = -2, 2 do
		if math.random() < 0.6 then
			Build.part({
				Size = Vector3.new(1.1, 0.5, 1.1),
				CFrame = cf * CFrame.new(i * 2.8, 4.5, D / 2 - 1.6) * CFrame.Angles(0, math.random() * 2, 0),
				Color = Build.tint(C.WOOD, 0.1),
				Material = Enum.Material.WoodPlanks,
				CanCollide = false,
			})
		end
	end

	-- placa do ofício, pendurada na frente do toldo
	local sign = Build.part({
		Size = Vector3.new(7.5, 1.9, 0.3),
		CFrame = cf * CFrame.new(0, POST_H + 0.2, D / 2 - 0.2),
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
	st.Text = v.papel
	st.TextColor3 = Color3.fromRGB(238, 226, 196)
	st.TextScaled = true
	st.Parent = sg

	-- barril e caixa ao lado, pra barraca não terminar numa linha reta
	Build.barrel((cf * CFrame.new(-W / 2 - 1.4, 0, D / 4)).Position)
	Build.crate((cf * CFrame.new(W / 2 + 1.5, 0, D / 5)).Position, 2.1)

	-- o vendedor fica ATRÁS do balcão, virado pra fora
	vendorNPC(cf * CFrame.new(0, 0, D / 2 - 4.4), v)
end

-- =================================================================== BRASEIRO
-- Fogo em pé no meio da praça. Em volta dele o chão fica PELADO: brasa acesa o
-- dia inteiro não deixa neve acumular, e é exatamente esse contraste que faz o
-- fogo parecer quente em vez de decorativo.
local function brazier(pos: Vector3)
	-- Brasa acesa o dia inteiro não deixa neve acumular em volta. É esse anel
	-- pelado que faz o fogo parecer QUENTE em vez de decorativo.
	Build.paintGround(pos.X, pos.Z, 17)
	Build.paintGround(pos.X + 6, pos.Z - 4, 11)
	Build.paintGround(pos.X - 5, pos.Z + 6, 10)

	Build.post(pos, 3.2, 2.6, C.STONE_DARK, Enum.Material.Cobblestone)
	Build.post(pos + Vector3.new(0, 3.0, 0), 1.4, 4.2, C.STONE, Enum.Material.Cobblestone)
	-- lenha
	for i = 0, 4 do
		local a = (i / 5) * math.pi * 2
		Build.part({
			Size = Vector3.new(0.45, 2.2, 0.45),
			CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * 0.7, 4.9, math.sin(a) * 0.7))
				* CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4),
			Color = C.WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CastShadow = false,
		})
	end
	local fire = Build.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 5.4, 0)),
		Color = C.FIRE,
		Material = Enum.Material.Neon,
		Transparency = 0.22,
		CanCollide = false,
		CastShadow = false,
	})
	Build.light(fire, C.FIRE, 1.0, 22)
end

-- =================================================================== BANCO
local function bank(cf: CFrame)
	local W, D, H = 26, 18, 13

	Build.part({ -- corpo
		Size = Vector3.new(W, H, D),
		CFrame = cf * CFrame.new(0, H / 2, 0),
		Color = Build.tint(C.STONE, 0.03),
		Material = Enum.Material.Cobblestone,
	})
	Build.part({ -- embasamento
		Size = Vector3.new(W + 1.6, 1.6, D + 1.6),
		CFrame = cf * CFrame.new(0, 0.8, 0),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})
	Build.part({ -- cornija
		Size = Vector3.new(W + 2.2, 1.2, D + 2.2),
		CFrame = cf * CFrame.new(0, H, 0),
		Color = C.STONE_LIGHT,
		Material = Enum.Material.Cobblestone,
		CastShadow = false,
	})
	-- telhado em duas águas
	local rh = 6
	for _, s in { -1, 1 } do
		local slope = math.sqrt((W / 2) ^ 2 + rh * rh)
		Build.part({
			Size = Vector3.new(slope, 0.9, D + 3),
			CFrame = cf
				* CFrame.new(s * (W / 4), H + 0.6 + rh / 2, 0)
				* CFrame.Angles(0, 0, -s * math.atan2(rh, W / 2)),
			Color = C.ROOF_SHINGLE,
			Material = Enum.Material.Slate,
		})
	end

	-- pórtico: quatro colunas na frente. Colunata é o que diz "instituição"
	-- num relance — é por isso que banco de verdade tem coluna.
	for i = -1.5, 1.5, 1 do
		Build.post((cf * CFrame.new(i * 6.4, 0, D / 2 + 2.2)).Position, 10.5, 2.1, C.STONE_LIGHT, Enum.Material.Cobblestone)
	end
	Build.part({
		Size = Vector3.new(W - 1, 1.8, 5.2),
		CFrame = cf * CFrame.new(0, 11.2, D / 2 + 2.2),
		Color = C.STONE_LIGHT,
		Material = Enum.Material.Cobblestone,
	})
	-- frontão
	for i = 0, 5 do
		local w = (W - 2) * (1 - i / 6)
		Build.part({
			Size = Vector3.new(w, 0.9, 5.2),
			CFrame = cf * CFrame.new(0, 12.3 + i * 0.85, D / 2 + 2.2),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end

	-- porta dupla
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(3.0, 7.5, 0.5),
			CFrame = cf * CFrame.new(s * 1.6, 3.75, D / 2 + 0.1),
			Color = C.WOOD_DARK,
			Material = Enum.Material.WoodPlanks,
		})
	end

	-- placa
	local sign = Build.part({
		Size = Vector3.new(11, 2.4, 0.35),
		CFrame = cf * CFrame.new(0, 9.4, D / 2 + 0.3),
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
	st.Text = "CASA DE DEPÓSITO"
	st.TextColor3 = Color3.fromRGB(240, 210, 140)
	st.TextScaled = true
	st.Parent = sg

	Build.banner(cf * CFrame.new(-W / 2 + 1.5, 8, D / 2 + 0.4), 9, C.BANNER_2)
	Build.banner(cf * CFrame.new(W / 2 - 1.5, 8, D / 2 + 0.4), 9, C.BANNER_2)

	vendorNPC(cf * CFrame.new(0, 0, D / 2 + 6), {
		id = "banqueiro",
		nome = "Mestre Alrik",
		papel = "BANCO",
		corA = C.BANNER_2,
		corB = C.STONE_LIGHT,
		tunica = Color3.fromRGB(46, 54, 72),
	})
end

-- =================================================================== VARAL
-- Varal de lâmpadas entre postes. Amarra a praça como UM espaço em vez de um
-- punhado de barracas soltas, e dá um segundo nível de luz acima da cabeça.
local function lightLine(a: Vector3, b: Vector3)
	local n = 9
	local sag = 2.6
	local prev: Vector3? = nil
	for i = 0, n do
		local t = i / n
		local p = a:Lerp(b, t) + Vector3.new(0, -math.sin(t * math.pi) * sag, 0)
		if prev then
			local mid = (prev + p) / 2
			local d = p - prev
			Build.part({
				Size = Vector3.new(d.Magnitude + 0.1, 0.1, 0.1),
				CFrame = CFrame.lookAt(mid, mid + d.Unit) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(38, 34, 30),
				Material = Enum.Material.Fabric,
				CanCollide = false,
				CastShadow = false,
			})
		end
		if i > 0 and i < n then
			local bulb = Build.part({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.55, 0.55, 0.55),
				CFrame = CFrame.new(p - Vector3.new(0, 0.45, 0)),
				Color = Color3.fromRGB(255, 206, 138),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				CanCollide = false,
				CastShadow = false,
			})
			if i % 3 == 0 then
				Build.light(bulb, Color3.fromRGB(255, 196, 130), 0.3, 10)
			end
		end
		prev = p
	end
end

-- =================================================================== PRAÇA
function Market.build(center: Vector3, radius: number)
	-- CHÃO DA PRAÇA.
	--
	-- Isto eram 90 LAJES de calçamento sorteadas e sobrepostas, cada uma com
	-- rotação e tamanho aleatórios, todas na mesma altura. O resultado é o que
	-- se vê quando se olha pra baixo: retângulo em cima de retângulo brigando
	-- por z, com quinas soltas apontando pra tudo quanto é lado.
	--
	-- Chão é TERRENO. Já aprendi isso na neve e não apliquei aqui. O terreno
	-- tem material Cobblestone: superfície ÚNICA, contínua, sem sobreposição,
	-- sem z-fighting, com iluminação e textura próprias — e custa zero peça.
	--
	-- A praça fica em dois anéis: calçamento no miolo (onde fica o monumento e
	-- circula gente) e terra batida em volta (onde ficam as barracas), porque
	-- calçamento até a borda vira um disco perfeito de novo.
	local paved = radius * 0.5
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2 + math.random() * 0.25
		local off = math.sqrt(math.random()) * paved * 0.5
		Build.paintGround(
			center.X + math.cos(a) * off,
			center.Z + math.sin(a) * off,
			paved * (0.7 + math.random() * 0.4),
			Enum.Material.Cobblestone
		)
	end
	-- anel de terra batida em volta do calçamento
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2 + math.random() * 0.2
		local off = paved * 0.85 + math.random() * radius * 0.28
		Build.paintGround(
			center.X + math.cos(a) * off,
			center.Z + math.sin(a) * off,
			radius * (0.3 + math.random() * 0.2)
		)
	end

	-- neve sobrando na borda
	for i = 1, 40 do
		local a = (i / 40) * math.pi * 2 + math.random() * 0.14
		local r = radius * (0.82 + math.random() * 0.2)
		Build.drift(center + Vector3.new(math.cos(a) * r, 0.35, math.sin(a) * r), 3.4, 4.4)
	end

	-- MONUMENTO central: pedra de juramento com runa. Dá um ponto focal e um
	-- lugar natural pra jogador ficar parado esperando amigo.
	Build.post(center, 1.4, 16, C.STONE_DARK, Enum.Material.Cobblestone)
	Build.post(center + Vector3.new(0, 1.2, 0), 1.2, 12, C.STONE, Enum.Material.Cobblestone)
	Build.part({
		Size = Vector3.new(4.2, 11, 2.6),
		CFrame = CFrame.new(center + Vector3.new(0, 7.5, 0)) * CFrame.Angles(0, math.rad(18), 0),
		Color = C.STONE,
		Material = Enum.Material.Rock,
	})
	local rune = Build.part({
		Size = Vector3.new(2.0, 3.4, 0.2),
		CFrame = CFrame.new(center + Vector3.new(0, 9, 1.4)) * CFrame.Angles(0, math.rad(18), 0),
		Color = C.RUNE,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	})
	Build.light(rune, C.RUNE, 0.8, 18)

	-- BRASEIROS em volta do monumento
	for i = 0, 3 do
		local a = (i / 4) * math.pi * 2 + math.rad(45)
		brazier(center + Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22))
	end

	-- BARRACAS. Os ângulos são EXPLÍCITOS, não um anel regular, por um motivo
	-- concreto: a rua principal atravessa a praça no eixo norte-sul (x≈0), e um
	-- anel de seis barracas espaçadas igualmente plantava duas delas EM CIMA da
	-- estrada. Praça de verdade tem a rua passando por dentro — o corredor tem
	-- que ficar livre. Todos os ângulos abaixo mantêm |x| ≥ 29 studs.
	local STALL_ANGLES = { 0, 40, 140, 180, 220, 320 }
	local LAMP_ANGLES = { 20, 68, 112, 160, 200, 250, 290, 340 }
	local ringR = radius * 0.74
	local postTops: { Vector3 } = {}

	for i, v in VENDORS do
		local a = math.rad(STALL_ANGLES[i] or (i * 60))
		local p = center + Vector3.new(math.cos(a) * ringR, 0, math.sin(a) * ringR)
		-- a frente da barraca (+Z local) tem que olhar pro centro
		stall(CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), v)
	end

	for _, deg in LAMP_ANGLES do
		local a = math.rad(deg)
		local lp = center + Vector3.new(math.cos(a) * ringR, 0, math.sin(a) * ringR)
		Build.lantern(lp, true)
		table.insert(postTops, lp + Vector3.new(0, 8.4, 0))
	end

	-- varal ligando os postes
	for i, p in postTops do
		local q = postTops[(i % #postTops) + 1]
		lightLine(p, q)
	end

	-- BANCO fora do anel, virado pro centro
	-- Ângulo fixo, fora do anel e fora do corredor da rua (|x| = 23 studs).
	-- Antes isto derivava de `n`, que deixou de existir quando o anel virou
	-- lista explícita de ângulos — e o erro derrubava a construção da CIDADE
	-- INTEIRA, não só do banco.
	local ba = math.rad(110)
	local bp = center + Vector3.new(math.cos(ba) * (radius + 16), 0, math.sin(ba) * (radius + 16))
	bank(CFrame.lookAt(bp, Vector3.new(center.X, bp.Y, center.Z)))
end

return Market
