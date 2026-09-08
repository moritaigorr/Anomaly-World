--!strict
-- AnimController.lua  (CLIENTE)
-- Toca as animações do jogador. Lê os IDs de AnimData; se o id estiver vazio,
-- não faz nada (então funciona antes de você ter qualquer animação).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimData = require(ReplicatedStorage.Shared.AnimData)

local player = Players.LocalPlayer

local AnimController = {}
local tracks: { [string]: AnimationTrack } = {}
local loadedFor: Instance? = nil

local function getAnimator(): Animator?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	return hum:FindFirstChildOfClass("Animator")
end

-- carrega (uma vez por personagem) todas as animações com id preenchido
local function ensureLoaded()
	local char = player.Character
	if not char or loadedFor == char then
		return
	end
	local animator = getAnimator()
	if not animator then
		return
	end
	loadedFor = char
	tracks = {}
	for name, id in AnimData do
		if type(id) == "string" and id ~= "" then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(anim)
			end)
			if ok and track then
				tracks[name] = track
			end
		end
	end
end

-- toca uma animação pelo nome (ex.: "swing1", "dodge", "powerZ")
function AnimController.play(name: string)
	ensureLoaded()
	local track = tracks[name]
	if track then
		track:Play(0.08)
	end
end

function AnimController.Start()
	ensureLoaded()
	player.CharacterAdded:Connect(function()
		loadedFor = nil
		task.wait(0.3)
		ensureLoaded()
	end)
	print("[AnimController] pronto (IDs em ReplicatedStorage/Shared/AnimData)")
end

return AnimController
