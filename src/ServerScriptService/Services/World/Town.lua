--!strict
-- Town.lua  (SERVIDOR)
-- A cidade: casas enxaimel, ruas de pedra, mercado, arcos com estandartes e o
-- Salão do Jarl. Estrutura tirada de Whiterun; arquitetura das referências de
-- Attack on Titan (telhado de telha, fileiras densas) e Riverwood/Solitude.
--
-- NOTA DE GEOMETRIA: o telhado é feito de DUAS LAJES INCLINADAS (rotação simples
-- no eixo Z) formando o "A", e a empena é escalonada. WedgePart com rotação dupla
-- é imprevisível de orientação — foi o que quebrou a versão anterior.

local Terrain = workspace.Terrain

local Build = require(script.Parent.Build)
local Market = require(script.Parent.Market)
local C = Build.C

local Town = {}

Town.GATE_Z = -160
Town.KEEP_Z = 70
Town.MAIN_ROAD_W = 22

-- Soleiras das casas, registradas aqui porque house() precisa delas e roda
-- muito antes do resto. Declarar isto lá embaixo, junto das ruas, fazia
-- table.insert receber nil e DERRUBAVA a construção da cidade inteira.
local doorsteps: { Vector3 } = {}

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

	-- Neve acumulada no pé da parede. Sem isso parede e chão se encontram numa
	-- linha reta e dura e a casa parece POUSADA sobre a neve em vez de estar
	-- enterrada nela desde novembro.
	-- A casa encara +Z, então a PORTA fica no meio da face +Z. O terceiro monte
	-- caía exatamente ali e o jogador tinha que escalar neve pra entrar. Neve
	-- acumula onde o vento deposita e ninguém pisa: nas laterais e nos cantos
	-- de trás — nunca na soleira, que é o primeiro lugar que alguém limpa.
	for _, o in
		{
			Vector3.new(w / 2 + 0.9, 0, d * 0.18),
			Vector3.new(-w / 2 - 0.9, 0, -d * 0.22),
			Vector3.new(w / 2 + 0.6, 0, -d / 2 - 0.6),
			Vector3.new(-w / 2 - 0.6, 0, -d / 2 - 0.6),
		}
	do
		Build.drift((base * o) + Vector3.new(0, 0.35, 0), 1.3, 2.3)
	end
	-- e limpa a soleira, caso a neve espalhada da cidade tenha caído ali
	-- 1,6 e não 2,4: a d/2 + 2,4 a soleira descolava da fachada e virava uma
	-- laje de pedra solta na neve, sem casa em cima dela.
	local doorAt = base * Vector3.new(0, 0, d / 2 + 1.6)
	table.insert(doorsteps, doorAt)
	Build.paintGround(doorAt.X, doorAt.Z, 9, Enum.Material.Cobblestone)

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
		-- FIADAS DE TELHA. Uma laje inclinada lisa é uma RAMPA, não um telhado.
		-- O que faz o olho ler "telha" não é a cor: é a sombra fina que cada
		-- fiada projeta na de baixo. Quatro fiadas sobrepostas, cada uma um
		-- degrau acima da seguinte, e alternando um tom — de longe some a
		-- escadinha e fica a textura.
		local courses = 4
		local cLen = slope / courses
		for ci = 0, courses - 1 do
			Build.part({
				Size = Vector3.new(cLen * 1.05, 0.3, rd + 0.12),
				CFrame = rcf * CFrame.new(
					-s * (slope / 2) + s * cLen * (ci + 0.5),
					0.42 + (courses - ci) * 0.055,
					0
				),
				Color = roofCol:Lerp(Color3.fromRGB(20, 16, 14), 0.05 + (ci % 2) * 0.06),
				Material = roofTile and Enum.Material.Slate or Enum.Material.WoodPlanks,
				CanCollide = false,
				CastShadow = false,
			})
		end

		-- Neve junto à cumeeira, em faixas com linha de degelo IRREGULAR. Era uma
		-- laje branca retangular só, e a aresta reta dela era o que fazia o
		-- telhado ler como "retângulo branco colado em cima da casa".
		-- O telhado ainda precisa CONTRASTAR: neve só na parte alta, nunca inteiro,
		-- senão a casa some contra o chão nevado.
		Build.roofSnow(rcf, slope, rd - 1.2, s)
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
-- CHÃO BATIDO.
-- Um FillBlock único deixa a rua com borda de régua, e um FillCylinder deixa a
-- praça com uma circunferência perfeita de lama no meio da neve. Nos dois casos
-- a FORMA denuncia o código antes de qualquer textura. Preenchendo em pedaços
-- sobrepostos, com largura e giro sorteados, a borda sai irregular de graça —
-- e o voxel de 4 studs já serrilha o resto.
local function trodden(cf: CFrame, width: number, len: number, mat: Enum.Material)
	-- FAIXA PAVIMENTADA, contínua e NIVELADA.
	--
	-- A largura é CONSTANTE de propósito. Antes era sorteada (0,54 a 0,76 da via)
	-- e o passo era grande: entre um quadrado e o outro sobrava vão, e era
	-- exatamente nesses vãos que a neve ficava em cima da rua. Rua de pedra não
	-- sofre influência da neve — ela está assentada, sempre no mesmo nível.
	local paveW = width * 0.82
	local step = width * 0.5 -- metade da largura: garante sobreposição
	local n = math.max(1, math.ceil(len / step))
	for i = 0, n - 1 do
		local t = -len / 2 + step * (i + 0.5)
		-- jitter pequeno só pra borda não sair de régua; nunca o bastante pra abrir vão
		local p = (cf * CFrame.new((math.random() - 0.5) * 1.6, 0, t)).Position
		Build.paintGround(p.X, p.Z, paveW, mat)
	end

	-- NEVE só FORA da faixa pavimentada, rareando em direção a ela. É o degradê
	-- que desenha a rua — mas ele acontece na margem, nunca sobre a pedra.
	local sstep = 6
	local m = math.max(1, math.floor(len / sstep))
	for i = 0, m - 1 do
		local t = -len / 2 + sstep * (i + 0.5)
		for _, sx in { -1, 1 } do
			for _, band in { { u = 0.75, chance = 0.9, size = 4.6 }, { u = 0.58, chance = 0.4, size = 3.0 } } do
				if math.random() < band.chance then
					local at = (cf * CFrame.new(sx * band.u * width, 0, t + (math.random() - 0.5) * 4)).Position
					Build.drift(Vector3.new(at.X, 2, at.Z), 1.5, band.size)
				end
			end
		end
	end
