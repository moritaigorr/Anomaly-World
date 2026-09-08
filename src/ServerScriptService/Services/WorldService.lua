--!strict
-- WorldService.lua  (SERVIDOR)
-- Orquestra a construção do mundo. A construção em si está em Services/World/:
--   Terra  -> terreno voxel (neve, fiorde, cordilheira)
--   Walls  -> a muralha, torres e o portão
--   Town   -> ruas, casas enxaimel, mercado e o Salão do Jarl
--   Wilds  -> floresta, forte em ruínas, túmulo, marcos rúnicos, círculo do boss
--
-- Referências: Whiterun (Skyrim), muralha de Attack on Titan, Vinland Saga e
-- cidades costeiras nevadas da Islândia.
--
-- Tudo o que é feito de peças fica em workspace.AnomalyWorld — apague a pasta
-- (e o Terrain) quando tiverem um mapa feito à mão.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local Constants = require(ReplicatedStorage.Shared.Constants)

local World = script.Parent.World
local Build = require(World.Build)
local Terra = require(World.Terra)
local Town = require(World.Town)
local Walls = require(World.Walls)
local Wilds = require(World.Wilds)
local Harbor = require(World.Harbor)
local Assets = require(World.Assets)

local WorldService = {}

local SPAWN_POS = ZoneData.SafeCenter + Vector3.new(0, 1.5, 0)

-- Em vez de chutar uma altura fixa, MEDE o chão com raycast de cima pra baixo.
-- Imune a mudança de terreno, geometria sobrando no lugar ou ordem de build.
function WorldService.getSpawnCFrame(): CFrame
	local x, z = SPAWN_POS.X, SPAWN_POS.Z

	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true

	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -900, 0), params)
	if hit then
		return CFrame.new(x, hit.Position.Y + 5, z)
	end
	-- não achou chão nenhum: joga bem alto (melhor cair do que nascer enterrado)
	warn("[WorldService] nenhum chão encontrado no spawn — usando altura de segurança")
	return CFrame.new(x, 30, z)
end

-- coloca o personagem no spawn e CONFERE de novo depois, porque o Roblox
-- reposiciona o personagem logo após o nascimento e sobrescreveria o nosso CFrame
function WorldService.placeCharacter(char: Model)
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local function put()
		if hrp.Parent then
			hrp.CFrame = WorldService.getSpawnCFrame()
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
	put()
	task.delay(0.15, put)
	task.delay(0.6, function()
		-- se ainda estiver enterrado, insiste
		if hrp.Parent and hrp.Position.Y < -2 then
			put()
		end
	end)
end

-- ponto onde o boss desperta (o círculo ritual, longe da cidade)
function WorldService.getBossPos(): Vector3
	return Wilds.BOSS_POS
end

local function buildSpawn()
	-- remove spawns antigos: eles podem cair dentro do cenário novo
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end
	local sp = Instance.new("SpawnLocation")
	sp.Name = "AnomalySpawn"
	sp.Size = Vector3.new(16, 1, 16)
	sp.CFrame = CFrame.new(SPAWN_POS)
	sp.Anchored = true
	sp.CanCollide = true
	sp.Neutral = true
	sp.Duration = 0
	sp.Color = Build.C.COBBLE
	sp.Material = Enum.Material.Cobblestone
	sp.TopSurface = Enum.SurfaceType.Smooth
	sp.Parent = Build.getRoot()
end

-- Nomes dos efeitos que ESTE arquivo gerencia. Qualquer outro efeito da mesma
-- classe em Lighting é sobra (Toolbox, teste manual antigo) e vai embora.
local MANAGED_FX = {
	AnomalyGrade = true,
	AnomalyBloom = true,
	AnomalySun = true,
	AnomalyDOF = true,
}

-- O Roblox EMPILHA efeitos de pós-processamento da mesma classe. Um Bloom
-- perdido de intensidade 1.0 por cima do nosso de 0.35 lava a cena inteira e
-- some com a gradação — foi exatamente o que aconteceu neste place. Skies
-- duplicados são só peso morto (a engine usa o primeiro). Limpar aqui, e não
-- só na mão no Studio, é o que impede a bagunça de voltar no próximo play.
local function pruneStrayLighting(): string
	local removed = {}
	local seenSky, seenAtmo = false, false

	for _, e in Lighting:GetChildren() do
		local drop = false
		if e:IsA("Sky") then
			drop = seenSky
			seenSky = true
		elseif e:IsA("Atmosphere") then
			drop = seenAtmo
			seenAtmo = true
		elseif e:IsA("BloomEffect") or e:IsA("SunRaysEffect")
			or e:IsA("DepthOfFieldEffect") or e:IsA("ColorCorrectionEffect") then
			drop = not MANAGED_FX[e.Name]
		end
		if drop then
			table.insert(removed, e.Name .. "(" .. e.ClassName .. ")")
			e:Destroy()
		end
	end

	return #removed > 0 and table.concat(removed, ", ") or "nada"
