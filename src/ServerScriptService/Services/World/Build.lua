--!strict
-- Build.lua  (SERVIDOR)
-- Primitivas de construção + paleta. Todo módulo do mundo usa isto.
-- Referências: Whiterun (Skyrim), muralha de Attack on Titan, vilarejos de
-- Vinland Saga e cidades costeiras da Islândia.

local Build = {}

-- ---------------- PALETA ----------------
-- Ambiente frio e dessaturado; saturação só onde há informação
-- (janela acesa = vida, runa = anomalia).
Build.C = {
	STONE = Color3.fromRGB(122, 116, 106),      -- pedra da muralha/alicerce
	STONE_DARK = Color3.fromRGB(88, 85, 78),
	STONE_LIGHT = Color3.fromRGB(150, 144, 132),
	PLASTER = Color3.fromRGB(201, 192, 172),    -- reboco claro do enxaimel
	PLASTER_2 = Color3.fromRGB(186, 174, 154),
	TIMBER = Color3.fromRGB(74, 58, 42),        -- vigas escuras
	WOOD = Color3.fromRGB(107, 82, 56),
	WOOD_DARK = Color3.fromRGB(70, 54, 38),
	ROOF_TILE = Color3.fromRGB(122, 68, 54),    -- telha de barro (ref. AoT)
	ROOF_SHINGLE = Color3.fromRGB(78, 66, 54),  -- madeira/ardósia (ref. Skyrim)
	THATCH = Color3.fromRGB(138, 116, 72),      -- palha
	SNOW = Color3.fromRGB(232, 236, 239),
	COBBLE = Color3.fromRGB(110, 106, 99),      -- rua de pedra
	DIRT = Color3.fromRGB(107, 92, 72),
	WINDOW = Color3.fromRGB(255, 190, 110),     -- luz quente de dentro
	FIRE = Color3.fromRGB(255, 152, 66),
	RUNE = Color3.fromRGB(150, 224, 255),       -- a anomalia
	BANNER = Color3.fromRGB(122, 52, 48),
	BANNER_2 = Color3.fromRGB(58, 78, 106),
}

local root: Instance? = nil
local warnedNoRoot = false

-- ORIGEM. Tudo que passa por Build.part nasce transformado por isto. É o que
-- permite erguer a MESMA cidade em outro canto do mapa, com outra rotação, sem
-- tocar numa linha de Town.lua nem de Walls.lua: a segunda cidade é configuração,
-- não cópia. Identidade = comportamento antigo, então nada muda por padrão.
local origin: CFrame = CFrame.identity

function Build.setRoot(r: Instance)
	root = r
end

function Build.setOrigin(cf: CFrame)
	origin = cf
end

function Build.getOrigin(): CFrame
	return origin
end

-- ponto do mundo a partir de uma coordenada local da cidade
function Build.toWorld(v: Vector3): Vector3
	return origin * v
end

-- Se a raiz não foi definida, as peças nasceriam SEM PAI: invisíveis e sem erro
-- nenhum. Cair pro workspace evita o mundo inteiro sumir em silêncio.
function Build.getRoot(): Instance
	if root then
		return root
	end
	if not warnedNoRoot then
		warnedNoRoot = true
		warn("[Build] raiz não definida — usando workspace (chame Build.setRoot antes)")
	end
	return workspace
end

-- peça padrão (ancorada, sem superfície feia)
function Build.part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.Slate
	p.Color = Build.C.STONE
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	-- a origem entra DEPOIS das props: quem chama continua pensando em
	-- coordenadas locais da cidade e não precisa saber onde ela foi parar
	if origin ~= CFrame.identity then
		p.CFrame = origin * p.CFrame
	end
	p.Parent = (props :: any).Parent or Build.getRoot()
	return p
end

function Build.wedge(props): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Material = Enum.Material.WoodPlanks
	p.Color = Build.C.ROOF_SHINGLE
	for k, v in props do
		(p :: any)[k] = v
	end
	if origin ~= CFrame.identity then
		p.CFrame = origin * p.CFrame
	end
	p.Parent = (props :: any).Parent or Build.getRoot()
	return p
end

-- cilindro deitado/em pé (tronco, poste, barril)
function Build.cyl(cf: CFrame, length: number, diameter: number, color: Color3, material: Enum.Material): Part
	return Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material,
	})
end

-- poste vertical (converte pra cilindro em pé automaticamente)
function Build.post(pos: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material): Part
	return Build.cyl(
		CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		height,
		diameter,
		color,
		material
	)
end

