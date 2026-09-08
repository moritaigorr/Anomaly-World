--!strict
-- Walls.lua  (SERVIDOR)
-- A muralha que cerca a cidade: o elemento de silhueta mais forte do mapa
-- (ref. Attack on Titan e Whiterun). Alta, irregular, com ameias de verdade,
-- torres redondas e um portão monumental por onde o jogador sai pra caçar.
--
-- POR QUE A VERSÃO ANTERIOR LIA COMO LAJE (os dois bugs que importavam):
--
--  1. As ameias tinham 6,5 studs de comprimento espaçadas a cada 5. Cada merlão
--     invadia o vizinho, então em vez de merlão-vão-merlão o resultado era uma
--     FAIXA SÓLIDA. O jogo nunca teve crenelagem: tinha um friso contínuo.
--  2. O plano era um círculo perfeito. A "irregularidade" mexia ±1,7 na altura
--     e ±0,8° na inclinação de uma parede de 54 studs — invisível — e nunca
--     tocava no raio. Círculo perfeito é assinatura de "gerado por loop".
--
-- Agora o traçado é um polígono fechado irregular (harmônicos inteiros da volta,
-- portanto periódico e sem emenda) e o perfil tem quatro leituras: talude,
-- corpo, friso e parapeito recortado.

local Build = require(script.Parent.Build)
local Town = require(script.Parent.Town)
local C = Build.C

local Walls = {}

Walls.RADIUS = 185
Walls.HEIGHT = 54

export type Config = {
	radius: number?,
	height: number?,
	segments: number?,
	gateT: number?, -- posição do portão no traçado, 0..1 (0.75 = sul)
	seed: number?, -- muda o formato da muralha sem mudar o código
	roughness: number?, -- 0 = círculo perfeito; 1 = bem recortada
}

type Cfg = {
	radius: number,
	height: number,
	segments: number,
	gateT: number,
	seed: number,
	roughness: number,
}

-- ---------------- PERFIL ----------------
-- Uma muralha real não é uma laje vertical. Tem embasamento mais largo (talude,
-- que a faz parecer plantada no chão em vez de apoiada nele), corpo, friso
-- saliente marcando o nível da passarela, e parapeito com ameias. São quatro
-- leituras de perto e uma silhueta recortada de longe.
local BATTER_H = 13 -- altura do talude
local BATTER_OUT = 3.2 -- quanto o talude avança além do corpo
local BODY_T = 9 -- espessura do corpo
local CORNICE_OUT = 1.5 -- saliência do friso
local CORNICE_H = 1.8
local PARAPET_H = 7
local MERLON_W = 3.4 -- largura do merlão (o dente)
local MERLON_GAP = 2.9 -- vão entre merlões: ISTO é a ameia
local WALK_W = 6 -- passarela interna

local function cfg(c: Config?): Cfg
	local t = c or {}
	return {
		radius = t.radius or Walls.RADIUS,
		height = t.height or Walls.HEIGHT,
		segments = t.segments or 72,
		gateT = t.gateT or 0.75,
		seed = t.seed or 1,
		roughness = t.roughness or 1,
	}
end

-- Traçado irregular mas FECHADO: só harmônicos inteiros da volta completa, então
-- o fim encontra o começo exatamente. Sem isso a muralha abriria uma fresta.
local function radiusAt(t: number, k: Cfg): number
	local a = t * math.pi * 2
	local s = k.seed * 1.7
	local wobble = math.sin(a * 3 + s) * 9.0
		+ math.sin(a * 5 + s * 2.3) * 5.0
		+ math.sin(a * 8 + s * 3.1) * 2.5
	return k.radius + wobble * k.roughness
end

local function pointAt(t: number, k: Cfg): Vector3
	local a = t * math.pi * 2
	local r = radiusAt(t, k)
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

-- A altura também ondula: muralha erguida ao longo de séculos não tem uma linha
-- de topo perfeitamente reta.
local function heightAt(t: number, k: Cfg): number
	local a = t * math.pi * 2
	local wobble = math.sin(a * 4 + k.seed) * 3.2 + math.sin(a * 7 + k.seed * 2) * 1.8
	return k.height + wobble * k.roughness
end

-- distância angular curta entre dois t (ambos em 0..1)
local function tDist(a: number, b: number): number
	local d = math.abs(a - b) % 1
	return math.min(d, 1 - d)
end

