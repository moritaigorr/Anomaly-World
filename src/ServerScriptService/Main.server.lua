-- Main.server.lua  (SERVIDOR)
-- Ponto de entrada do servidor. Inicializa o estado dos jogadores e liga os serviços.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

-- Sinal MAIS CEDO possível: se o rodapé mostrar isto, o servidor está rodando
-- o código novo. Se continuar em "aguardando", nem o Main novo chegou ao Studio.
ReplicatedStorage:SetAttribute("AW_WorldInfo", Constants.BUILD_ID .. " | main iniciou")

local Services = script.Parent.Services
local PlayerState = require(Services.PlayerState)
local DataService = require(Services.DataService)

-- NINGUÉM nasce antes do mundo existir (senão cai no vazio / dentro do cenário)
Players.CharacterAutoLoads = false

local WorldService = require(Services.WorldService)

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.MaxHealth = Constants.Player.MaxHealth
	hum.Health = Constants.Player.MaxHealth
	PlayerState.resetCombat(player) -- guarda cheia, sem stun, ao renascer

	-- posiciona no ponto de nascimento medindo o chão por raycast (e reconfere
	-- depois, porque o Roblox reposiciona o personagem logo após o nascimento)
	char:WaitForChild("HumanoidRootPart", 5)
	WorldService.placeCharacter(char)
end

local function onPlayer(player: Player)
	PlayerState.init(player)
	DataService.load(player) -- carrega o progresso salvo por cima do estado inicial
	if player.Character then
		onCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end

-- liga os serviços de forma resiliente: se um falhar, os outros continuam
-- e o erro aparece nomeado no Output (não derruba o servidor inteiro).
local function startService(name: string)
	local ok, err = pcall(function()
		require(Services[name]).Start()
	end)
	if not ok then
		warn("[Anomaly World] FALHA ao iniciar " .. name .. ": " .. tostring(err))
	end
end

startService("WorldService") -- primeiro: o chão e o spawn precisam existir

-- mundo pronto: agora sim pode nascer gente
Players.CharacterAutoLoads = true
for _, p in Players:GetPlayers() do
	if not p.Character then
		p:LoadCharacter()
	end
end

startService("DataService")
startService("CombatService")
startService("MovementService")
startService("CoreService")
startService("EnemyService")
startService("BossService")
startService("HealthService")
startService("StateService")

print("[Anomaly World] servidor iniciado — Marco 0")