-- variação sutil de cor: nada no mundo real tem duas paredes idênticas.
-- É um dos truques que mais tira a "cara de Roblox".
function Build.tint(c: Color3, amount: number): Color3
	local j = (math.random() - 0.5) * 2 * amount
	local k = (math.random() - 0.5) * amount
	return Color3.new(
		math.clamp(c.R + j, 0, 1),
		math.clamp(c.G + j + k * 0.3, 0, 1),
		math.clamp(c.B + j - k * 0.3, 0, 1)
	)
end

-- neve acumulada sobre uma superfície (realismo barato num mapa nevado)
function Build.snow(cf: CFrame, size: Vector3)
	Build.part({
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(238, 242, 245),
		Material = Enum.Material.Snow,
		CanCollide = false,
		CastShadow = false,
	})
end

-- ALTURA DO CHÃO em (x, z).
-- Ninguém deve chutar "y = 0". A superfície do terreno nevado fica em y≈2 por
-- causa do voxel de 4 studs, e o mapa ainda tem ondulação. Decoração colocada em
-- y=0,3 ficava ENTERRADA — foi por isso que calçamento e montinhos de neve
-- simplesmente não apareciam. Só olha pro Terrain, senão uma peça recém-criada
-- ao lado (parede, barril) rouba o raycast.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }
groundParams.IgnoreWater = true

local function groundHit(x: number, z: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, 220, z), Vector3.new(0, -400, 0), groundParams)
end

function Build.groundY(x: number, z: number, fallback: number?): number
	local hit = groundHit(x, z)
	return hit and hit.Position.Y or (fallback or 0)
end

-- O chão neste ponto ainda é neve intocada?
-- Esta é a regra que faltava: neve só acumula ONDE JÁ HÁ NEVE. Onde o chão foi
-- batido — rua, praça, volta do braseiro — não pode nascer monte, senão a terra
-- fica ondulada e a estrada perde justamente a leitura de "aqui passa gente".
function Build.isSnowAt(x: number, z: number): boolean
	local hit = groundHit(x, z)
	return hit ~= nil and hit.Material == Enum.Material.Snow
end

-- PINTAR O CHÃO (tirar a neve de onde passa gente).
--
-- FillBlock é a ferramenta ERRADA pra isto e custou caro descobrir: ele preenche
-- VOLUME. A superfície da neve não está em y=0 — está em y≈2, porque o voxel de
-- terreno tem 4 studs e a isosuperfície cai no meio dele. Então preencher com
-- Ground de -3,2 até 0 pintava só o que estava ENTERRADO: da superfície pra cima
-- continuava neve, e nenhuma estrada aparecia. Subir o topo do preenchimento
-- resolvia o material mas LEVANTAVA o terreno num degrau de 1 stud.
--
-- ReplaceMaterial troca só o MATERIAL dentro da região e preserva a ocupação,
-- que é exatamente o que "aqui a neve não fica porque passa cavalo" precisa.
-- Nível do chão da planície. Terra.lua preenche a neve com o topo em 0, e a
-- isosuperfície do voxel renderiza isso em y≈2. Tudo que "normaliza o chão"
-- tem que mirar exatamente neste valor, senão vira degrau.
local GROUND_TOP = 0

function Build.paintGround(cx: number, cz: number, size: number, material: Enum.Material?)
	local mat = material or Enum.Material.Ground

	-- 1) NIVELA. Isto é o que faltava: trocar só o material deixava o morro de
	--    neve que já estava ali, agora vestido de terra — e o calçamento plano
	--    ficava espetado no morro. Onde não há neve, o chão volta ao nível.
	--    Limpa tudo acima do nível...
	workspace.Terrain:FillBlock(
		CFrame.new(cx, GROUND_TOP + 24, cz),
		Vector3.new(size, 48, size),
		Enum.Material.Air
	)
	--    ...e preenche sólido até ele.
	workspace.Terrain:FillBlock(
		CFrame.new(cx, GROUND_TOP - 9, cz),
		Vector3.new(size, 18, size),
		mat
	)

	-- NÃO existe passo 2.
	--
	-- Havia aqui um ReplaceMaterial numa região maior que o bloco, "pra suavizar
	-- a transição". Ele trocava o MATERIAL da neve vizinha por pedra SEM mexer na
	-- altura — ou seja, o monte de neve continuava lá, com o formato dele, só que
	-- agora vestido de calçamento. O resultado é pedra ondulada seguindo o
	-- contorno da neve: ninguém assenta paralelepípedo em cima de um monte.
	--
	-- Pedra é o que foi NIVELADO, e só. O que está fora continua neve, com a
	-- forma irregular que a neve tem — e é a neve que cai por cima da pedra na
	-- borda, nunca o contrário.
