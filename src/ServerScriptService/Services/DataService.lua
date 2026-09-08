--!strict
-- DataService.lua  (SERVIDOR)
-- Persistência do progresso (money, mastery, inventário, abates de boss).
--
-- NOTA: esta é uma versão simplificada baseada em DataStore direto, boa pro Marco 1.
-- Para produção, troque por ProfileService (session-locking evita item duplicado
-- entre servidores e perda por corrida). A interface abaixo já foi desenhada pra
-- essa troca ser fácil: só load()/save() mudam por dentro.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PlayerState = require(script.Parent.PlayerState)

local DataService = {}

local STORE_NAME = "AnomalyWorld_Save_v1"
local AUTOSAVE_INTERVAL = 60

local store: DataStore? = nil
local loaded: { [Player]: boolean } = {}

-- em Studio sem API Services ligado, DataStore lança erro; a gente segue sem salvar
local ok = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not ok then
	warn("[DataService] DataStore indisponivel (ative API Services no Studio). Rodando sem salvar.")
end

local function keyFor(player: Player): string
	return "player_" .. tostring(player.UserId)
end

-- aplica os dados salvos no estado em memória
local function apply(player: Player, data: { [string]: any })
	local s = PlayerState.get(player)
	if not s then
		return
	end
	s.money = tonumber(data.money) or s.money
	s.mastery = tonumber(data.mastery) or s.mastery
	s.bossKills = tonumber(data.bossKills) or s.bossKills
	if type(data.inventory) == "table" then
		s.inventory = data.inventory
	end
	if type(data.database) == "table" then
		s.database = data.database
	end
	if type(data.equippedCore) == "string" then
		s.equippedCore = data.equippedCore
	end
end

-- monta a tabela a salvar a partir do estado atual
local function snapshot(player: Player): { [string]: any }?
	local s = PlayerState.get(player)
	if not s then
		return nil
	end
	return {
		money = s.money,
		mastery = s.mastery,
		bossKills = s.bossKills,
		inventory = s.inventory,
		database = s.database,
		equippedCore = s.equippedCore,
	}
end

function DataService.load(player: Player)
	if not store then
		loaded[player] = true
		return
	end
	local success, data = pcall(function()
		return (store :: DataStore):GetAsync(keyFor(player))
	end)
	if success and type(data) == "table" then
		apply(player, data)
	elseif not success then
		warn("[DataService] falha ao carregar " .. player.Name .. ": " .. tostring(data))
	end
	loaded[player] = true
end

-- No Studio sem "Enable Studio Access to API Services" TODA chamada falha.
-- Sem isto o console vira spam de 403 e esconde os erros que importam.
local apiBlocked = false

function DataService.save(player: Player)
	if not store or not loaded[player] or apiBlocked then
		return -- nunca salve por cima antes de ter carregado (evita zerar progresso)
	end
	local snap = snapshot(player)
	if not snap then
		return
	end
	local success, err = pcall(function()
		local ds = store :: DataStore
		ds:UpdateAsync(keyFor(player), function()
			return snap
		end)
	end)
	if not success then
		local msg = tostring(err)
		if string.find(msg, "API") or string.find(msg, "403") or string.find(msg, "not allowed") then
			apiBlocked = true
			warn(
				"[DataService] DataStore bloqueado no Studio — save desligado nesta sessao. "
					.. "Para ligar: Game Settings > Security > Enable Studio Access to API Services"
			)
		else
			warn("[DataService] falha ao salvar " .. player.Name .. ": " .. msg)
		end
	end
end

function DataService.Start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		loaded[player] = nil
	end)

	-- autosave periódico
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				DataService.save(player)
			end
		end
	end)

	-- salva todo mundo no fechamento do servidor
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in Players:GetPlayers() do
			DataService.save(player)
		end
		task.wait(2)
	end)

	print("[DataService] pronto")
end

return DataService
