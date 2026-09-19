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

-- ---------------- PORTARIA: medidas ----------------
-- BUG QUE ISTO CORRIGE (o buraco na muralha).
-- A abertura era recortada por um arco fixo de ±0,055 da volta. Numa muralha de
-- raio 185 a volta tem ~1162 studs, então ±0,055 apaga 128 studs de parede — e a
-- portaria construída no lugar tem 70. Sobravam ~29 studs de buraco aberto de
-- cada lado, por onde se via a cidade inteira de fora.
-- Agora a abertura é definida pela PRÓPRIA geometria da portaria: o trecho de
-- muralha só é pulado se o seu meio cair dentro da pegada dela. Os dois não têm
-- como se desencontrar de novo, mesmo mudando raio, semente ou rugosidade.
local TOWER_W = 22 -- largura de cada torre do portão
local TOWER_D = 24 -- profundidade da portaria
local TOWER_X = 24 -- centro de cada torre em X (torres ocupam |x| 13..35)
local GATE_HALF = TOWER_X + TOWER_W / 2 -- 35: meia-largura total da portaria
local PASS_HALF = 13 -- meia-largura do vão de passagem (26 de vão)
local SPRING = 20 -- altura onde o arco começa a curvar
local DOOR_H = 19

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

-- O ponto cai dentro da pegada da portaria? É este teste — e não um arco fixo —
-- que decide onde a muralha abre. Deixamos 2 studs de folga pra DENTRO da
-- portaria: o trecho de muralha termina embutido na torre, então não existe
-- fresta possível na junção.
local function insideGate(p: Vector3): boolean
	return p.Z < -100 and math.abs(p.X) < GATE_HALF - 2
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
	-- braseiro no topo: o pontinho quente que dá escala à silhueta
	Build.fire(pos + Vector3.new(0, h + PARAPET_H + layers * 1.9 + 1, 0), 1.3, 24)
end