end

-- NEVE DE TELHADO.
-- Uma laje branca retangular com as quatro arestas retas é a coisa que mais
-- entrega "Roblox" num telhado. Neve de verdade acumula da cumeeira pra baixo e
-- derrete numa linha IRREGULAR: mais grossa em cima, mais fina embaixo, com
-- pedaços faltando onde bateu sol ou saiu fumaça da chaminé.
--
-- rcf       = CFrame da água do telhado (X = descida, Y = normal, Z = cumeeira)
-- slopeLen  = comprimento da descida
-- depth     = comprimento ao longo da cumeeira
-- dir       = +1/-1: de que lado da cumeeira esta água está
function Build.roofSnow(rcf: CFrame, slopeLen: number, depth: number, dir: number)
	-- Faixas ESTREITAS: quanto mais estreita, mais a linha de degelo serrilha.
	local strips = math.max(5, math.floor(depth / 2.2))
	local stripD = depth / strips

	-- A cobertura passeia por uma ONDA LENTA em vez de ser sorteada faixa a
	-- faixa. Sorteio independente produz um pente regular — parece dente de
	-- serra, não neve. Onda + ruído fino dá manchas contínuas de bordas rasgadas,
	-- que é como neve realmente derrete num telhado: em placas, não em listras.
	local phase = math.random() * 6.28
	local bias = 0.30 + math.random() * 0.16

	for i = 0, strips - 1 do
		local u = i / strips
		local wave = math.sin(u * 6.5 + phase) * 0.22 + math.sin(u * 13.0 + phase * 2.1) * 0.10
		local cover = bias + wave + (math.random() - 0.5) * 0.09
		-- abaixo disso a placa simplesmente não existe: buraco na cobertura
		if cover > 0.11 then
			cover = math.min(cover, 0.80)
			local len = slopeLen * cover
			local thick = 0.36 - cover * 0.26 -- grossa na cumeeira, fina na beira
			Build.part({
				Size = Vector3.new(len, thick, stripD * 1.02),
				CFrame = rcf * CFrame.new(
					-dir * (slopeLen / 2 - len / 2),
					0.72 + thick / 2, -- acima das fiadas de telha
					-depth / 2 + stripD * (i + 0.5)
				),
				Color = Color3.fromRGB(235, 240, 244),
				Material = Enum.Material.Snow,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
end

-- DISCO DE CHÃO PLANO.
--
-- Pintar uma praça com vários quadrados sorteados e sobrepostos SEMPRE deixa
-- vãos entre eles, e é justamente nos vãos que sobra neve e terra. Praça de
-- pedra é uma superfície só: um cilindro sólido, de uma vez, perfeitamente
-- nivelado. Dentro do perímetro não existe neve nem terra — só o calçamento.
function Build.paintDisc(cx: number, cz: number, radius: number, material: Enum.Material?)
	local mat = material or Enum.Material.Cobblestone
	-- limpa TUDO acima do nível do chão (monte de neve, terra empilhada, o que for)
	workspace.Terrain:FillCylinder(
		CFrame.new(cx, GROUND_TOP + 26, cz),
		52,
		radius,
		Enum.Material.Air
	)
	-- e preenche sólido até exatamente o nível
	workspace.Terrain:FillCylinder(
		CFrame.new(cx, GROUND_TOP - 10, cz),
		20,
		radius,
		mat
	)
end

-- MONTE DE NEVE.
--
-- Isto era feito com PEÇAS e o resultado eram caixas brancas retangulares
-- espalhadas pelo chão como isopor — de longe a pior coisa do mapa. Neve não
-- tem aresta viva, e nenhuma quantidade de sorteio de tamanho conserta um
-- retângulo.
--
-- O motor já resolve isso: o terreno voxel suaviza a superfície e FUNDE volumes
-- vizinhos automaticamente, então bolas de neve sobrepostas viram um banco
-- contínuo e macio, com a textura de neve de verdade e sombreamento próprio.
-- Banco de neve é TERRENO, não Part. De quebra some com ~1.700 peças do mapa.
function Build.drift(pos: Vector3, spread: number, size: number)
	for _ = 1, 3 do
		local a = math.random() * math.pi * 2
		local r = math.random() * spread
		local x, z = pos.X + math.cos(a) * r, pos.Z + math.sin(a) * r
		local rad = size * (0.6 + math.random() * 0.55)

		-- A PEGADA INTEIRA tem que estar em neve, não só o centro.
		-- Testar só o centro era o bug: uma bola nascia legitimamente na neve ao
		-- lado da rua e TRANSBORDAVA por cima da pedra, misturando os dois
		-- terrenos e levantando o calçamento. Neve, terra e pedra são três
		-- superfícies distintas — nenhuma invade a outra.
		-- O MIOLO da bola tem que estar em neve; a beirada dela PODE encostar na
		-- pedra, porque é assim que fica certo: a neve cai por cima do
		-- calçamento na borda. O que não pode é o monte nascer sobre a rua e
		-- levantar a pedra — por isso o teste é a 45% do raio, não no raio todo.
		local core = rad * 0.45
		local footprintClear = Build.isSnowAt(x, z)
		if footprintClear then
			for k = 0, 3 do
				local ang = k * math.pi / 2
				if not Build.isSnowAt(x + math.cos(ang) * core, z + math.sin(ang) * core) then
					footprintClear = false
					break
				end
			end
		end
		if not footprintClear then
			continue
		end
		-- TRAVA DE ACÚMULO. groundY mede o terreno, e o terreno já inclui a neve
		-- que acabamos de colocar: sem teto, cada monte se apoia no anterior e a
		-- neve cresce sem fim até virar um paredão branco. O teto é relativo à
		-- altura que o chamador pediu, não absoluto, pra continuar funcionando
		-- em encosta.
		local y = math.min(Build.groundY(x, z, pos.Y), pos.Y + 1.3)
		-- quanto o monte sobe acima do chão: raso, senão vira parede de neve
		local rise = size * (0.16 + math.random() * 0.18)
		workspace.Terrain:FillBall(Vector3.new(x, y - rad + rise, z), rad, Enum.Material.Snow)
	end
end

-- janela: VIDRO (não neon puro). O erro anterior era um retângulo neon 100%
-- opaco e enorme — é o que dava aquele brilho chapado de Roblox.
function Build.window(cf: CFrame, w: number, h: number, lit: boolean?)
	-- painel de vidro com tom quente e reflexo
	Build.part({
		Size = Vector3.new(w, h, 0.2),
		CFrame = cf,
		Color = lit and Color3.fromRGB(196, 146, 88) or Color3.fromRGB(84, 92, 100),
		Material = Enum.Material.Glass,
		Transparency = lit and 0.3 or 0.5,
		Reflectance = 0.14,
		CanCollide = false,
		CastShadow = false,
	})
	-- Brilho interno. A 0,52 de transparência o Neon estourava com o bloom e a
	-- janela virava um RETÂNGULO AMARELO CHAPADO — uma das coisas que mais
	-- entregam "Roblox" numa fachada à noite. O que vende luz de dentro não é o
	-- painel brilhante: é o vidro âmbar mais a luz caindo na parede em volta.
	if lit then
		Build.part({
			Size = Vector3.new(w * 0.7, h * 0.7, 0.1),
			CFrame = cf * CFrame.new(0, 0, -0.16),
			Color = Color3.fromRGB(255, 206, 150),
			Material = Enum.Material.Neon,
			Transparency = 0.74,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- caixilho: 4 lados (não um bloco atrás)
	local t = 0.34
	for _, o in
		{
			{ Vector3.new(w + t * 2, t, 0.42), Vector3.new(0, h / 2 + t / 2, 0.08) },
			{ Vector3.new(w + t * 2, t, 0.42), Vector3.new(0, -h / 2 - t / 2, 0.08) },
			{ Vector3.new(t, h, 0.42), Vector3.new(-w / 2 - t / 2, 0, 0.08) },
			{ Vector3.new(t, h, 0.42), Vector3.new(w / 2 + t / 2, 0, 0.08) },
		}
	do
		Build.part({
			Size = o[1],
			CFrame = cf * CFrame.new(o[2]),
			Color = Build.C.TIMBER,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- cruzeta central
	Build.part({
		Size = Vector3.new(0.18, h, 0.4),
		CFrame = cf * CFrame.new(0, 0, 0.08),
		Color = Build.C.TIMBER,
		Material = Enum.Material.Wood,
		CanCollide = false,
		CastShadow = false,
	})
	Build.part({
		Size = Vector3.new(w, 0.18, 0.4),
		CFrame = cf * CFrame.new(0, 0, 0.08),
		Color = Build.C.TIMBER,
		Material = Enum.Material.Wood,
		CanCollide = false,
		CastShadow = false,
	})
	-- peitoril
	Build.part({
		Size = Vector3.new(w + 1.2, 0.3, 0.9),
		CFrame = cf * CFrame.new(0, -h / 2 - 0.45, 0.25),
		Color = Build.C.STONE_LIGHT,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
		CastShadow = false,
	})
end

-- FOGO.
-- Uma esfera de Neon é uma BOLA DE PLÁSTICO ACESA: não tem movimento, não tem
-- borda quente, e o brilho do Neon a infla na tela até virar um disco amarelo
-- chapado. Fogo se lê por MOVIMENTO e por gradiente de cor — do branco-quente
-- no núcleo ao laranja escuro na ponta. Um emissor resolve os dois, e o núcleo
-- de Neon vira só a brasa no meio.
function Build.fire(at: Vector3, scale: number, lightRange: number?): Part
	local core = Build.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.9, 0.9, 0.9) * scale,
		CFrame = CFrame.new(at),
		Color = Color3.fromRGB(255, 176, 92),
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
		CastShadow = false,
	})

	local fx = Instance.new("ParticleEmitter")
	fx.Name = "Chama"
	fx.Rate = 16
	fx.Lifetime = NumberRange.new(0.45, 0.85)
	fx.Speed = NumberRange.new(1.6 * scale, 3.2 * scale)
	fx.SpreadAngle = Vector2.new(14, 14)
	fx.Acceleration = Vector3.new(0, 5 * scale, 0)
	fx.LightEmission = 0.85
	fx.LightInfluence = 0
	fx.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5 * scale),
		NumberSequenceKeypoint.new(0.45, 1.1 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	fx.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- branco-quente no nascimento, laranja no meio, vermelho escuro ao apagar
	fx.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 190)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 152, 56)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 44, 20)),
	})
	fx.Parent = core

	if lightRange then
		Build.light(core, Color3.fromRGB(255, 170, 96), 0.6, lightRange)
	end
	return core
