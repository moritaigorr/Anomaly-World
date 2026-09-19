--!strict
-- Terra.lua  (SERVIDOR)
-- Terreno de verdade (voxel) em vez de um bloco plano: planície nevada, fiorde
-- com água e cordilheira ao redor. Referência: foto de Siglufjörður/Islândia —
-- cidade encaixada entre montanha e mar, luz baixa e fria.

local Assets = require(script.Parent.Assets)
local Terrain = workspace.Terrain

local Terra = {}

-- ALTURA DO CHÃO.
--
-- O resto do mundo assume que o chão está em y = 0 e constrói pra cima a partir
-- daí. Só que o voxel de terreno tem 4 studs e a isosuperfície NÃO cai no topo
-- do preenchimento: medido em jogo, preencher até 0 renderiza a superfície em
-- y = 2. Resultado: todo prop colocado em y = 0 nascia DOIS STUDS ENTERRADO —
-- barril de 3 de altura virava uma tampa deitada na neve.
--
-- A quantização não permite acertar 0 exatamente (topo -1 -> superfície 1,0;
-- topo -2 -> superfície -1,0), mas -1 corta o enterramento pela metade em todo
-- o mapa de uma vez, e é uma linha em vez de 96 pontos de chamada.
-- Build.GROUND_TOP acompanha este valor: os dois preenchem o mesmo nível.
local GROUND_TOP = -1
local PLAIN = 1500 -- extensão da planície (era 900: dava pra ver a borda cortada)
local SEA_FROM = 300 -- a partir deste X começa o fiorde (leste)

local function fillBlock(cx: number, cy: number, cz: number, sx: number, sy: number, sz: number, mat: Enum.Material)
	Terrain:FillBlock(CFrame.new(cx, cy, cz), Vector3.new(sx, sy, sz), mat)
end

