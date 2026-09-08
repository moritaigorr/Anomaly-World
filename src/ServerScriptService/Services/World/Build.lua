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

function Build.setRoot(r: Instance)
	root = r
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
	-- brilho interno DISCRETO (translúcido, atrás do vidro)
	if lit then
		Build.part({
			Size = Vector3.new(w * 0.82, h * 0.82, 0.1),
			CFrame = cf * CFrame.new(0, 0, -0.16),
			Color = Color3.fromRGB(255, 198, 132),
			Material = Enum.Material.Neon,
			Transparency = 0.52,
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
	local flame = Build.part({ -- chama pequena dentro da gaiola
		Size = Vector3.new(0.7, 0.9, 0.7),
		CFrame = CFrame.new(cx),
		Color = Build.C.FIRE,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	if withLight then
		Build.light(flame, Build.C.FIRE, 1.4, 26)
	end
end

return Build
