--!strict
-- HealthService.lua  (SERVIDOR)
-- Cura passiva: se o jogador não toma dano por alguns segundos, a vida regenera.
-- Também marca o momento do último dano (usado pelo regen).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local HealthService = {}

local lastHit: { [Player]: number } = {}
local lastHealth: { [Player]: number } = {}

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	lastHealth[player] = hum.Health
	lastHit[player] = 0

	hum.HealthChanged:Connect(function(h)
		local prev = lastHealth[player] or h
		if h < prev then
			lastHit[player] = os.clock() -- levou dano agora
		end
		lastHealth[player] = h
	end)
end

function HealthService.Start()
	for _, p in Players:GetPlayers() do
		if p.Character then
			onCharacter(p, p.Character)
		end
		p.CharacterAdded:Connect(function(c)
			onCharacter(p, c)
		end)
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function(c)
			onCharacter(p, c)
		end)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastHit[p] = nil
		lastHealth[p] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
				if now - (lastHit[player] or 0) >= Constants.Player.RegenDelay then
					local newH = math.min(
						hum.MaxHealth,
						hum.Health + Constants.Player.HealthRegenPerSec * dt
					)
					lastHealth[player] = newH -- não conta regen como "dano"
					hum.Health = newH
				end
			end
		end
	end)

	print("[HealthService] pronto")
end

return HealthService
