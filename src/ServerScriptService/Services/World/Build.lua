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

function Build.groundY(x: number, z: number, fallback: number?): number
	local hit = workspace:Raycast(Vector3.new(x, 220, z), Vector3.new(0, -400, 0), groundParams)
	return hit and hit.Position.Y or (fallback or 0)
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
function Build.paintGround(cx: number, cz: number, size: number, material: Enum.Material?)
	local half = size / 2
	local region = Region3.new(
		Vector3.new(cx - half, -10, cz - half),
		Vector3.new(cx + half, 12, cz + half)
	):ExpandToGrid(4)
	workspace.Terrain:ReplaceMaterial(region, 4, Enum.Material.Snow, material or Enum.Material.Ground)
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

-- MONTE DE NEVE encostado numa construção ou numa quina.
-- Sem isto, parede e chão se encontram numa linha reta e dura e as duas parecem
-- objetos empilhados. Neve acumulada no pé é o que amarra construção e terreno.
function Build.drift(pos: Vector3, spread: number, size: number)
	for _ = 1, 3 do
		local a = math.random() * math.pi * 2
		local r = math.random() * spread
		local x, z = pos.X + math.cos(a) * r, pos.Z + math.sin(a) * r
		local sx = size * (0.7 + math.random() * 0.8)
		local h = size * (0.32 + math.random() * 0.3)
		-- assenta no chão de verdade: monte de neve enterrado não existe
		local y = Build.groundY(x, z, pos.Y)
		Build.part({
			Size = Vector3.new(sx, h, sx * (0.6 + math.random() * 0.7)),
			CFrame = CFrame.new(x, y + h * 0.22, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
			Color = Color3.fromRGB(237, 241, 245),
			Material = Enum.Material.Snow,
			CanCollide = false,
			CastShadow = false,
		})
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
	-- CHAMA. Era um CUBO de Neon opaco: com bloom em cima, virava um retângulo
	-- amarelo chapado flutuando na rua — a leitura mais "Roblox" que existe numa
	-- luz. Esfera + transparência lê como brilho; a luz de verdade quem faz é o
	-- PointLight, não o tamanho do bloco aceso.
	local flame = Build.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.55, 0.55, 0.55),
		CFrame = CFrame.new(cx),
		Color = Build.C.FIRE,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CastShadow = false,
	})
	if withLight then
		Build.light(flame, Build.C.FIRE, 1.4, 26)
	end
end

return Build
