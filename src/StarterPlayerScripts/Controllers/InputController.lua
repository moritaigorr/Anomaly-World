--!strict
-- InputController.lua  (CLIENTE)
-- Captura o input e PEDE ao servidor. Não decide nada de dano — só comunica
-- intenção e dispara o feedback local (previsão) pra sensação de resposta imediata.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local AttackRequest = Net.get("AttackRequest")
local DashRequest = Net.get("DashRequest")
local PowerRequest = Net.get("PowerRequest")
local BlockRequest = Net.get("BlockRequest")
local HeavyRequest = Net.get("HeavyRequest")
local UltimateRequest = Net.get("UltimateRequest")
local SwapCoreRequest = Net.get("SwapCoreRequest")

local player = Players.LocalPlayer

local InputController = {}
local CombatController -- injetado no Start pra evitar require circular
local AnimController
local CameraController
local HudController

local POWER_KEYS = {
	[Enum.KeyCode.Z] = "Z",
	[Enum.KeyCode.X] = "X",
	[Enum.KeyCode.C] = "C",
	[Enum.KeyCode.V] = "V",
}

local function moveDirection(): Vector3
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude > 0 then
		return hum.MoveDirection
	end
	-- sem input de movimento: usa a frente da câmera achatada
	local look = Workspace.CurrentCamera.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z)
end

local function attack()
	AttackRequest:FireServer()
	if CombatController then
		CombatController.predictSwing() -- feedback imediato no cliente
	end
end

function InputController.Start(deps)
	CombatController = deps.CombatController
	AnimController = deps.AnimController
	CameraController = deps.CameraController
	HudController = deps.HudController

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			attack()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			-- segurar botão direito = bloquear (tap no tempo certo = parry)
			BlockRequest:FireServer(true)
			if CombatController then
				CombatController.setBlocking(true) -- escudo visual
			end
		elseif input.KeyCode == Enum.KeyCode.T then
			SwapCoreRequest:FireServer() -- troca de Anomaly Core
		elseif input.KeyCode == Enum.KeyCode.B then
			if HudController then
				HudController.toggleDatabase() -- Anomaly Database
			end
		elseif input.KeyCode == Enum.KeyCode.F then
			-- ataque pesado: quebra a guarda do inimigo
			HeavyRequest:FireServer()
			if AnimController then
				AnimController.play("heavy")
			end
		elseif input.KeyCode == Enum.KeyCode.G then
			UltimateRequest:FireServer()
			if AnimController then
				AnimController.play("ultimate")
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			local dir = moveDirection()
			DashRequest:FireServer(dir) -- servidor: stamina + i-frames
			if CameraController then
				CameraController.suppressFacing(0.35) -- deixa o impulso acontecer
			end
			-- o impulso é aplicado AQUI (o cliente é dono do personagem)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and dir.Magnitude > 0 then
				hrp.AssemblyLinearVelocity = dir.Unit * 70 + Vector3.new(0, 12, 0)
			end
			if AnimController then
				AnimController.play("dodge")
			end
		else
			local key = POWER_KEYS[input.KeyCode]
			if key then
				-- manda o alvo travado junto (o servidor valida antes de usar)
				local lockTarget = CameraController and CameraController.getLocked() or nil
				PowerRequest:FireServer(key, lockTarget)
				if key == "Z" and CameraController then
					CameraController.suppressFacing(0.35) -- Thunder Dash precisa do impulso
				end
				if AnimController then
					AnimController.play("power" .. key)
				end
			end
		end
	end)

	-- soltar o botão direito para de bloquear
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			BlockRequest:FireServer(false)
			if CombatController then
				CombatController.setBlocking(false)
			end
		end
	end)

	print(
		"[InputController] pronto — M1 leve · F pesado · G ultimate · Q esquiva · "
			.. "botão direito bloqueia/parry · Z/X/C/V poderes · R lock-on"
	)
end

return InputController