end

-- Rua DENTRO da vila é CALÇADA, não terra: é uma cidade murada com praça de
-- pedra, e o mesmo calçamento tem que continuar pelas ruas. Terra batida fica
-- para as estradas de FORA dos muros, onde ninguém assentou pedra.
-- Registro das ruas pavimentadas, pra poder repavimentar no fim.
local paved: { { from: Vector3, to: Vector3, width: number, mat: Enum.Material } } = {}

local function road(from: Vector3, to: Vector3, width: number, mat: Enum.Material?)
	local d = to - from
	local len = Vector3.new(d.X, 0, d.Z).Magnitude
	local mid = Vector3.new((from.X + to.X) / 2, 0, (from.Z + to.Z) / 2)
	local cf = CFrame.lookAt(mid, Vector3.new(to.X, 0, to.Z))

	local material = mat or Enum.Material.Cobblestone
	table.insert(paved, { from = from, to = to, width = width, mat = material })
	trodden(cf, width, len, material)

	-- montes de neve irregulares nas duas margens
	local n = math.max(3, math.floor(len / 13))
	for i = 0, n do
		for _, sx in { -1, 1 } do
			if math.random() < 0.72 then
				local t = (i / n - 0.5) * len
				Build.drift((cf * CFrame.new(sx * (width / 2 + 0.5), 0.35, t)).Position, 1.7, 3.2)
			end
		end
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
	-- ARCO. Estava quebrado: 9 aduelas de 3,4 studs distribuídas por ângulo
	-- constante numa elipse achatada. Perto do topo o passo chega a 6,5 studs,
	-- então sobrava um VÃO de 3,1 entre pedra e pedra e o arco lia como blocos
	-- soltos flutuando no céu. E eram cubos alinhados ao eixo, sem acompanhar a
	-- curva — pedra de arco é cunha, sempre apontada pro centro.
	local RISE = 9
	local N = 24
	for i = 0, N do
		local a = (i / N) * math.pi
		local x = math.cos(a) * W
		local y = 20 + math.sin(a) * RISE
		-- tangente da elipse: gira cada aduela pra acompanhar a curva
		local ang = math.atan2(math.cos(a) * RISE, -math.sin(a) * W)
		Build.part({
			Size = Vector3.new(4.4, 3.2, 8), -- 4,4 > passo máximo: sempre encostam
			CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, ang),
			Color = Build.tint(C.STONE_LIGHT, 0.045),
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	-- fecho (pedra do meio, maior): é o que faz o olho ler "arco" e não "curva"
	Build.part({
		Size = Vector3.new(4.6, 5.2, 8.6),
		CFrame = CFrame.new(0, 20 + RISE + 0.6, z),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	for _, s in { -1, 1 } do
		Build.banner(CFrame.new(s * (W - 3), 13, z - 4.2), 11, s > 0 and C.BANNER or C.BANNER_2)
	end
	-- CABO das bandeirolas, com barriga. Sem ele os losangos ficam flutuando
	-- soltos no ar — que era exatamente como estavam.
	for seg = -4, 3 do
		local x0, x1 = seg * 4, (seg + 1) * 4
		local y0 = 18.2 - math.abs(seg) * 0.34
		local y1 = 18.2 - math.abs(seg + 1) * 0.34
		local mid = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, z + 6)
		local len = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) + 0.2
		Build.part({
			Size = Vector3.new(len, 0.14, 0.14),
			CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, math.atan2(y1 - y0, x1 - x0)),
			Color = C.TIMBER,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CastShadow = false,
		})
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
-- Raio da PRAÇA em si. Cresceu de 38 pra 52 porque agora ela é o hub social:
-- seis barracas grandes num anel, braseiros, monumento e o banco fora do anel.
local MARKET_R = 52
-- Raio de EXCLUSÃO de casas.
-- Estava 84 pra caber o banco FORA do anel, e isso comeu metade da área
-- construível: a cidade caiu de ~80 casas para praticamente nenhuma, virando um
-- descampado de neve entre a praça e a muralha. O banco passou pra borda da
-- própria praça, então 62 basta (praça 52 + folga).
local MARKET_KEEPOUT = 62