-- ---------------- PORTARIA ----------------
-- O QUE ESTAVA ERRADO (o "portão mal feito").
-- As duas torres subiam 74 studs e entre elas não havia NADA do chão até y=58:
-- um buraco retangular de 26 x 58 recortado na pedra, com duas portinhas de 22
-- lá embaixo e um "arco" decorativo pendurado a 58 studs de altura, longe de
-- qualquer coisa que ele pudesse estar arqueando. Lia como vão de elevador.
--
-- Agora a passagem tem escala humana e leitura de portaria: ombreiras retas até
-- a linha de imposta, arco pleno de aduelas em cima, e ALVENARIA FECHADA do
-- topo do arco até as ameias — que é o que faz uma portaria parecer maciça.
local function gatehouse(k: Cfg)
	local z = Town.GATE_Z - 25
	local h = k.height
	local step = MERLON_W + MERLON_GAP
	local topY = h + 20 -- topo das torres
	local crown = SPRING + PASS_HALF -- topo do intradorso do arco

	-- ---- torres laterais ----
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(TOWER_W, topY, TOWER_D),
			CFrame = CFrame.new(sx * TOWER_X, topY / 2, z),
			Color = Build.tint(C.STONE, 0.04),
			Material = Enum.Material.Cobblestone,
		})
		-- talude: a portaria nasce do chão, não pousa nele
		Build.part({
			Size = Vector3.new(TOWER_W + BATTER_OUT * 2, BATTER_H, TOWER_D + BATTER_OUT * 2),
			CFrame = CFrame.new(sx * TOWER_X, BATTER_H / 2, z),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
		})
		-- seteiras: recortes escuros e estreitos. Detalhe barato que dá escala a
		-- uma face que sem ele é só um retângulo de pedra.
		for i = 0, 2 do
			for _, face in { -1, 1 } do
				Build.part({
					Size = Vector3.new(0.9, 5.5, 1.2),
					CFrame = CFrame.new(sx * TOWER_X + (i - 1) * 6, 26 + i % 2 * 9, z + face * (TOWER_D / 2)),
					Color = Color3.fromRGB(16, 17, 19),
					Material = Enum.Material.Slate,
					CastShadow = false,
				})
			end
		end
		Build.banner(CFrame.new(sx * TOWER_X, h * 0.62, z - TOWER_D / 2 - 0.2), 16, C.BANNER)
	end

	-- ---- ombreiras da passagem (do chão até a imposta) ----
	for _, sx in { -1, 1 } do
		Build.part({
			Size = Vector3.new(2.4, SPRING, TOWER_D),
			CFrame = CFrame.new(sx * (PASS_HALF + 1.2), SPRING / 2, z),
			Color = Build.tint(C.STONE_DARK, 0.03),
			Material = Enum.Material.Cobblestone,
		})
		-- imposta: a pedra saliente de onde o arco parte
		Build.part({
			Size = Vector3.new(4.2, 1.1, TOWER_D + 1),
			CFrame = CFrame.new(sx * (PASS_HALF + 0.8), SPRING, z),
			Color = C.STONE_LIGHT,
			Material = Enum.Material.Cobblestone,
		})
	end

	-- ---- arco pleno: aduelas radiais ----
	-- A peça tem o eixo Y apontando pra FORA do centro do arco, então girar em Z
	-- por (a - 90°) resolve a orientação sem tentativa e erro.
	local NV = 19
	local rV = PASS_HALF + 1.6
	for i = 0, NV do
		local a2 = (i / NV) * math.pi
		Build.part({
			Size = Vector3.new(3.0, 3.2, TOWER_D),
			CFrame = CFrame.new(math.cos(a2) * rV, SPRING + math.sin(a2) * rV, z)
				* CFrame.Angles(0, 0, a2 - math.pi / 2),
			Color = Build.tint(C.STONE_LIGHT, 0.05),
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end

	-- ---- ALVENARIA ACIMA DO ARCO ----
	-- Isto é o que faltava: sem este bloco a portaria era um vão vazio de 58
	-- studs. Vai do topo do arco até as ameias e fecha a fachada.
	Build.part({
		Size = Vector3.new(PASS_HALF * 2 + 4.6, topY - (crown + 2), TOWER_D - 0.08),
		CFrame = CFrame.new(0, (crown + 2) + (topY - (crown + 2)) / 2, z),
		Color = Build.tint(C.STONE, 0.05),
		Material = Enum.Material.Cobblestone,
	})
	-- matacães: consolos salientes sobre a passagem (onde se despejava o que
	-- fosse preciso em quem batia na porta). Quebram a face lisa lá no alto.
	for i = -3, 3 do
		Build.part({
			Size = Vector3.new(2.6, 2.2, 3.4),
			CFrame = CFrame.new(i * 4.2, topY - 7, z - TOWER_D / 2 - 1.2),
			Color = C.STONE_DARK,
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
		})
	end
	-- friso contínuo marcando o nível da passarela, ligando as duas torres
	Build.part({
		Size = Vector3.new(GATE_HALF * 2 + CORNICE_OUT * 2, CORNICE_H, TOWER_D + CORNICE_OUT * 2),
		CFrame = CFrame.new(0, topY - 1.2, z),
		Color = C.STONE_LIGHT,
		Material = Enum.Material.Cobblestone,
		CastShadow = false,
	})

	-- ---- ameias no topo, atravessando a portaria inteira ----
	local n = math.floor((GATE_HALF * 2) / step)
	for i = 0, n - 1 do
		local x = -((n - 1) * step) / 2 + i * step
		for _, sz in { -1, 1 } do
			Build.part({
				Size = Vector3.new(MERLON_W, PARAPET_H, 3.4),
				CFrame = CFrame.new(x, topY + PARAPET_H / 2, z + sz * (TOWER_D / 2 - 1.7)),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
		end
	end

	-- ---- grade (portcullis) meio baixada, presa no arco ----
	for i = -4, 4 do
		Build.part({
			Size = Vector3.new(0.5, 11, 0.5),
			CFrame = CFrame.new(i * 2.8, crown - 5.5, z + 7),
			Color = C.IRON,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CastShadow = false,
		})
	end
	for j = 0, 2 do
		Build.part({
			Size = Vector3.new(PASS_HALF * 2 - 2, 0.5, 0.5),
			CFrame = CFrame.new(0, crown - 1 - j * 4.6, z + 7),
			Color = C.IRON,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CastShadow = false,
		})
	end

	-- ---- folhas da porta, abertas contra as ombreiras ----
	for _, sx in { -1, 1 } do
		local swing = math.rad(72)
		local tip = Vector3.new(-sx * math.cos(swing), 0, -math.sin(swing))
		local hinge = Vector3.new(sx * PASS_HALF, DOOR_H / 2, z - TOWER_D / 2 + 2)
		local center = hinge + tip * (PASS_HALF / 2)
		local cf = CFrame.lookAt(center, center + tip)
		Build.part({
			Size = Vector3.new(1.4, DOOR_H, PASS_HALF),
			CFrame = cf,
			Color = C.WOOD_DARK,
			Material = Enum.Material.WoodPlanks,
		})
		-- ferragens: duas cintas de ferro por folha
		for _, fy in { -DOOR_H / 4, DOOR_H / 4 } do
			Build.part({
				Size = Vector3.new(1.7, 1.0, PASS_HALF - 0.6),
				CFrame = cf * CFrame.new(0, fy, 0),
				Color = C.IRON,
				Material = Enum.Material.Metal,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end

	-- ESTRADA SAINDO DO PORTÃO. Fora dos muros ninguém assentou pedra: aqui é
	-- terra batida mesmo, em blocos sobrepostos pra borda não sair de régua.
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

	for i = 0, N - 1 do
		local t0, t1 = i / N, (i + 1) / N
		local tMid = (t0 + t1) / 2
		-- abre a muralha SÓ onde a portaria realmente cobre (ver insideGate)
		if not insideGate(pointAt(tMid, k)) then
			local p0, p1 = pointAt(t0, k), pointAt(t1, k)
			local dir = p1 - p0
			local len = dir.Magnitude + 1.2 -- sobreposição: sem fresta entre trechos
			local mid = (p0 + p1) / 2
			local h = heightAt(tMid, k)
			-- o eixo Z da peça acompanha o trecho; "outward" aponta pra fora
			local flat = CFrame.lookAt(mid, mid + dir.Unit)
			local outward = mid.Unit

			-- Espessura alternada por um fio. Os trechos se sobrepoem 1,2 pra nao
			-- abrir fresta, e com a MESMA espessura as faces laterais dos dois ficam
			-- exatamente no mesmo plano: o renderizador nao tem como decidir qual
			-- esta na frente e sai uma listra que pisca em cada emenda. 0,06 de
			-- diferenca resolve e e invisivel.
			local eps = (i % 2) * 0.06

			-- corpo
			Build.part({
				Size = Vector3.new(BODY_T + eps, h, len),
				CFrame = flat * CFrame.new(0, h / 2, 0),
				Color = Build.tint((i % 3 == 0) and C.STONE_DARK or C.STONE, 0.05),
				Material = Enum.Material.Cobblestone,
			})
			-- talude: mais largo e escuro, planta a muralha no chão
			Build.part({
				Size = Vector3.new(BODY_T + BATTER_OUT * 2 + eps, BATTER_H, len),
				CFrame = flat * CFrame.new(0, BATTER_H / 2, 0),
				Color = Build.tint(C.STONE_DARK, 0.04),
				Material = Enum.Material.Cobblestone,
			})
			-- friso saliente marcando o nível da passarela
			Build.part({
				Size = Vector3.new(BODY_T + CORNICE_OUT * 2 + eps, CORNICE_H, len),
				CFrame = flat * CFrame.new(0, h - 0.7, 0),
				Color = C.STONE_LIGHT,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
			})
			-- Parapeito recortado. Usa o comprimento VERDADEIRO do trecho, e nao o
			-- esticado: com o +1,2 de sobreposicao os merloes do fim de um trecho
			-- caiam em cima dos do comeco do seguinte -- duas pecas identicas no
			-- mesmo lugar, com tons sorteados diferentes, o que faz a emenda PISCAR
			-- (z-fighting) em volta da muralha inteira.
			crenellate(flat, dir.Magnitude, h)
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
		local p = pointAt(t, k)
		-- nenhuma torre solta encostada na portaria
		if not (p.Z < -100 and math.abs(p.X) < GATE_HALF + 30) then
			tower(p, k, talls[i])
		end
	end

	gatehouse(k)
end

return Walls