end

-- luz pontual barata (usar com moderação: luz custa performance)
function Build.light(parent: BasePart, color: Color3, brightness: number, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

-- barril / caixa: props que dão vida às ruas (ref. Riverwood)
function Build.barrel(pos: Vector3)
	Build.post(pos, 3, 2.2, Build.C.WOOD, Enum.Material.Wood)
	Build.part({
		Size = Vector3.new(2.35, 0.3, 2.35),
		CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)),
		Color = Build.C.WOOD_DARK,
		Material = Enum.Material.Wood,
		CanCollide = false,
	})
end

function Build.crate(pos: Vector3, size: number)
	Build.part({
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(pos + Vector3.new(0, size / 2, 0))
			* CFrame.Angles(0, math.random() * 6, 0),
		Color = Build.C.WOOD,
		Material = Enum.Material.WoodPlanks,
	})
end

-- estandarte pendurado (ref. Solitude)
-- aceita CFrame ou Vector3: passar posição crua aqui já derrubou a construção
-- inteira do Salão do Jarl uma vez ("CoordinateFrame expected, got Vector3")
function Build.banner(at: CFrame | Vector3, h: number, color: Color3)
	local cf = if typeof(at) == "Vector3" then CFrame.new(at) else at :: CFrame
	Build.part({
		Size = Vector3.new(2.6, h, 0.2),
		CFrame = cf,
		Color = color,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CastShadow = false,
	})
