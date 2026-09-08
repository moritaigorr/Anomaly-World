--!strict
-- MovementService.lua  (SERVIDOR)
-- Esquiva (Shift): custa stamina, dá impulso e concede i-frames.
-- Também regenera stamina de todo mundo.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)

local DashRequest = Net.get("DashRequest")
local BlockRequest = Net.get("BlockRequest")

local MovementService = {}

local function onBlock(player: Player, down: boolean)
	local s = PlayerState.get(player)
	if not s then
		return
	end
	if os.clock() < s.stunUntil then
		return -- atordoado: não consegue levantar a guarda
	end
	if down and not s.blocking then
		s.blockStart = os.clock() -- inicia a janela de parry
	end
	s.blocking = down == true

	-- bloqueando = anda devagar (peso do souls-like)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = s.blocking and 8 or 16
	end
end

local function onDash(player: Player, direction: Vector3?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local s = PlayerState.get(player)
	if not (hrp and s) then
		return
	end

	local now = os.clock()
	if now < s.stunUntil then
		return -- guarda quebrada: não pode esquivar
	end
	if now < s.dashCdUntil or s.stamina < Constants.Dash.StaminaCost then
		return
	end

	s.stamina -= Constants.Dash.StaminaCost
	s.dashCdUntil = now + Constants.Dash.Cooldown
	s.iframeUntil = now + Constants.Dash.IFrames
	-- NÃO aplicamos velocidade aqui: o personagem é controlado pelo cliente, então
	-- um impulso do servidor é sobrescrito pela física dele. O cliente dá o impulso;
	-- o servidor mantém a autoridade do que importa (stamina e i-frames).
end

function MovementService.Start()
	DashRequest.OnServerEvent:Connect(onDash)
	BlockRequest.OnServerEvent:Connect(onBlock)

	-- regen de stamina
	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local s = PlayerState.get(player)
			if s then
				s.stamina = math.min(
					Constants.Player.MaxStamina,
					s.stamina + Constants.Player.StaminaRegenPerSec * dt
				)
				-- guarda (posture) volta quando você para de apanhar
				if os.clock() - s.postureHitAt >= Constants.Posture.RegenDelay then
					s.posture = math.min(
						Constants.Posture.Max,
						s.posture + Constants.Posture.RegenPerSec * dt
					)
				end
			end
		end
	end)

	print("[MovementService] pronto")
end

return MovementService
