--!strict
-- CameraController.lua  (CLIENTE)
-- Lock-on estilo souls-like (inspirado no Dueling Grounds):
--   - Câmera livre normal (mouse) por padrão.
--   - Tecla R  -> trava no inimigo mais próximo/ao centro da tela.
--   - Travado: a câmera enquadra você + o alvo, e seu personagem sempre encara
--     o alvo (então os golpes e poderes miram nele). Anda de lado = strafe.
--   - Destrava sozinho se o alvo morrer, sumir ou ficar longe demais. R de novo alterna.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local StateUpdate = Net.get("StateUpdate")

local player = Players.LocalPlayer

local CameraController = {}

local LOCK_RANGE = 90        -- distância máxima pra travar
local UNLOCK_RANGE = 120     -- solta o lock se passar disso
local CAM_DISTANCE = 13      -- quão atrás a câmera fica
local CAM_HEIGHT = 6

-- FOV. O padrão do Roblox (70) é grande-angular e achata a perspectiva — é um
-- dos motivos de todo jogo da plataforma "parecer Roblox". 65 lê mais cinema.
-- Correr abre um pouco: o olho lê isso como velocidade sem precisar de blur.
local BASE_FOV = 65
local SPRINT_FOV = 72
local FOV_LERP = 6 -- por segundo; suave o bastante pra não embrulhar o estômago

local locked: Model? = nil
local reticle: BillboardGui? = nil
local facingSuppressedUntil = 0 -- durante dash/impulso não forçamos a rotação
local sprinting = false -- verdade do SERVIDOR (via StateUpdate), não do teclado

local function getChar(): (Model?, BasePart?, Humanoid?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	return char, hrp, hum
end

local function targetRoot(t: Model?): BasePart?
	if not t or not t.Parent then
		return nil
	end
	local hum = t:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return t:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- cria o marcador visual no alvo travado
local function makeReticle(): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "LockReticle"
	bb.Size = UDim2.fromOffset(44, 44)
	bb.AlwaysOnTop = true
	local img = Instance.new("TextLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Font = Enum.Font.GothamBlack
	img.Text = "◈"
	img.TextScaled = true
	img.TextColor3 = Color3.fromRGB(47, 212, 194)
	img.TextStrokeTransparency = 0.3
	img.Parent = bb
	return bb
end

-- escolhe o melhor alvo: perto do centro da tela e do jogador
local function pickTarget(): Model?
	local _, hrp = getChar()
	if not hrp then
		return nil
	end
	local cam = Workspace.CurrentCamera
	local best: Model? = nil
	local bestScore = math.huge
	local vw = cam.ViewportSize
	local center = Vector2.new(vw.X / 2, vw.Y / 2)

	for _, enemy in CollectionService:GetTagged("Enemy") do
		local ehrp = targetRoot(enemy)
		if ehrp then
			local d = (ehrp.Position - hrp.Position).Magnitude
			if d <= LOCK_RANGE then
				local sp, onScreen = cam:WorldToViewportPoint(ehrp.Position)
				if onScreen then
					local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					local score = screenDist + d * 4 -- prioriza o que está no centro da mira
					if score < bestScore then
						bestScore = score
						best = enemy
					end
				end
			end
		end
	end
	return best
end

local function unlock()
	locked = nil
	if reticle then
		reticle.Parent = nil
	end
	local _, _, hum = getChar()
	if hum then
		hum.AutoRotate = true
	end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function toggleLock()
	if locked then
		unlock()
	else
		local t = pickTarget()
		if t then
			locked = t
			if not reticle then
				reticle = makeReticle()
			end
			local ehrp = targetRoot(t)
			if reticle and ehrp then
				reticle.Adornee = ehrp
				reticle.Parent = player:WaitForChild("PlayerGui")
			end
		end
	end
end

-- atualização de câmera + orientação por frame
local function onRender(dt: number)
	-- FOV acompanha a corrida. O alvo vem do SERVIDOR: se ele recusou a corrida
	-- (sem stamina, de guarda alta), a câmera não abre. A câmera nunca mente.
	local camera = Workspace.CurrentCamera
	if camera then
		local goal = sprinting and SPRINT_FOV or BASE_FOV
		if math.abs(camera.FieldOfView - goal) > 0.05 then
			camera.FieldOfView += (goal - camera.FieldOfView) * math.clamp(dt * FOV_LERP, 0, 1)
		end
	end

	if not locked then
		return
	end
	local _, hrp, hum = getChar()
	-- morreu / sem personagem: solta o lock e devolve a câmera normal
	if not (hrp and hum) or hum.Health <= 0 then
		unlock()
		return
	end
	local tpos = targetRoot(locked)
	if not tpos then
		unlock()
		return
	end
	if (tpos.Position - hrp.Position).Magnitude > UNLOCK_RANGE then
		unlock()
		return
	end

	-- personagem encara o alvo (só yaw), pra golpes/poderes mirarem nele.
	-- durante um dash a gente NÃO reescreve o CFrame (isso mataria o impulso).
	hum.AutoRotate = false
	if os.clock() >= facingSuppressedUntil then
		local faceAt = Vector3.new(tpos.Position.X, hrp.Position.Y, tpos.Position.Z)
		if (faceAt - hrp.Position).Magnitude > 0.1 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, faceAt)
		end
	end

	-- câmera atrás do jogador, enquadrando os dois
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local dir = (tpos.Position - hrp.Position)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		flat = hrp.CFrame.LookVector
	end
	flat = flat.Unit
	local camPos = hrp.Position - flat * CAM_DISTANCE + Vector3.new(0, CAM_HEIGHT, 0)
	local focus = (hrp.Position + tpos.Position) / 2 + Vector3.new(0, 2, 0)
	cam.CFrame = CFrame.lookAt(camPos, focus)

	-- reticle acompanha (troca de alvo se o atual morreu tratado acima)
	if reticle then
		reticle.Adornee = tpos
	end
end

function CameraController.Start()
	pcall(function()
		Workspace.CurrentCamera.FieldOfView = BASE_FOV
	end)

	-- o servidor é quem diz se estamos correndo
	StateUpdate.OnClientEvent:Connect(function(data)
		sprinting = data.sprinting == true
	end)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = Workspace.CurrentCamera
		if cam then
			cam.FieldOfView = BASE_FOV
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			toggleLock()
		end
	end)

	player.CharacterRemoving:Connect(unlock)
	player.CharacterAdded:Connect(function()
		-- renasceu: garante câmera livre normal
		locked = nil
		if reticle then
			reticle.Parent = nil
		end
		Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end)
	RunService:BindToRenderStep("AnomalyLockCam", Enum.RenderPriority.Camera.Value + 1, onRender)

	print("[CameraController] pronto — R para lock-on")
end

-- exposto pra outros controllers saberem o alvo travado (ex.: mirar poderes)
function CameraController.getLocked(): Model?
	return locked
end

-- chamado ao dar dash: solta a rotação forçada por um instante pro impulso valer
function CameraController.suppressFacing(duration: number?)
	facingSuppressedUntil = os.clock() + (duration or 0.35)
end

return CameraController