end

-- lanterna de rua: poste de ferro, braço curvo e gaiola com chama
function Build.lantern(pos: Vector3, withLight: boolean?)
	Build.post(pos, 8, 0.45, Build.C.TIMBER, Enum.Material.Metal)
	-- braço que projeta a lanterna pro lado
	Build.part({
		Size = Vector3.new(2.4, 0.3, 0.3),
		CFrame = CFrame.new(pos + Vector3.new(1.1, 7.9, 0)),
		Color = Build.C.TIMBER,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CastShadow = false,
	})
	local cx = pos + Vector3.new(2.1, 7.1, 0)
	-- gaiola: 4 montantes + tampa
	for _, o in { Vector3.new(-0.5, 0, -0.5), Vector3.new(0.5, 0, -0.5), Vector3.new(-0.5, 0, 0.5), Vector3.new(0.5, 0, 0.5) } do
		Build.part({
			Size = Vector3.new(0.16, 1.5, 0.16),
			CFrame = CFrame.new(cx + o),
			Color = Build.C.TIMBER,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CastShadow = false,
		})
	end
	Build.part({ -- telhadinho
		Size = Vector3.new(1.5, 0.35, 1.5),
		CFrame = CFrame.new(cx + Vector3.new(0, 0.9, 0)),
		Color = Build.C.TIMBER,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CastShadow = false,
	})
	Build.fire(cx, 0.55, 15)
end

return Build