-- ---------------- CRENELAGEM ----------------
-- Merlão de 3,4 com vão de 2,9: passo 6,3. O VÃO é o que faz o olho ler
-- "fortificação". Antes o passo era menor que o merlão e tudo virava parede.
local function crenellate(cf: CFrame, length: number, top: number)
	local step = MERLON_W + MERLON_GAP
	local n = math.max(1, math.floor(length / step))
	local used = n * step
	local start = -used / 2 + step / 2
	for i = 0, n - 1 do
		Build.part({
			Size = Vector3.new(BODY_T + CORNICE_OUT * 2, PARAPET_H, MERLON_W),
			CFrame = cf * CFrame.new(0, top + PARAPET_H / 2, start + i * step),
			Color = Build.tint(C.STONE_LIGHT, 0.045),
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
end

-- ---------------- TORRE ----------------
-- Redonda, não cúbica. Uma torre quadrada de 18x18 com telhado de caixas
-- empilhadas era a coisa mais "Roblox" que existia neste mapa.
local function tower(pos: Vector3, k: Cfg, tall: number)
	local h = k.height + tall
	local d = 21

	-- Fuste. Cilindro pega a luz do sol em mais ângulos que uma face plana, então
	-- com a MESMA cor do corpo da muralha a torre lia como arenito claro ao lado
	-- de granito. Escurecer um degrau faz as duas voltarem a ser a mesma pedra.
	Build.post(pos, h, d, Build.tint(C.STONE_DARK, 0.05), Enum.Material.Cobblestone)
	-- talude da base: a torre nasce do chão, não pousa nele
	Build.post(pos, BATTER_H, d + 4.5, C.STONE_DARK, Enum.Material.Cobblestone)
	-- mísula: anel saliente sob o parapeito. Detalhe barato que lê como pedra
	-- trabalhada e quebra o cilindro liso.
	Build.post(pos + Vector3.new(0, h - 5, 0), 2.6, d + 3.2, C.STONE, Enum.Material.Cobblestone)

	-- ameias em volta do topo
	local ring = 10
	for i = 0, ring - 1 do
		local a = (i / ring) * math.pi * 2
		Build.part({
			Size = Vector3.new(3.2, PARAPET_H, 3.2),
			CFrame = CFrame.new(
				pos + Vector3.new(math.cos(a) * (d / 2 + 0.6), h + PARAPET_H / 2 - 1, math.sin(a) * (d / 2 + 0.6))
			) * CFrame.Angles(0, -a, 0),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end

	-- telhado cônico: cilindros decrescentes. Passo pequeno = cone, não escada.
	local layers = 9
	for i = 0, layers - 1 do
		local f = i / layers
		Build.post(
			pos + Vector3.new(0, h + PARAPET_H - 1 + i * 1.9, 0),
			2.0,
			(d - 1) * (1 - f * 0.92),
			Build.tint(C.ROOF_SHINGLE, 0.03),
			Enum.Material.Wood
		)
	end

	-- braseiro: o pontinho quente que dá escala e leitura noturna à silhueta
	-- esfera, não cubo: de longe um cubo de Neon vira um quadrado amarelo colado
	-- no céu; a esfera lê como fogo mesmo a 300 studs
	local fire = Build.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = CFrame.new(pos + Vector3.new(0, h + PARAPET_H + layers * 1.9 + 1, 0)),
		Color = C.FIRE,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
		CastShadow = false,
	})
	Build.light(fire, C.FIRE, 0.9, 24)
end

-- ---------------- PORTARIA ----------------
local function gatehouse(k: Cfg)
	local z = Town.GATE_Z - 25
	local h = k.height
	local step = MERLON_W + MERLON_GAP

	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(22, h + 20, 24),
			CFrame = CFrame.new(sx * 24, (h + 20) / 2, z),
			Color = C.STONE,
			Material = Enum.Material.Cobblestone,
		})
		-- talude nas torres do portão
		Build.part({
			Size = Vector3.new(22 + BATTER_OUT * 2, BATTER_H, 24 + BATTER_OUT * 2),
			CFrame = CFrame.new(sx * 24, BATTER_H / 2, z),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
		})
		-- ameias reais no topo das torres do portão
		for i = 0, 3 do
			for _, sz in { -1, 1 } do
				Build.part({
					Size = Vector3.new(MERLON_W, PARAPET_H, 3.4),
					CFrame = CFrame.new(sx * 24 + (i - 1.5) * step, h + 20 + PARAPET_H / 2, z + sz * 10.5),
					Color = C.STONE_LIGHT,
					Material = Enum.Material.Cobblestone,
					CastShadow = false,
				})
			end
		end
		Build.banner(CFrame.new(sx * 24, h * 0.62, z - 12.2), 16, C.BANNER)
	end

	-- travessa por cima da passagem
	Build.part({
		Size = Vector3.new(28, 16, 24),
		CFrame = CFrame.new(0, h + 12, z),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	for i = 0, 3 do
		for _, sz in { -1, 1 } do
			Build.part({
				Size = Vector3.new(MERLON_W, PARAPET_H, 3.4),
				CFrame = CFrame.new((i - 1.5) * step, h + 20 + PARAPET_H / 2, z + sz * 10.5),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
		end
	end
	-- arco
	for i = 0, 8 do
		local a = (i / 8) * math.pi
		Build.part({
			Size = Vector3.new(3, 3, 24),
			CFrame = CFrame.new(math.cos(a) * 13, h + 4 + math.sin(a) * 9, z),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	-- portas abertas
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(11, 22, 1.2),
			CFrame = CFrame.new(sx * 8, 11, z - 11) * CFrame.Angles(0, math.rad(sx * 62), 0),
			Color = C.WOOD_DARK,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- ESTRADA SAINDO DO PORTÃO. Fora dos muros ninguém assentou pedra: aqui é
	-- terra batida mesmo. E era uma LAJE de 20x0,5 pousada em y=0,25 — ou seja,
	-- enterrada, porque a superfície do terreno está em y≈2. Agora é terreno
	-- pintado e nivelado, em blocos sobrepostos pra borda não sair de régua.
	for i = 0, 11 do
		local zz = z - 12 - i * 11
		Build.paintGround(
			(math.random() - 0.5) * 3,
			zz,
			18 + math.random() * 7,
			Enum.Material.Ground
		)
	end
end

function Walls.build(config: Config?)
	local k = cfg(config)
	local N = k.segments
	local gateArc = 0.055 -- fração da volta ocupada pelo portão

	for i = 0, N - 1 do
		local t0, t1 = i / N, (i + 1) / N
		local tMid = (t0 + t1) / 2
		if tDist(tMid, k.gateT) > gateArc then
			local p0, p1 = pointAt(t0, k), pointAt(t1, k)
			local dir = p1 - p0
			local len = dir.Magnitude + 1.2 -- sobreposição: sem fresta entre trechos
			local mid = (p0 + p1) / 2
			local h = heightAt(tMid, k)
			-- o eixo Z da peça acompanha o trecho; "outward" aponta pra fora
			local flat = CFrame.lookAt(mid, mid + dir.Unit)
			local outward = mid.Unit

			-- corpo
			Build.part({
				Size = Vector3.new(BODY_T, h, len),
				CFrame = flat * CFrame.new(0, h / 2, 0),
				Color = Build.tint((i % 3 == 0) and C.STONE_DARK or C.STONE, 0.05),
				Material = Enum.Material.Cobblestone,
			})
			-- talude: mais largo e escuro, planta a muralha no chão
			Build.part({
				Size = Vector3.new(BODY_T + BATTER_OUT * 2, BATTER_H, len),
				CFrame = flat * CFrame.new(0, BATTER_H / 2, 0),
				Color = Build.tint(C.STONE_DARK, 0.04),
				Material = Enum.Material.Cobblestone,
			})
			-- friso saliente marcando o nível da passarela
			Build.part({
				Size = Vector3.new(BODY_T + CORNICE_OUT * 2, CORNICE_H, len),
				CFrame = flat * CFrame.new(0, h - 0.7, 0),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
			-- parapeito recortado
			crenellate(flat, len, h)
			-- Neve acumulada no pé, do lado de fora. Sem isso a muralha encosta na
			-- planície numa linha reta e dura, e as duas parecem coisas separadas
			-- empilhadas — não construção assentada num terreno.
			-- TERRENO, não peça: uma barra branca de 3,4 x 21 contornando a
			-- muralha inteira é exatamente o tipo de aresta reta que denuncia
			-- geometria. Bolas de neve vizinhas se fundem num banco contínuo.
			for k = 0, 1 do
				local at = (flat * CFrame.new(0, 0, (k - 0.5) * len * 0.55)).Position
					+ outward * (BODY_T / 2 + 2.6)
				Build.drift(Vector3.new(at.X, 2, at.Z), 2.4, 5.2)
			end
			-- passarela interna, encostada na face de dentro
			Build.part({
				Size = Vector3.new(WALK_W, 1, len),
				CFrame = flat * CFrame.new(0, h - 0.5, 0) - outward * (BODY_T / 2 + WALK_W / 2 - 0.5),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
		end
	end

	-- Torres em intervalos IRREGULARES e alturas diferentes. Espaçamento perfeito
	-- denuncia tanto quanto o círculo perfeito: ninguém constrói assim ao longo
	-- de séculos, cada torre responde a uma ameaça de uma época.
	local spots = { 0.02, 0.14, 0.235, 0.35, 0.46, 0.56, 0.655, 0.895, 0.965 }
	local talls = { 16, 22, 12, 26, 14, 20, 11, 24, 15 }
	for i, t in spots do
		if tDist(t, k.gateT) > gateArc + 0.03 then
			tower(pointAt(t, k), k, talls[i])
		end
	end

	gatehouse(k)
end

return Walls