end

local function setupLighting()
	local pruned = pruneStrayLighting()
	if pruned ~= "nada" then
		print("[WorldService] efeitos de luz duplicados removidos: " .. pruned)
	end

	-- luz baixa e fria do norte (a foto da Islândia é a referência exata)
	-- 16h + latitude 64 deixava o sol quase no horizonte: a cena virava noite.
	-- 14h mantém a luz baixa e fria do norte, mas com o mundo visível.
	-- 14h é sol a pino: num mapa coberto de neve isso lava tudo, mata a sombra
	-- longa e achata o relevo. A nota antiga dizia que 16h "virava noite" — mas
	-- isso era com latitude 64. Em 48 o sol de 16h20 fica BAIXO sem sumir: dá
	-- sombra comprida na neve, luz mais quente e contraste de verdade, que é
	-- exatamente o cartão-postal nórdico da referência.
	Lighting.ClockTime = 16.2
	Lighting.GeographicLatitude = 48
	-- Um mapa coberto de neve é quase todo branco, então ele satura o expositor
	-- e a cena inteira lava: montanha vira mancha, muralha perde a face
	-- sombreada e o grade dessaturado simplesmente não aparece. Puxar a
	-- exposição pra baixo é o que devolve separação de valor num mundo branco.
	Lighting.Brightness = 1.75
	Lighting.ExposureCompensation = -0.15
	Lighting.Ambient = Color3.fromRGB(92, 99, 108)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 150, 164)
	Lighting.FogColor = Color3.fromRGB(168, 180, 190)
	Lighting.FogStart = 220
	Lighting.FogEnd = 1400
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4

	-- ATMOSFERA. Isto estava dentro de um `if not existe then criar` — e como o
	-- place JÁ tinha um objeto Atmosphere, nenhuma destas propriedades era
	-- aplicada nunca. O jogo rodava com Haze=0 e Glare=0, ou seja, sem NENHUMA
	-- profundidade atmosférica: montanha a 600 studs com o mesmo contraste de
	-- uma parede a 20. Criar se falta é uma coisa; CONFIGURAR é outra, e tem que
	-- acontecer sempre.
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.36
	atmo.Offset = 0.1
	atmo.Haze = 2.6
	atmo.Glare = 0.25
	atmo.Color = Color3.fromRGB(205, 214, 222)
	atmo.Decay = Color3.fromRGB(118, 132, 146)
	-- NUVENS VOLUMÉTRICAS: talvez o maior ganho de realismo disponível só por
	-- código. Céu chapado é uma das marcas registradas do visual Roblox.
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = terrain
	end
	clouds.Cover = 0.78 -- céu carregado do norte
	clouds.Density = 0.65
	clouds.Color = Color3.fromRGB(198, 204, 212)

	-- CÉU: troca o skybox por um neutro, tira as estrelas e diminui o sol.
	-- Skybox colorido de galáxia é outra marca registrada de jogo Roblox.
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	sky.StarCount = 0
	sky.SunAngularSize = 2.5 -- sol pequeno = leitura mais fotográfica
	sky.MoonAngularSize = 1.5 -- estava 6: uma lua gigante no céu entrega "Roblox"

	-- GRADAÇÃO DE COR mais filmica: sombras frias, meio-tom dessaturado.
	-- Cor chapada e saturada é o que faz tudo parecer plástico.
	if not Lighting:FindFirstChild("AnomalyGrade") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "AnomalyGrade"
		cc.Parent = Lighting
	end
	local grade = Lighting.AnomalyGrade :: ColorCorrectionEffect
	grade.Saturation = -0.24
	grade.Contrast = 0.24
	grade.Brightness = -0.02
	grade.TintColor = Color3.fromRGB(226, 233, 241)
	if not Lighting:FindFirstChild("AnomalyBloom") then
		local b = Instance.new("BloomEffect")
		b.Name = "AnomalyBloom"
		b.Parent = Lighting
	end
	-- Também precisa ser reconfigurado SEMPRE, pelo mesmo motivo da atmosfera.
	-- Threshold 1,9 ainda deixava cada chama de 0,55 stud florescer numa bola
	-- amarela de ~2,5 studs na tela.
	local bloom = Lighting.AnomalyBloom :: BloomEffect
	-- Size 20 fazia uma chama de 0,55 stud florescer numa bola amarela de ~2,5
	-- studs na tela. O halo tem que ser menor que o objeto que o gera, senão a
	-- luz vira mancha e come a geometria em volta.
	bloom.Intensity = 0.12
	bloom.Size = 8
	bloom.Threshold = 2.2

	-- raios de sol atravessando a névoa: é o que dá aquela luz "de filme"
	if not Lighting:FindFirstChild("AnomalySun") then
		local s = Instance.new("SunRaysEffect")
		s.Name = "AnomalySun"
		s.Intensity = 0.12
		s.Spread = 0.9
		s.Parent = Lighting
	end
	-- desfoque leve só no fundo: separa os planos e mata o look "tudo nítido"
	if not Lighting:FindFirstChild("AnomalyDOF") then
		local d = Instance.new("DepthOfFieldEffect")
		d.Name = "AnomalyDOF"
		d.FarIntensity = 0.28
		d.NearIntensity = 0
		d.FocusDistance = 55
		d.InFocusRadius = 180
		d.Parent = Lighting
	end

	-- SOMBRAS REALISTAS.
	-- 'Lighting.Technology' foi descontinuada (jan/2025) e substituída por
	-- 'LightingStyle': o antigo 'Future' agora é 'Realistic'.
	--
	-- Rodamos em task.spawn de propósito: trocar o modo de luz faz o engine
	-- recompilar a cena inteira, e foi isso que travou a construção em
	-- "9/9 luz...". Fora do caminho crítico, ele pode demorar à vontade.
	task.spawn(function()
		local ok = pcall(function()
			Lighting.LightingStyle = Enum.LightingStyle.Realistic
		end)
		if not ok then
			-- fallback pra versões antigas do engine
			pcall(function()
				Lighting.Technology = Enum.Technology.Future
			end)
		end
	end)
