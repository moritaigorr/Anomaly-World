--!strict
-- Terra.lua  (SERVIDOR)
-- Terreno de verdade (voxel) em vez de um bloco plano: planície nevada, fiorde
-- com água e cordilheira ao redor. Referência: foto de Siglufjörður/Islândia —
-- cidade encaixada entre montanha e mar, luz baixa e fria.

local Terrain = workspace.Terrain

local Terra = {}

-- topo do terreno fica em y = 0 (todo o resto do mundo assume isso)
local GROUND_TOP = 0
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
	local function ridge(count: number, distMin: number, distSpan: number, rMin: number, rSpan: number)
		for i = 1, count do
			local ang = (i / count) * math.pi * 2 + math.random() * 0.15
			if math.cos(ang) < 0.45 then -- pula o setor do mar
				local dist = distMin + math.random() * distSpan
				local x, z = math.cos(ang) * dist, math.sin(ang) * dist
				local r = rMin + math.random() * rSpan
				Terrain:FillBall(Vector3.new(x, GROUND_TOP - r * 0.40, z), r, Enum.Material.Rock)
				Terrain:FillBall(Vector3.new(x, GROUND_TOP + r * 0.32, z), r * 0.48, Enum.Material.Snow)
			end
		end
	end

	ridge(20, 380, 70, 55, 55) -- serra próxima: dá profundidade
	ridge(26, 600, 90, 110, 90) -- parede de horizonte: esconde a borda do mundo

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

	-- afloramentos: rocha exposta com neve acumulada em cima
	for _ = 1, 70 do
		local x = (math.random() - 0.5) * PLAIN * 0.86
		local z = (math.random() - 0.5) * PLAIN * 0.86
		if not blocked(x, z) then
			local r = 9 + math.random() * 20
			Terrain:FillBall(Vector3.new(x, GROUND_TOP - r * 0.55, z), r, Enum.Material.Rock)
			Terrain:FillBall(Vector3.new(x, GROUND_TOP - r * 0.15, z), r * 0.62, Enum.Material.Snow)
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
