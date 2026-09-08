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

-- POSIÇÃO DO BANCO, exportada porque o Town precisa dela pra não encostar casa
-- nele. Fica FORA do anel de barracas, num ângulo que mantém o corredor da rua
-- principal (x≈0) livre — na borda da praça ele acabava a 2,7 studs do ponto de
-- spawn, e o jogador nascia colado numa parede.
Market.BANK_ANGLE = math.rad(150)
Market.BANK_EXTRA = 24 -- quanto além do raio da praça
Market.BANK_CLEAR = 26 -- raio livre de casas em volta dele

function Market.bankCenter(center: Vector3, radius: number): Vector3
	local d = radius + Market.BANK_EXTRA
	return Vector3.new(
		center.X + math.cos(Market.BANK_ANGLE) * d,
		center.Y,
		center.Z + math.sin(Market.BANK_ANGLE) * d
	)
end

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

	-- PROPORÇÃO. A versão anterior tinha 7,3 studs de altura, tronco de 2,5 de
	-- largura e um capuz de 1,75 por cima de uma cabeça de 1,35 — o capuz
	-- ENGOLIA a cabeça e o conjunto virava um bloco marrom sem silhueta. Aqui a
	-- proporção segue o boneco R6, que é a silhueta humana que todo jogador de
	-- Roblox já reconhece de longe: ~5,4 studs, ombro estreito, cabeça separada.
	local skin = Color3.fromRGB(214, 178, 146)
	local dark = Color3.fromRGB(46, 40, 36)

	-- pernas
	piece(Vector3.new(0.95, 2.0, 0.95), CFrame.new(-0.52, 1.0, 0), dark, Enum.Material.Fabric)
	piece(Vector3.new(0.95, 2.0, 0.95), CFrame.new(0.52, 1.0, 0), dark, Enum.Material.Fabric)

	-- tronco: 1,9 de largura (não 2,5). Ombro estreito é o que dá leitura de
	-- pessoa; largo demais lê como caixa.
	local torso = piece(Vector3.new(1.9, 2.0, 1.0), CFrame.new(0, 3.0, 0), v.tunica, Enum.Material.Fabric)
	-- avental/faixa clara atravessando o peito: quebra o bloco de cor única e
	-- destaca o vendedor da madeira da barraca, que é do mesmo tom
	piece(Vector3.new(1.96, 0.7, 1.06), CFrame.new(0, 2.55, 0), Color3.fromRGB(198, 188, 168), Enum.Material.Fabric)
	piece(Vector3.new(1.96, 0.34, 1.06), CFrame.new(0, 3.7, 0), dark, Enum.Material.Fabric)

	-- braços, um pouco afastados do corpo pra silhueta não fundir
	for _, sx in { -1, 1 } do
		piece(Vector3.new(0.72, 1.9, 0.72), CFrame.new(sx * 1.36, 3.0, 0), v.tunica, Enum.Material.Fabric)
		piece(Vector3.new(0.66, 0.5, 0.66), CFrame.new(sx * 1.36, 1.9, 0), skin, Enum.Material.Plastic)
	end

	-- pescoço + cabeça SEPARADA do tronco (o vão é o que faz ler cabeça)
	piece(Vector3.new(0.6, 0.4, 0.6), CFrame.new(0, 4.2, 0), skin, Enum.Material.Plastic)
	piece(Vector3.new(1.15, 1.15, 1.15), CFrame.new(0, 5.0, 0), skin, Enum.Material.Plastic)
	-- capuz caído nas COSTAS, não sobre a cabeça
	piece(Vector3.new(1.3, 1.0, 0.55), CFrame.new(0, 4.5, -0.62), v.tunica, Enum.Material.Fabric)
	-- gorro raso: cobre o topo sem apagar o rosto
	piece(Vector3.new(1.25, 0.42, 1.25), CFrame.new(0, 5.62, 0), v.tunica, Enum.Material.Fabric)

	model.PrimaryPart = torso

	-- placa com nome e ofício, pra achar o vendedor certo de longe
	local tag = Instance.new("BillboardGui")
	tag.Name = "Placa"
	tag.Size = UDim2.new(0, 210, 0, 42)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
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
	local PITCH = math.rad(26)
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
	-- Postes mais altos e cumeeira mais alta. Antes o beiral do toldo caía a 4
	-- studs do chão — ABAIXO da cabeça do vendedor —, então de frente só se via
	-- lona: a barraca virava uma tampa listrada sobre caixas. Agora o beiral fica
	-- a ~7,5 studs e dá pra ver quem está atrás do balcão.
	local POST_H = 9.5
	local RIDGE_UP = 2.8
	local SLOPE = 6.4

	-- 4 postes de canto
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = (cf * CFrame.new(sx * (W / 2 - 0.6), 0, sz * (D / 2 - 0.6))).Position
			Build.post(p, POST_H, 0.62, C.TIMBER, Enum.Material.Wood)
		end
	end

	stripedAwning(cf * CFrame.new(0, POST_H + RIDGE_UP, 0), W, SLOPE, v.corA, v.corB)

	-- BALCÃO na frente (+Z), com tampo saliente e painel fechando embaixo
	Build.part({
		Size = Vector3.new(W - 1.4, 0.5, 3.0),
		CFrame = cf * CFrame.new(0, 3.4, D / 2 - 1.6),
		Color = C.WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	Build.part({
		Size = Vector3.new(W - 2.2, 3.1, 0.5),
		CFrame = cf * CFrame.new(0, 1.75, D / 2 - 0.4),
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
				CFrame = cf * CFrame.new(i * 2.8, 3.9, D / 2 - 1.6) * CFrame.Angles(0, math.random() * 2, 0),
				Color = Build.tint(C.WOOD, 0.1),
				Material = Enum.Material.WoodPlanks,
				CanCollide = false,
			})
		end
	end

	-- placa do ofício, pendurada na frente do toldo
	local sign = Build.part({
		Size = Vector3.new(7.5, 1.9, 0.3),
		CFrame = cf * CFrame.new(0, POST_H + 1.0, D / 2 - 0.2),
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
	Build.paintGround(pos.X, pos.Z, 17, Enum.Material.Cobblestone)
	Build.paintGround(pos.X + 6, pos.Z - 4, 11, Enum.Material.Cobblestone)
	Build.paintGround(pos.X - 5, pos.Z + 6, 10, Enum.Material.Cobblestone)

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
	Build.fire(pos + Vector3.new(0, 5.2, 0), 1.5, 22)
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

-- Repavimenta a praça. Chamado no FIM da construção da cidade.
-- Nenhuma ordem de chamadas garante que a neve não invada: Build.drift testa se
-- há neve no CENTRO da bola, mas a bola tem raio, então um monte que nasce
-- legitimamente fora do perímetro ainda transborda pra dentro. Em vez de tentar
-- prever cada caso, a invariante é imposta no fim: praça é pedra plana, ponto.
function Market.repave(center: Vector3, radius: number)
	-- +5 de folga porque o voxel tem 4 studs: um cilindro de raio 52 sai
	-- SERRILHADO, e sobrava neve nos entalhes da borda (medido: 34 de 432
	-- amostras). A folga cobre a quantização sem mover o limite visual, que
	-- quem desenha é a neve encostada por fora.
	Build.paintDisc(center.X, center.Z, radius + 5, Enum.Material.Cobblestone)
end

-- =================================================================== PRAÇA
function Market.build(center: Vector3, radius: number)
	-- CHÃO DA PRAÇA.
	--
	-- UM disco sólido, de uma vez. Antes eram dezenas de quadrados sorteados e
	-- sobrepostos, e entre eles sempre sobrava vão — era nos vãos que a neve e a
	-- terra ficavam dentro da praça. Aqui dentro do perímetro não existe neve
	-- nem terra batida: só calçamento, perfeitamente nivelado.
	Build.paintDisc(center.X, center.Z, radius, Enum.Material.Cobblestone)

	-- A neve volta a existir SÓ FORA do perímetro, encostada na borda. É ela que
	-- desenha o limite da praça — não uma aresta de geometria.
	-- A distância mínima leva em conta o RAIO DA BOLA, não só o centro dela: um
	-- monte centrado a 3 studs da borda com bola de 5 ainda invade 2 studs de
	-- praça. Medido: com radius+3 sobravam 7 amostras de neve dentro do
	-- perímetro e 1,5 stud de desnível.
	for i = 1, 46 do
		local a = (i / 46) * math.pi * 2 + math.random() * 0.1
		local r = radius + 9 + math.random() * 10
		Build.drift(center + Vector3.new(math.cos(a) * r, 2, math.sin(a) * r), 2.4, 4.4)
	end

	-- MONUMENTO central: pedra de juramento com runa. Dá um ponto focal e um
	-- lugar natural pra jogador ficar parado esperando amigo.
	local gy = Build.groundY(center.X, center.Z, 2)
	center = Vector3.new(center.X, gy, center.Z)
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
		local bx, bz = center.X + math.cos(a) * 22, center.Z + math.sin(a) * 22
		brazier(Vector3.new(bx, Build.groundY(bx, bz, 2), bz))
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

	-- ALTURA REAL DO CHÃO. Tudo aqui era construído assumindo y=0, mas a
	-- superfície do terreno fica em y≈2: a praça inteira nascia DOIS STUDS
	-- ENTERRADA. É por isso que o toldo parecia baixo demais e o vendedor
	-- sumia atrás do balcão.
	for i, v in VENDORS do
		local a = math.rad(STALL_ANGLES[i] or (i * 60))
		local px, pz = center.X + math.cos(a) * ringR, center.Z + math.sin(a) * ringR
		local p = Vector3.new(px, Build.groundY(px, pz, 2), pz)
		-- a frente da barraca (+Z local) tem que olhar pro centro
		stall(CFrame.lookAt(p, Vector3.new(center.X, p.Y, center.Z)), v)
	end

	for _, deg in LAMP_ANGLES do
		local a = math.rad(deg)
		local lx, lz = center.X + math.cos(a) * ringR, center.Z + math.sin(a) * ringR
		local lp = Vector3.new(lx, Build.groundY(lx, lz, 2), lz)
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
	local ba = Market.BANK_ANGLE
	local bc = Market.bankCenter(center, radius)
	local bp = Vector3.new(bc.X, Build.groundY(bc.X, bc.Z, 2), bc.Z)
	bank(CFrame.lookAt(bp, Vector3.new(center.X, bp.Y, center.Z)))
end

return Market
