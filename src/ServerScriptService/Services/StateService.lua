--!strict
-- StateService.lua  (SERVIDOR)
-- Manda o estado do jogador pro HUD (HP, stamina, cooldowns dos poderes) ~10x/s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreData = require(ReplicatedStorage.Shared.CoreData)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)

local StateUpdate = Net.get("StateUpdate")

local StateService = {}

local KEYS = { "Z", "X", "C", "V" }

function StateService.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local s = PlayerState.get(player)
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if s and hum then
					local core = CoreData[s.equippedCore]
					local cds = {}
					for _, key in KEYS do
						local ability = core and core.habilidades[key]
						local remain = (s.cooldowns[key] or 0) - now
						cds[key] = {
							name = ability and ability.nome or key,
							remain = math.max(0, remain),
							total = ability and ability.cooldown or 0,
						}
					end
					StateUpdate:FireClient(player, {
						hp = hum.Health,
						maxHp = hum.MaxHealth,
						stamina = s.stamina,
						maxStamina = Constants.Player.MaxStamina,
						formActive = now < s.formBuffUntil,
						money = s.money,
						bossKills = s.bossKills,
						posture = s.posture,
						maxPosture = Constants.Posture.Max,
						ult = s.ultCharge,
						maxUlt = Constants.Ultimate.Max,
						stunned = now < s.stunUntil,
						coreName = core and core.nome or s.equippedCore,
						database = s.database,
						cooldowns = cds,
					})
				end
			end
		end
	end)
	print("[StateService] pronto")
end

return StateService