function Terra.build()
	Terrain:Clear()
	-- Neve quase branco puro (226,232,236) NÃO tem margem: sob sol ela satura o
	-- expositor e vira chapado — some a forma dos bancos, some a sombra e a cena
	-- inteira lava. Puxando pra 196 a neve continua lendo como neve e passa a
	-- ter meio-tom pra sombrear.
	Terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(196, 205, 214))
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(92, 92, 92))
	-- CALÇAMENTO. O Cobblestone padrão do terreno puxa pro marrom-tijolo; a
	-- referência é paralelepípedo de GRANITO — cinza frio, quase sem saturação,
	-- com a neve entrando nas juntas em vez de se acumular por cima. Cinza frio
	-- também separa a rua da madeira das casas, que é toda quente.
	Terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(132, 134, 138))
	-- Chão batido CINZENTO, não marrom quente: no meio de um mapa nevado um
	-- marrom saturado lê como lama de outono e briga com a paleta fria.
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(76, 71, 64))

	-- planície nevada (topo em y = 0)
	fillBlock(0, GROUND_TOP - 20, 0, PLAIN, 40, PLAIN, Enum.Material.Snow)

	-- rocha por baixo, pra encosta cortada não parecer neve maciça
	fillBlock(0, GROUND_TOP - 46, 0, PLAIN, 20, PLAIN, Enum.Material.Rock)

	-- ---- fiorde a leste: escava e enche de água ----
	local seaW = (PLAIN / 2) - SEA_FROM + 60
	local seaCx = SEA_FROM + seaW / 2
	fillBlock(seaCx, GROUND_TOP - 18, 0, seaW, 46, PLAIN, Enum.Material.Air)
	fillBlock(seaCx, GROUND_TOP - 21, 0, seaW, 40, PLAIN, Enum.Material.Water)

	-- praia/encosta descendo até a água
	for i = 0, 7 do
		local x = SEA_FROM - 46 + i * 6
		local drop = i * 1.6
		fillBlock(x, GROUND_TOP - 10 - drop, 0, 8, 20, PLAIN, Enum.Material.Air)
		fillBlock(x, GROUND_TOP - 20 - drop, 0, 8, 20, PLAIN, Enum.Material.Snow)
	end

	-- ---- CORDILHEIRA: duas faixas, formando um horizonte fechado ----
	-- Antes havia um único anel a 370 studs e dava pra ver a planície acabar num
	-- corte reto atrás dele. Agora uma faixa próxima (relevo) e outra distante e
	-- bem alta (parede de horizonte) escondem a borda do mundo.
	-- CORDILHEIRA DE MESH.
	--
	-- DUAS TENTATIVAS ERRADAS ANTES DESTA, e vale registrar pra ninguém repetir:
	-- primeiro cada montanha era UMA Terrain:FillBall — uma esfera enterrada pela
	-- metade, ou seja, um domo liso. Depois tentei "consertar" empilhando de 5 a 8
	-- bolas ao longo de uma crista, o que só produziu domos maiores encostados uns
	-- nos outros. Bola continua sendo bola: FillBall não tem como gerar aresta,
	-- face de rocha nem vertente.
	--
	-- Agora é MALHA: um mesh de penhasco do catálogo, esticado em três eixos
	-- (MeshPart.Size aceita escala não uniforme, ScaleTo não) pra cada monte ter
	-- proporção própria, com um pico menor por cima em branco fazendo a neve de
	-- cume. Duas peças por montanha contra ~7 bolas de terreno — e finalmente
	-- parece rocha.
	local ROCHA = Color3.fromRGB(88, 92, 99)
	local ROCHA_LONGE = Color3.fromRGB(104, 112, 124) -- mais claro: perspectiva aérea
	local NEVE_CUME = Color3.fromRGB(226, 232, 238)

	local function serra(count: number, distMin: number, distSpan: number, largMin: number, largSpan: number, altF: number, longe: boolean)
		for i = 1, count do
			local ang = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.22
			if math.cos(ang) < 0.45 then -- pula o setor do mar
				local dist = distMin + math.random() * distSpan
				local x, z = math.cos(ang) * dist, math.sin(ang) * dist
				local larg = largMin + math.random() * largSpan
				local alt = larg * altF * (0.8 + math.random() * 0.45)
				local prof = larg * (0.7 + math.random() * 0.5)
				local giro = math.random(0, 359)
				Assets.spawnRelief(
					Vector3.new(x, GROUND_TOP, z),
					larg,
					alt,
					prof,
					giro,
					longe and ROCHA_LONGE or ROCHA
				)
				-- cume nevado: a mesma malha menor, branca, sentada no terço de cima
				if math.random() < 0.85 then
					Assets.spawnRelief(
						Vector3.new(x, GROUND_TOP + alt * 0.46, z),
						larg * 0.52,
						alt * 0.42,
						prof * 0.52,
						giro + math.random(-25, 25),
						NEVE_CUME
					)
				end
			end
		end
	end

	serra(16, 390, 80, 200, 150, 0.62, false) -- serra próxima: dá profundidade
	serra(20, 620, 110, 330, 240, 0.58, true) -- parede de horizonte

	-- RELEVO DA PLANÍCIE.
	-- Uma planície perfeitamente plana é o que faz a cidade ler como maquete
	-- apoiada numa mesa: sem nada entre o jogador e a serra, o olho não tem como
	-- medir distância. Afloramentos de rocha e ondulações rasas dão escala,
	-- silhueta de meia distância e cobertura pro combate — e custam terreno
	-- voxel, não peças.
	local TOWN_CLEAR = 250 -- raio livre em volta da muralha
	local ROAD_HALF = 34 -- corredor da estrada que sai do portão

	local function blocked(x: number, z: number): boolean
		if math.sqrt(x * x + z * z) < TOWN_CLEAR then
			return true
		end
		if math.abs(x) < ROAD_HALF and z < 0 then
			return true -- não fecha a saída do portão
		end
		if x > SEA_FROM - 70 then
			return true -- não joga pedra dentro do fiorde
		end
		return false
	end

	-- AFLORAMENTOS: pedra exposta na planície. Também eram bolas (uma de rocha
	-- com outra de neve por cima); agora é a mesma malha de penhasco em tamanho
	-- de pedra, girada ao acaso, que dá aresta e sombra de verdade.
	for _ = 1, 55 do
		local x = (math.random() - 0.5) * PLAIN * 0.86
		local z = (math.random() - 0.5) * PLAIN * 0.86
		if not blocked(x, z) then
			local larg = 16 + math.random() * 26
			Assets.spawnRelief(
				Vector3.new(x, GROUND_TOP, z),
				larg,
				larg * (0.45 + math.random() * 0.4),
				larg * (0.7 + math.random() * 0.5),
				math.random(0, 359),
				Color3.fromRGB(92, 96, 104)
			)
		end
	end

	-- ondulações largas e RASAS: o olho lê como terreno, não como obstáculo
	for _ = 1, 90 do
		local x = (math.random() - 0.5) * PLAIN * 0.9
		local z = (math.random() - 0.5) * PLAIN * 0.9
		if not blocked(x, z) then
			local r = 26 + math.random() * 46
			Terrain:FillBall(Vector3.new(x, GROUND_TOP - r * 0.88, z), r, Enum.Material.Snow)
		end
	end

	-- (a elevação da cidade é feita com peças, na plataforma do Salão do Jarl:
	-- terreno voxel embaixo das construções causaria interseção)
end

return Terra
