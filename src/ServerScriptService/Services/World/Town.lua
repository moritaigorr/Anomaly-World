--!strict
-- Town.lua  (SERVIDOR)
-- A cidade: casas enxaimel, ruas de pedra, mercado, arcos com estandartes e o
-- Salão do Jarl. Estrutura tirada de Whiterun; arquitetura das referências de
-- Attack on Titan (telhado de telha, fileiras densas) e Riverwood/Solitude.
--
-- NOTA DE GEOMETRIA: o telhado é feito de DUAS LAJES INCLINADAS (rotação simples
-- no eixo Z) formando o "A", e a empena é escalonada. WedgePart com rotação dupla
-- é imprevisível de orientação — foi o que quebrou a versão anterior.

local Build = require(script.Parent.Build)
local C = Build.C

local Town = {}

Town.GATE_Z = -160
Town.KEEP_Z = 70
Town.MAIN_ROAD_W = 22

-- ================================================================= CASA
-- Encara +Z. w = largura (X), d = profundidade (Z).
local function house(pos: Vector3, w: number, d: number, floors: number, ang: number, roofTile: boolean)
	local base = CFrame.new(pos) * CFrame.Angles(0, ang, 0)
	local GF = 6.0 -- pé-direito do térreo (pedra)
	local UF = 5.4 -- pé-direito dos andares de cima

	-- cada casa tem sua própria variação de cor: casas idênticas em série é o
	-- que mais denuncia geometria gerada por código
	local plasterCol = Build.tint((math.random() < 0.5) and C.PLASTER or C.PLASTER_2, 0.055)
	local roofCol = Build.tint(roofTile and C.ROOF_TILE or C.ROOF_SHINGLE, 0.05)
	local stoneCol = Build.tint(C.STONE, 0.045)

	-- ---------------- térreo: embasamento de pedra ----------------
	Build.part({
		Size = Vector3.new(w, GF, d),
		CFrame = base * CFrame.new(0, GF / 2, 0),
		Color = stoneCol,
		Material = Enum.Material.Cobblestone,
	})
	-- soco (faixa saliente na base) — dá "peso" à construção
	Build.part({
		Size = Vector3.new(w + 0.7, 0.9, d + 0.7),
		CFrame = base * CFrame.new(0, 0.45, 0),
		Color = C.STONE_DARK,
		Material = Enum.Material.Cobblestone,
	})

	-- SUJEIRA acumulada na base da parede. Parede que tem exatamente a mesma cor
	-- do topo até o chão é uma das coisas que mais denunciam geometria de código:
	-- no mundo real a base é sempre mais escura (respingo, musgo, umidade).
	Build.part({
		Size = Vector3.new(w + 0.12, 2.2, d + 0.12),
		CFrame = base * CFrame.new(0, 1.6, 0),
		Color = stoneCol:Lerp(Color3.fromRGB(38, 36, 30), 0.42),
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	})

	-- cornija separando pedra e reboco (quebra a leitura de "bloco único")
	if floors > 1 then
		Build.part({
			Size = Vector3.new(w + 1.1, 0.5, d + 1.1),
			CFrame = base * CFrame.new(0, GF - 0.25, 0),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- ---------------- andares superiores: enxaimel ----------------
	local topY = GF
	local ww, dd = w, d
	for f = 1, floors - 1 do
		ww = w + 1.4 * f -- jetty: cada andar avança sobre o de baixo
		dd = d + 1.4 * f
		local y0 = GF + UF * (f - 1)

		-- viga de apoio do balanço
		Build.part({
			Size = Vector3.new(ww, 0.7, dd),
			CFrame = base * CFrame.new(0, y0 + 0.35, 0),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
		})
		-- parede de reboco
		Build.part({
			Size = Vector3.new(ww, UF, dd),
			CFrame = base * CFrame.new(0, y0 + UF / 2, 0),
			Color = plasterCol,
			Material = Enum.Material.Plaster,
		})

		-- estrutura de madeira aparente (o desenho do enxaimel)
		local yMid = y0 + UF / 2
		for _, face in { { dd / 2, 0 }, { -dd / 2, math.pi } } do
			local zz = face[1] :: number
			-- montantes verticais espaçados
			local studs = math.max(2, math.floor(ww / 3.2))
			for i = 0, studs do
				local x = -ww / 2 + (ww / studs) * i
				Build.part({
					Size = Vector3.new(0.5, UF, 0.28),
					CFrame = base * CFrame.new(x, yMid, zz),
					Color = C.TIMBER,
					Material = Enum.Material.Wood,
					CanCollide = false,
					CastShadow = false,
				})
			end
			-- travessas superior e inferior
			for _, yy in { y0 + 0.5, y0 + UF - 0.5 } do
				Build.part({
					Size = Vector3.new(ww, 0.55, 0.28),
					CFrame = base * CFrame.new(0, yy, zz),
					Color = C.TIMBER,
					Material = Enum.Material.Wood,
					CanCollide = false,
					CastShadow = false,
				})
			end
			-- duas diagonais simétricas dentro do vão (contida na largura)
			local segW = ww / 2 - 0.6
			local segH = UF - 1.6
			local len = math.sqrt(segW * segW + segH * segH)
			for _, s in { -1, 1 } do
				Build.part({
					Size = Vector3.new(len, 0.45, 0.26),
					CFrame = base
						* CFrame.new(s * ww / 4, yMid, zz)
						* CFrame.Angles(0, 0, s * math.atan2(segH, segW)),
					Color = C.TIMBER,
					Material = Enum.Material.Wood,
					CanCollide = false,
					CastShadow = false,
				})
			end
		end
		-- cantoneiras nas quinas
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Build.part({
					Size = Vector3.new(0.75, UF, 0.75),
					CFrame = base * CFrame.new(sx * (ww / 2 - 0.37), yMid, sz * (dd / 2 - 0.37)),
					Color = C.TIMBER,
					Material = Enum.Material.Wood,
				})
			end
		end
		topY = y0 + UF
	end

	-- ---------------- telhado ----------------
	local over = 1.8 -- beiral avançado (assinatura nórdica)
	local rw = ww + over * 2
	local rd = dd + over * 2
	local rh = ww * 0.78 -- MUITO íngreme
	local half = rw / 2
	local slope = math.sqrt(half * half + rh * rh)
	local pitch = math.atan2(rh, half)

	for _, s in { -1, 1 } do
		local rcf = base * CFrame.new(s * (rw / 4), topY + rh / 2, 0) * CFrame.Angles(0, 0, -s * pitch)
		Build.part({ -- laje inclinada: rotação SIMPLES no eixo Z
			Size = Vector3.new(slope, 0.75, rd),
			CFrame = rcf,
			Color = roofCol,
			Material = roofTile and Enum.Material.Slate or Enum.Material.WoodPlanks,
		})
		-- Neve só numa faixa fina junto à cumeeira. Telhado todo branco fazia a
		-- casa sumir contra o chão nevado — o telhado precisa CONTRASTAR.
		if math.random() < 0.6 then
			Build.snow(
				rcf * CFrame.new(-s * slope * 0.30, 0.5, 0),
				Vector3.new(slope * 0.34, 0.26, rd - 1.5)
			)
		end
	end
	-- cumeeira
	Build.part({
		Size = Vector3.new(1.3, 0.8, rd + 0.6),
		CFrame = base * CFrame.new(0, topY + rh + 0.1, 0),
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
		CastShadow = false,
	})
	-- tábuas de beiral (fascia) nas duas laterais
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(0.4, 0.9, rd),
			CFrame = base * CFrame.new(s * half, topY - 0.1, 0),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- ---------------- empena (fecha o triângulo da fachada) ----------------
	-- 16 degraus finos em vez de 6 grossos: de longe some a escadinha.
	local steps = 16
	for _, sz in { 1, -1 } do
		for i = 0, steps - 1 do
			local frac = (i + 0.5) / steps
			local y = topY + frac * rh
			local segW = ww * (1 - frac)
			Build.part({
				Size = Vector3.new(segW, rh / steps + 0.08, 0.6),
				CFrame = base * CFrame.new(0, y, sz * (dd / 2 - 0.2)),
				Color = plasterCol,
				Material = Enum.Material.Plaster,
				CastShadow = false,
			})
		end
		-- TÁBUAS DE EMPENA: acompanham a inclinação do telhado e escondem
		-- completamente o degrau. É o detalhe que faz a fachada "fechar".
		for _, s in { -1, 1 } do
			Build.part({
				Size = Vector3.new(slope, 0.8, 0.55),
				CFrame = base
					* CFrame.new(s * (rw / 4), topY + rh / 2, sz * (dd / 2 + 0.36))
					* CFrame.Angles(0, 0, -s * pitch),
				Color = C.TIMBER,
				Material = Enum.Material.Wood,
				CanCollide = false,
				CastShadow = false,
			})
		end
		-- viga vertical no centro da empena
		Build.part({
			Size = Vector3.new(0.5, rh * 0.85, 0.3),
			CFrame = base * CFrame.new(0, topY + rh * 0.42, sz * (dd / 2 + 0.15)),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- ---------------- porta ----------------
	local dz = d / 2
	Build.part({ -- vão escuro
		Size = Vector3.new(3.4, 5, 0.5),
		CFrame = base * CFrame.new(0, 2.5, dz + 0.1),
		Color = Color3.fromRGB(24, 20, 18),
		Material = Enum.Material.Wood,
	})
	Build.part({ -- porta
		Size = Vector3.new(3, 4.6, 0.35),
		CFrame = base * CFrame.new(0, 2.3, dz + 0.3),
		Color = C.WOOD_DARK,
		Material = Enum.Material.WoodPlanks,
	})
	for _, sx in { -1.7, 1.7 } do -- batentes
		Build.part({
			Size = Vector3.new(0.45, 5.4, 0.6),
			CFrame = base * CFrame.new(sx, 2.7, dz + 0.25),
			Color = C.TIMBER,
			Material = Enum.Material.Wood,
		})
	end
	Build.part({ -- verga
		Size = Vector3.new(4.2, 0.6, 0.7),
		CFrame = base * CFrame.new(0, 5.3, dz + 0.25),
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
	})
	Build.part({ -- degrau
		Size = Vector3.new(4, 0.5, 1.6),
		CFrame = base * CFrame.new(0, 0.25, dz + 1),
		Color = C.STONE_LIGHT,
		Material = Enum.Material.Cobblestone,
	})

	-- ---------------- janelas ----------------
	-- menores e nem todas acesas: uma cidade onde TUDO brilha parece cenário
	local litChance = 0.55
	for _, sx in { -1, 1 } do
		if w > 12 then
			Build.window(
				base * CFrame.new(sx * (w / 2 - 2.8), 3.5, dz + 0.15),
				1.5,
				1.8,
				math.random() < litChance
			)
		end
	end
	for f = 1, floors - 1 do
		local y0 = GF + UF * (f - 1)
		local W = w + 1.4 * f
		local D = d + 1.4 * f
		for _, sx in { -1, 1 } do
			Build.window(
				base * CFrame.new(sx * (W / 4), y0 + UF * 0.55, D / 2 + 0.15),
				1.5,
				1.9,
				math.random() < litChance
			)
		end
		if math.random() < 0.6 then
			Build.window(
				base * CFrame.new(W / 2 + 0.15, y0 + UF * 0.55, 0) * CFrame.Angles(0, math.rad(90), 0),
				1.5,
				1.9,
				math.random() < litChance
			)
		end
	end

	-- ---------------- mansarda (janela saindo do telhado) ----------------
	-- Quebra a linha reta do telhado. É o detalhe que mais enriquece a
	-- silhueta de um bairro medieval visto de longe.
	if floors >= 2 and math.random() < 0.5 then
		local side = (math.random() < 0.5) and 1 or -1
		local dz = (math.random() - 0.5) * dd * 0.4
		local dw, dh, ddp = 3.6, 3.4, 3.2
		local dx = side * (ww / 4)
		local dy = topY + rh * 0.42

		Build.part({ -- corpo da mansarda
			Size = Vector3.new(dw, dh, ddp),
			CFrame = base * CFrame.new(dx, dy, dz),
			Color = plasterCol,
			Material = Enum.Material.Plaster,
		})
		-- telhadinho próprio (duas águas, mesma técnica)
		local mrw, mrh = dw + 1.2, 2.4
		local mhalf = mrw / 2
		local mslope = math.sqrt(mhalf * mhalf + mrh * mrh)
		local mpitch = math.atan2(mrh, mhalf)
		for _, s2 in { -1, 1 } do
			Build.part({
				Size = Vector3.new(mslope, 0.4, ddp + 1),
				CFrame = base
					* CFrame.new(dx + s2 * (mrw / 4), dy + dh / 2 + mrh / 2, dz)
					* CFrame.Angles(0, 0, -s2 * mpitch),
				Color = roofCol,
				Material = roofTile and Enum.Material.Slate or Enum.Material.WoodPlanks,
				CastShadow = false,
			})
		end
		Build.window(
			base * CFrame.new(dx + side * (ddp / 2 + 0.15), dy, dz)
				* CFrame.Angles(0, math.rad(side * 90), 0),
			1.4,
			1.6,
			math.random() < 0.6
		)
	end

	-- ---------------- chaminé ----------------
	if math.random() < 0.7 then
		local cx = (w / 2 - 1.8) * (math.random() < 0.5 and 1 or -1)
		local ch = rh * 0.8 + 3
		Build.part({
			Size = Vector3.new(2.2, ch, 2.2),
			CFrame = base * CFrame.new(cx, topY + ch / 2, -d / 4),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
		})
		Build.part({ -- coroamento
			Size = Vector3.new(3, 0.6, 3),
			CFrame = base * CFrame.new(cx, topY + ch + 0.3, -d / 4),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
end

-- ================================================================= RUAS
local function road(from: Vector3, to: Vector3, width: number)
	local d = to - from
	local len = Vector3.new(d.X, 0, d.Z).Magnitude
	Build.part({
		Size = Vector3.new(width, 0.5, len),
		CFrame = CFrame.lookAt(
			Vector3.new((from.X + to.X) / 2, 0.3, (from.Z + to.Z) / 2),
			Vector3.new(to.X, 0.3, to.Z)
		),
		Color = C.COBBLE,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	})
	-- meio-fio
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(0.8, 0.75, len),
			CFrame = CFrame.lookAt(
				Vector3.new((from.X + to.X) / 2, 0.38, (from.Z + to.Z) / 2),
				Vector3.new(to.X, 0.38, to.Z)
			) * CFrame.new(s * width / 2, 0, 0),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CanCollide = false,
		})
	end
end

-- arco de pedra cruzando a rua, com estandartes (ref. Solitude)
local function streetArch(z: number)
	local W = Town.MAIN_ROAD_W / 2 + 6
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(6, 20, 8),
			CFrame = CFrame.new(s * W, 10, z),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
		})
	end
	for i = 0, 8 do
		local a = (i / 8) * math.pi
		Build.part({
			Size = Vector3.new(3.4, 3.4, 8),
			CFrame = CFrame.new(math.cos(a) * W, 20 + math.sin(a) * 7, z),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	for _, s in { -1, 1 } do
		Build.banner(CFrame.new(s * (W - 3), 13, z - 4.2), 11, s > 0 and C.BANNER or C.BANNER_2)
	end
	-- bandeirolas atravessando a rua
	for i = -4, 4 do
		Build.part({
			Size = Vector3.new(1.1, 1.4, 0.12),
			CFrame = CFrame.new(i * 4, 17.5 - math.abs(i) * 0.35, z + 6)
				* CFrame.Angles(0, 0, math.rad(45)),
			Color = (i % 2 == 0) and C.BANNER or C.BANNER_2,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

local function buildStreets()
	road(Vector3.new(0, 0, Town.GATE_Z), Vector3.new(0, 0, Town.KEEP_Z), Town.MAIN_ROAD_W)
	for _, z in { -118, -58, 6 } do
		road(Vector3.new(-145, 0, z), Vector3.new(145, 0, z), 14)
	end
	-- becos estreitos (a densidade das referências vem daqui)
	for _, x in { -78, 78 } do
		road(Vector3.new(x, 0, -140), Vector3.new(x, 0, 20), 9)
	end

	streetArch(-124)
	streetArch(-16)

	local i = 0
	for z = Town.GATE_Z + 24, Town.KEEP_Z - 12, 30 do
		i += 1
		-- só metade das lanternas emite luz (custo de performance)
		Build.lantern(Vector3.new(-Town.MAIN_ROAD_W / 2 - 3, 0, z), i % 2 == 0)
		Build.lantern(Vector3.new(Town.MAIN_ROAD_W / 2 + 3, 0, z), i % 2 == 1)
	end
end

-- a casa cabe aqui? (dentro da muralha, fora do mercado e fora da via principal)
local INNER_LIMIT = 158 -- muralha fica em 185; deixa recuo pra passarela e becos
local MARKET_C = Vector3.new(0, 0, -80)
local MARKET_R = 38

local function canPlace(x: number, z: number, w: number, d: number): boolean
	local reach = math.max(w, d) / 2 + 3
	if math.sqrt(x * x + z * z) + reach > INNER_LIMIT then
		return false -- atravessaria a muralha
	end
	local dx, dz = x - MARKET_C.X, z - MARKET_C.Z
	if math.sqrt(dx * dx + dz * dz) < MARKET_R + reach then
		return false -- invadiria a praça do mercado
	end
	if math.abs(x) < Town.MAIN_ROAD_W / 2 + reach then
		return false -- em cima da via principal
	end
	return true
end

-- fileira densa de casas ao longo de uma rua
local function houseRow(z: number, xFrom: number, xTo: number, facing: number, tileChance: number)
	local x = xFrom
	while x < xTo - 10 do
		local w = 11 + math.random() * 7
		local d = 10 + math.random() * 4
		local cx = x + w / 2
		if canPlace(cx, z, w, d) then
			local floors = (math.random() < 0.6) and 2 or ((math.random() < 0.25) and 3 or 1)
			house(
				Vector3.new(cx, 0, z),
				w,
				d,
				floors,
				facing + math.rad(math.random(-3, 3)),
				math.random() < tileChance
			)
			x += w + 1.5 + math.random() * 2.5 -- coladas: cidade densa
		else
			x += 6
		end
	end
end

-- ================================================================= MERCADO
local function buildMarket()
	local c = Vector3.new(0, 0, -80)
	Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 66, 66),
		CFrame = CFrame.new(c + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.COBBLE,
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
	})
	-- poço com telhadinho
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		Build.part({
			Size = Vector3.new(1.5, 2.6, 1.5),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 3.6, 1.3, math.sin(a) * 3.6))
				* CFrame.Angles(0, a, 0),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
		})
	end
	for _, sx in { -3.8, 3.8 } do
		Build.post(c + Vector3.new(sx, 2.6, 0), 5.5, 0.5, C.TIMBER, Enum.Material.Wood)
	end
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(9.5, 0.5, 5),
			CFrame = CFrame.new(c + Vector3.new(0, 8.4, s * 1.2))
				* CFrame.Angles(math.rad(s * 32), 0, 0),
			Color = C.ROOF_SHINGLE,
			Material = Enum.Material.WoodPlanks,
			CastShadow = false,
		})
	end

	-- barracas
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2 + 0.35
		local p = c + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 24)
		local rot = -a
		for _, off in
			{ Vector3.new(-3.4, 0, -2.4), Vector3.new(3.4, 0, -2.4), Vector3.new(-3.4, 0, 2.4), Vector3.new(3.4, 0, 2.4) }
		do
			local r = CFrame.new(p) * CFrame.Angles(0, rot, 0) * CFrame.new(off)
			Build.post(r.Position, 5.5, 0.4, C.TIMBER, Enum.Material.Wood)
		end
		-- toldo em duas águas
		for _, s in { -1, 1 } do
			Build.part({
				Size = Vector3.new(8.5, 0.35, 4),
				CFrame = CFrame.new(p + Vector3.new(0, 6.2, 0))
					* CFrame.Angles(0, rot, 0)
					* CFrame.new(0, 0, s * 1.9)
					* CFrame.Angles(math.rad(s * 26), 0, 0),
				Color = (i % 2 == 0) and C.BANNER or C.BANNER_2,
				Material = Enum.Material.Fabric,
				CastShadow = false,
			})
		end
		-- balcão + mercadoria
		Build.part({
			Size = Vector3.new(7.5, 0.4, 2.2),
			CFrame = CFrame.new(p + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, rot, 0),
			Color = C.WOOD,
			Material = Enum.Material.WoodPlanks,
		})
		Build.crate(p + Vector3.new(2, 0, 1.4), 1.9)
		Build.barrel(p + Vector3.new(-2.2, 0, 1.6))
	end