end

-- água do fiorde e vegetação do terreno
local function setupTerrainLook()
	local t = workspace.Terrain
	t.WaterColor = Color3.fromRGB(38, 62, 78)
	t.WaterTransparency = 0.72
	t.WaterReflectance = 0.35
	t.WaterWaveSize = 0.18
	t.WaterWaveSpeed = 12
	-- (Terrain.Decoration não existe nesta versão da engine — tentar setar
	-- derrubava a etapa inteira de água/decoração)
end

-- Constrói o mundo inteiro. Usado tanto em runtime quanto no "bake" (modo de
-- edição), por isso não faz nada que dependa de jogador.
local function buildWorld(): Folder
	local old = workspace:FindFirstChild("AnomalyWorld")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "AnomalyWorld"
	root.Parent = workspace
	Build.setRoot(root)

	local bp = workspace:FindFirstChild("Baseplate")
	if bp then
		bp:Destroy()
	end

	-- TODAS as etapas isoladas — inclusive terreno, água e spawn. Antes elas
	-- ficavam fora do pcall: se uma estourasse, o Start morria em silêncio e
	-- sobrava só a paisagem, sem cidade e sem relatório.
	local steps: { { name: string, fn: () -> () } } = {
		{ name = "terreno", fn = Terra.build },
		{ name = "agua/deco", fn = setupTerrainLook },
		{ name = "spawn", fn = buildSpawn },
		{ name = "muralha", fn = Walls.build },
		{ name = "cidade", fn = Town.build },
		{ name = "porto", fn = Harbor.build },
		{ name = "selvagem", fn = Wilds.build },
		{
			name = "modelos",
			fn = function()
				Assets.populate(Town.GATE_Z, Town.KEEP_Z)
			end,
		},
		{ name = "luz", fn = setupLighting },
	}

	-- Se alguma etapa travar (não der erro, só nunca terminar), marca no rodapé
	-- em qual ela ficou presa. Sem isto, um travamento fica mudo pra sempre.
	task.delay(30, function()
		local info = tostring(ReplicatedStorage:GetAttribute("AW_WorldInfo") or "")
		if string.find(info, "%.%.%.", 1) then
			pcall(function()
				ReplicatedStorage:SetAttribute("AW_WorldInfo", info .. "  <<< TRAVOU AQUI")
			end)
		end
	end)

	-- Publica o progresso A CADA etapa. Se a construção parar no meio, o rodapé
	-- mostra exatamente qual etapa foi a última — sem precisar do Output.
	for i, step in steps do
		pcall(function()
			ReplicatedStorage:SetAttribute(
				"AW_WorldInfo",
				("%s | %d/%d %s..."):format(Constants.BUILD_ID, i, #steps, step.name)
			)
		end)

		local before = #root:GetDescendants()
		local ok, err = pcall(step.fn)
		local made = #root:GetDescendants() - before

		if ok then
			print(("[WorldService] %-10s OK   +%d pecas"):format(step.name, made))
		else
			warn(("[WorldService] %-10s FALHOU: %s"):format(step.name, tostring(err)))
			pcall(function()
				ReplicatedStorage:SetAttribute(
					"AW_WorldInfo",
					("%s | %s FALHOU: %s"):format(
						Constants.BUILD_ID,
						step.name,
						string.sub(tostring(err), 1, 120)
					)
				)
			end)
			task.wait(4) -- segura na tela pra dar tempo de ler
		end
	end

	-- avisa (só no Output) se sobrou algo estranho e enorme no Workspace —
	-- modelo inserido pela Toolbox fica salvo no lugar e engole o mapa
	pcall(function()
		for _, child in workspace:GetChildren() do
			local isChar = false
			for _, p in Players:GetPlayers() do
				if p.Character == child then
					isChar = true
				end
			end
			if child ~= root and not child:IsA("Terrain") and not child:IsA("Camera") and not isChar then
				local size: Vector3? = nil
				if child:IsA("Model") then
					local okSize, s = pcall(function()
						return child:GetExtentsSize()
					end)
					size = okSize and s or nil
				elseif child:IsA("BasePart") then
					size = child.Size
				end
				if size and math.max(size.X, size.Y, size.Z) > 400 then
					warn(
						("[WorldService] objeto GIGANTE no Workspace: %s (%s) %.0fx%.0fx%.0f — apague"):format(
							child.Name,
							child.ClassName,
							size.X,
							size.Y,
							size.Z
						)
					)
				end
			end
		end
	end)

	-- Publica um resumo do que foi construído. O HUD mostra isso num cantinho,
	-- então dá pra confirmar DENTRO DO JOGO qual versão do código rodou e se os
	-- modelos externos entraram — sem depender da janela de Output.
	local pieces = #root:GetDescendants()
	-- protegido: um erro aqui não pode derrubar a construção inteira
	pcall(function()
		local tech = "?"
		pcall(function()
			tech = tostring(Lighting.LightingStyle):gsub("Enum%.LightingStyle%.", "")
		end)
		local assetInfo = Assets.statusLine()
		ReplicatedStorage:SetAttribute(
			"AW_WorldInfo",
			("%s | %d pecas | %s | luz %s"):format(Constants.BUILD_ID, pieces, assetInfo, tech)
		)
	end)

	print(("[WorldService] mundo pronto — %d pecas"):format(pieces))
	return root
end

-- ========================================================================
-- BAKE: gera a cidade no MODO DE EDIÇÃO, pra ela virar geometria de verdade
-- que vocês podem mexer com a mão no Studio.
--
-- Como usar: no Studio (jogo PARADO), abra a barra de comandos
--   (View > Command Bar) e cole:
--
--   require(game.ServerScriptService.Services.WorldService).Bake()
--
-- Depois é só salvar o lugar. A partir daí a cidade existe no arquivo e o
-- gerador NÃO reconstrói mais no Play (senão apagaria suas edições).
-- Pra voltar a gerar do zero: apague a pasta AnomalyWorld e dê Play.
-- ========================================================================
function WorldService.Bake()
	local root = buildWorld()
	root:SetAttribute("Baked", true)
	print("[WorldService] BAKE pronto. A cidade agora é editável no Studio.")
	print("[WorldService] Salve o lugar (Ctrl+S). O Play não vai mais regerar.")
	return root
end

function WorldService.Start()
	local existing = workspace:FindFirstChild("AnomalyWorld")

	if existing and existing:GetAttribute("Baked") then
		-- cidade já existe no arquivo do lugar: NÃO reconstrói, senão apagaria
		-- tudo que foi editado à mão. Só liga o que é de runtime.
		Build.setRoot(existing)
		print("[WorldService] cidade 'baked' encontrada — preservando edições manuais")
		pcall(setupLighting)
		pcall(setupTerrainLook)
	else
		buildWorld()
	end

	-- rede de segurança: enterrado ou caindo volta pra cidade
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and hrp.Position.Y < -6 then
					hrp.CFrame = WorldService.getSpawnCFrame()
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

return WorldService