local function canPlace(x: number, z: number, w: number, d: number): boolean
	local reach = math.max(w, d) / 2 + 3
	if math.sqrt(x * x + z * z) + reach > INNER_LIMIT then
		return false -- atravessaria a muralha
	end
	local dx, dz = x - MARKET_C.X, z - MARKET_C.Z
	if math.sqrt(dx * dx + dz * dz) < MARKET_KEEPOUT + reach then
		return false -- invadiria a praça do mercado
	end
	if math.abs(x) < Town.MAIN_ROAD_W / 2 + reach then
		return false -- em cima da via principal
	end
	-- O banco fica FORA do anel da praça. Em vez de inflar o raio de exclusão da
	-- praça inteira por causa dele (o que já apagou as casas da cidade uma vez),
	-- ele tem a própria área livre, do tamanho dele.
	local bc = Market.bankCenter(MARKET_C, MARKET_R)
	local bx, bz = x - bc.X, z - bc.Z
	if math.sqrt(bx * bx + bz * bz) < Market.BANK_CLEAR + reach then
		return false
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

	-- Neve acumulada pela cidade. Eram 70 CAIXAS brancas de 4x0,7x3 deitadas no
	-- chão (e ainda por cima enterradas em y=0,35, quando a superfície está em
	-- y≈2). Agora é terreno: bolas que se fundem em banco macio.
	-- 45 montes de 3,4 em vez de 70 de 5,5: com o tamanho anterior a cidade
	-- afundava em DUNAS e as construções ficavam ilhadas. Neve entre casas é
	-- acúmulo, não relevo.
	for _ = 1, 45 do
		local x = math.random(-150, 150)
		local z = math.random(Town.GATE_Z, 60)
		if math.sqrt(x * x + z * z) < 168 then
			Build.drift(Vector3.new(x, 2, z), 2.6, 3.4)
		end
	end
end

function Town.build()
	-- ORDEM IMPORTA. Tudo que PINTA chão batido (ruas, praça, braseiros) tem que
	-- rodar antes de tudo que ESPALHA neve, porque a neve só se deposita onde o
	-- chão ainda é neve. Na ordem errada a praça nasceria por cima de montes já
	-- formados e ficaria ondulada — a terra tem que ficar plana.
	buildStreets()
	Market.build(MARKET_C, MARKET_R)
	buildDistricts()
	buildKeep()

	-- REPAVIMENTAÇÃO FINAL.
	-- Rua de pedra e praça não sofrem influência da neve: estão assentadas,
	-- sempre no mesmo nível. Como qualquer monte de neve espalhado depois pode
	-- transbordar por cima delas, a garantia é dada AQUI, no fim, e não por
	-- ordem de chamadas — que é frágil e já falhou duas vezes.
	for _, r in paved do
		local d = r.to - r.from
		local len = Vector3.new(d.X, 0, d.Z).Magnitude
		local mid = Vector3.new((r.from.X + r.to.X) / 2, 0, (r.from.Z + r.to.Z) / 2)
		local cf = CFrame.lookAt(mid, Vector3.new(r.to.X, 0, r.to.Z))
		-- Largura CHEIA. Estreitar isto pra 0,58 deixou a rua uma fita fininha:
		-- a neve espalhada depois cobria toda a pedra que o repavimento não
		-- garantia. O que causava a pedra ondulada da foto era o ReplaceMaterial
		-- do paintGround, não a largura daqui — e aquele já saiu.
		local paveW = r.width * 0.86
		local step = r.width * 0.45
		for i = 0, math.max(1, math.ceil(len / step)) - 1 do
			local p = (cf * CFrame.new(0, 0, -len / 2 + step * (i + 0.5))).Position
			Build.paintGround(p.X, p.Z, paveW, r.mat)
		end
	end
	for _, at in doorsteps do
		Build.paintGround(at.X, at.Z, 9, Enum.Material.Cobblestone)
	end
	Market.repave(MARKET_C, MARKET_R)
end

return Town