end

-- ================================================================= SALÃO
local function buildKeep()
	local c = Vector3.new(0, 0, Town.KEEP_Z)

	Build.part({
		Size = Vector3.new(96, 9, 64),
		CFrame = CFrame.new(c + Vector3.new(0, 4.5, 16)),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	for i = 0, 8 do
		Build.part({
			Size = Vector3.new(28, 1.15, 2.8),
			CFrame = CFrame.new(c + Vector3.new(0, 0.6 + i * 1.02, -14 - i * 2.6)),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
		})
	end
	-- muretas da escadaria
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(2.5, 6, 26),
			CFrame = CFrame.new(c + Vector3.new(sx * 15, 3, -25)) * CFrame.Angles(math.rad(-11), 0, 0),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
		})
	end

	-- corpo do salão + telhado A (mesma técnica das casas)
	local w, d, h = 48, 32, 22
	local y0 = 9
	Build.part({
		Size = Vector3.new(w, h, d),
		CFrame = CFrame.new(c + Vector3.new(0, y0 + h / 2, 16)),
		Color = C.WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	local rw, rd, rh = w + 7, d + 7, 26
	local half = rw / 2
	local slope = math.sqrt(half * half + rh * rh)
	local pitch = math.atan2(rh, half)
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(slope, 1, rd),
			CFrame = CFrame.new(c + Vector3.new(s * (rw / 4), y0 + h + rh / 2, 16))
				* CFrame.Angles(0, 0, -s * pitch),
			Color = C.ROOF_SHINGLE,
			Material = Enum.Material.WoodPlanks,
		})
	end
	Build.part({
		Size = Vector3.new(2, 1.2, rd + 2),
		CFrame = CFrame.new(c + Vector3.new(0, y0 + h + rh, 16)),
		Color = C.TIMBER,
		Material = Enum.Material.Wood,
	})
	-- empena escalonada da frente
	for i = 0, 6 do
		local frac = (i + 0.5) / 7
		Build.part({
			Size = Vector3.new(w * (1 - frac), rh / 7 + 0.2, 0.8),
			CFrame = CFrame.new(c + Vector3.new(0, y0 + h + frac * rh, 0.2)),
			Color = C.WOOD,
			Material = Enum.Material.WoodPlanks,
			CastShadow = false,
		})
	end

	-- torre alta atrás (a silhueta que se vê da cidade inteira)
	local th = 46
	Build.part({
		Size = Vector3.new(18, th, 18),
		CFrame = CFrame.new(c + Vector3.new(0, y0 + th / 2, 40)),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		Build.part({
			Size = Vector3.new(3.6, 3.6, 3.6),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 7.8, y0 + th + 1.8, 40 + math.sin(a) * 7.8)),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	local trw, trh = 22, 16
	local thalf = trw / 2
	local tslope = math.sqrt(thalf * thalf + trh * trh)
	local tpitch = math.atan2(trh, thalf)
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(tslope, 0.8, 22),
			CFrame = CFrame.new(c + Vector3.new(s * (trw / 4), y0 + th + 5 + trh / 2, 40))
				* CFrame.Angles(0, 0, -s * tpitch),
			Color = C.ROOF_SHINGLE,
			Material = Enum.Material.WoodPlanks,
		})
	end

	-- portão, vigas e estandartes
	for _, sx in { -1, 1 } do
		Build.post(c + Vector3.new(sx * (w / 2 - 2.5), y0, 0.5), h + 3, 2.4, C.TIMBER, Enum.Material.Wood)
		Build.banner(CFrame.new(c + Vector3.new(sx * 11, y0 + h * 0.5, -0.3)), 14, C.BANNER)
	end
	Build.part({
		Size = Vector3.new(9, 11, 0.8),
		CFrame = CFrame.new(c + Vector3.new(0, y0 + 5.5, 0.1)),
		Color = C.WOOD_DARK,
		Material = Enum.Material.WoodPlanks,
	})
	for _, sx in { -15, 15 } do
		Build.window(CFrame.new(c + Vector3.new(sx, y0 + 13, 0.2)), 2.4, 3.4, true)
	end
	-- braseiros na entrada
	for _, sx in { -20, 20 } do
		local p = c + Vector3.new(sx, y0, -6)
		Build.post(p, 4, 1.4, C.STONE_DARK, Enum.Material.Cobblestone)
		local f = Build.part({
			Size = Vector3.new(2.6, 1.8, 2.6),
			CFrame = CFrame.new(p + Vector3.new(0, 4.4, 0)),
			Color = C.FIRE,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		Build.light(f, C.FIRE, 2.4, 45)
	end
end

local function buildDistricts()
	-- fileiras densas dos dois lados de cada rua (telha de barro perto do portão,
	-- madeira perto do salão — dá gradiente de "bairro" como nas referências)
	houseRow(-140, -140, -32, 0, 0.75)
	houseRow(-140, 32, 140, 0, 0.75)
	houseRow(-100, -138, -24, math.pi, 0.7)
	houseRow(-100, 24, 138, math.pi, 0.7)

	houseRow(-40, -136, -26, 0, 0.5)
	houseRow(-40, 26, 136, 0, 0.5)
	houseRow(-76, -134, -26, math.pi, 0.55)
	houseRow(-76, 26, 134, math.pi, 0.55)

	houseRow(-12, -120, -28, 0, 0.3)
	houseRow(-12, 28, 120, 0, 0.3)
	houseRow(26, -104, -30, math.pi, 0.2)
	houseRow(26, 30, 104, math.pi, 0.2)

	-- props de rua: mais variedade = rua que parece usada, não decorada
	for _ = 1, 140 do
		local x = math.random(-140, 140)
		local z = math.random(Town.GATE_Z + 18, 48)
		if math.abs(x) > Town.MAIN_ROAD_W / 2 + 3 and math.sqrt(x * x + z * z) < 165 then
			local p = Vector3.new(x, 0, z)
			local r = math.random()
			if r < 0.3 then
				Build.barrel(p)
			elseif r < 0.55 then
				Build.crate(p, 1.8 + math.random() * 1.6)
			elseif r < 0.7 then
				-- pilha de lenha
				for i = 0, 2 do
					Build.cyl(
						CFrame.new(x, 0.6 + i * 1.1, z) * CFrame.Angles(0, math.random() * 3, math.rad(90)),
						3.5,
						1,
						C.WOOD_DARK,
						Enum.Material.Wood
					)
				end
			elseif r < 0.82 then
				-- cerca de madeira
				local ang2 = math.random() * math.pi
				for i = 0, 3 do
					local fp = p + Vector3.new(math.cos(ang2) * i * 3, 0, math.sin(ang2) * i * 3)
					Build.post(fp, 3.4, 0.5, C.WOOD_DARK, Enum.Material.Wood)
				end
				Build.part({
					Size = Vector3.new(9.5, 0.4, 0.35),
					CFrame = CFrame.new(p + Vector3.new(math.cos(ang2) * 4.5, 2.4, math.sin(ang2) * 4.5))
						* CFrame.Angles(0, -ang2, 0),
					Color = C.WOOD_DARK,
					Material = Enum.Material.Wood,
					CanCollide = false,
				})
			elseif r < 0.92 then
				-- carroça de mão
				Build.part({
					Size = Vector3.new(5, 0.5, 3),
					CFrame = CFrame.new(p + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.random() * 6, 0),
					Color = C.WOOD,
					Material = Enum.Material.WoodPlanks,
				})
				for _, s in { -1.6, 1.6 } do
					Build.cyl(
						CFrame.new(p + Vector3.new(s, 1.4, 0)),
						0.4,
						2.8,
						C.WOOD_DARK,
						Enum.Material.Wood
					)
				end
			else
				-- monte de feno
				Build.part({
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(5, 3.4, 5),
					CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0)),
					Color = C.THATCH,
					Material = Enum.Material.Grass,
				})
			end
		end
	end

	-- neve encostada nas construções (acúmulo no chão dá muito realismo)
	for _ = 1, 70 do
		local x = math.random(-150, 150)
		local z = math.random(Town.GATE_Z, 60)
		if math.sqrt(x * x + z * z) < 168 then
			Build.snow(
				CFrame.new(x, 0.35, z) * CFrame.Angles(0, math.random() * 6, 0),
				Vector3.new(4 + math.random() * 7, 0.7, 3 + math.random() * 5)
			)
		end
	end
end

function Town.build()
	buildStreets()
	buildDistricts()
	buildMarket()
	buildKeep()
end

return Town
