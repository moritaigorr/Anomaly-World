--!strict
-- CameraController.lua  (CLIENTE)
-- Terceira pessoa clássica, sempre ativa:
--   - Crosshair fixa no centro (sem ponto), cursor preso e invisível.
--   - O mouse gira a câmera E o personagem (yaw) o tempo todo, não só travado.
--   - Tecla R -> trava/destrava no inimigo apontado pela crosshair. Travado,
--     a câmera segue abrindo conforme o alvo se afasta e um reticle marca ele;
--     destravado, é só a câmera de ombro padrão.
--   - Lock se solta sozinho se o alvo morrer, sumir ou ficar longe demais.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local LockUi = require(ReplicatedStorage.Shared.LockUi)

local StateUpdate = Net.get("StateUpdate")

local player = Players.LocalPlayer

local CameraController = {}

local LOCK_RANGE = 90        -- distância máxima pra travar
local UNLOCK_RANGE = 120     -- solta o lock se passar disso
local CAM_DISTANCE = 12      -- distância padrão atrás do jogador
local MAX_CAM_DISTANCE = 20  -- abre conforme os duelistas se afastam, travado
local CAM_HEIGHT = 5
local SHOULDER_OFFSET = 2.5  -- câmera sobre o ombro direito
local CAMERA_SMOOTH = 10     -- rapidez da transição/seguimento
local WALL_PADDING = 0.75    -- margem antes de uma parede
local INITIAL_CURSOR_RADIUS = 220 -- tolerância pra travar com R
local MOUSE_SENSITIVITY = 0.003
local MIN_CAMERA_PITCH = math.rad(-35)
local MAX_CAMERA_PITCH = math.rad(45)

-- FOV. O padrão do Roblox (70) é grande-angular e achata a perspectiva — é um
-- dos motivos de todo jogo da plataforma "parecer Roblox". 65 lê mais cinema.
-- Correr abre um pouco: o olho lê isso como velocidade sem precisar de blur.
local BASE_FOV = 65
local SPRINT_FOV = 72
local FOV_LERP = 6 -- por segundo; suave o bastante pra não embrulhar o estômago

local controlActive = false -- câmera+crosshair de 3ª pessoa ligadas (tem personagem vivo)
local locked: Model? = nil
local reticle: BillboardGui? = nil
local facingSuppressedUntil = 0 -- durante dash/impulso não forçamos a rotação
local sprinting = false -- verdade do SERVIDOR (via StateUpdate), não do teclado
local smoothedCFrame: CFrame? = nil
local cameraYaw = 0
local cameraPitch = 0

local function resolveCollision(
	origin: Vector3,
	desiredPosition: Vector3,
	hitDistance: number?,
	padding: number
): Vector3
	if hitDistance == nil then
		return desiredPosition
	end
	local offset = desiredPosition - origin
	local distance = offset.Magnitude
	if distance < 0.001 then
		return origin
	end
	local safeDistance = math.clamp(hitDistance - padding, 0.5, distance)
	return origin + offset.Unit * safeDistance
end

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

-- escolhe o inimigo mais próximo da crosshair (sempre no centro da tela)
local function pickTarget(screenPoint: Vector2, maxScreenDistance: number): Model?
	local _, hrp = getChar()
	if not hrp then
		return nil
	end
	local cam = Workspace.CurrentCamera
	local best: Model? = nil
	local bestScore = math.huge

	for _, enemy in CollectionService:GetTagged("Enemy") do
		local ehrp = targetRoot(enemy)
		if ehrp then
			local d = (ehrp.Position - hrp.Position).Magnitude
			if d <= LOCK_RANGE then
				local sp, onScreen = cam:WorldToViewportPoint(ehrp.Position)
				if onScreen then
					local screenDist = (Vector2.new(sp.X, sp.Y) - screenPoint).Magnitude
					if screenDist <= maxScreenDistance then
						local score = screenDist + d * 0.25
						if score < bestScore then
							bestScore = score
							best = enemy
						end
					end
				end
			end
		end
	end
	return best
end

-- inimigo vivo mais próximo do jogador, sem depender de onde a câmera aponta
-- (usado pra retravar sozinho quando o alvo travado morre)
local function pickNearestEnemy(hrp: BasePart): Model?
	local best: Model? = nil
	local bestDist = math.huge
	for _, enemy in CollectionService:GetTagged("Enemy") do
		local ehrp = targetRoot(enemy)
		if ehrp then
			local d = (ehrp.Position - hrp.Position).Magnitude
			if d <= LOCK_RANGE and d < bestDist then
				bestDist = d
				best = enemy
			end
		end
	end
	return best
end

local function clearLock()
	locked = nil
	if reticle then
		reticle.Parent = nil
	end
end

-- ativa a câmera/crosshair de 3ª pessoa (chamado ao nascer)
local function activateControl()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	LockUi.setActive(playerGui, true)
	local cam = Workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	cameraYaw = math.atan2(-look.X, -look.Z)
	cameraPitch = math.asin(math.clamp(look.Y, -1, 1))
	smoothedCFrame = nil
	controlActive = true
end

-- desativa (personagem morreu/saiu) e devolve o mouse solto
local function deactivateControl()
	controlActive = false
	clearLock()
	smoothedCFrame = nil
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		LockUi.setActive(playerGui, false)
	end
	local _, _, hum = getChar()
	if hum then
		hum.AutoRotate = true
	end
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function toggleLock()
	if not controlActive then
		return
	end
	if locked then
		clearLock()
		return
	end
	local cam = Workspace.CurrentCamera
	local viewportCenter = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	local t = pickTarget(viewportCenter, INITIAL_CURSOR_RADIUS)
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

	local _, hrp, hum = getChar()
	if not controlActive then
		-- autocorreção: se por alguma corrida de spawn o CharacterAdded passou
		-- batido (câmera solta, sem crosshair), religa sozinho assim que
		-- encontrar um personagem vivo, sem precisar esperar o próximo spawn.
		if hrp and hum and hum.Health > 0 then
			activateControl()
		else
			return
		end
	end
	-- morreu / sem personagem: solta o controle e devolve o mouse
	if not (hrp and hum) or hum.Health <= 0 then
		deactivateControl()
		return
	end

	-- resolve o alvo travado ANTES de decidir pra onde a câmera olha
	local tpos: BasePart? = nil
	if locked then
		tpos = targetRoot(locked)
		if tpos and (tpos.Position - hrp.Position).Magnitude > UNLOCK_RANGE then
			tpos = nil
		end
		if not tpos then
			-- alvo morreu ou sumiu: tenta travar sozinho no bicho vivo mais perto
			local nextEnemy = pickNearestEnemy(hrp)
			if nextEnemy then
				locked = nextEnemy
				tpos = targetRoot(locked)
			else
				clearLock()
			end
		end
		if tpos and reticle then
			reticle.Adornee = tpos
			if reticle.Parent == nil then
				reticle.Parent = player:WaitForChild("PlayerGui")
			end
		end
	end

	local orbitRotation: CFrame
	local facingDir: Vector3
	if tpos then
		-- travado de verdade: câmera e personagem SEMPRE encaram o alvo, sem
		-- depender do mouse. É isso que faz o lock parecer sólido — o mouse só
		-- volta a mandar na câmera quando o R solta.
		local delta = tpos.Position - hrp.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude < 0.001 then
			flat = hrp.CFrame.LookVector
		end
		flat = flat.Unit
		facingDir = flat
		local dist3 = math.max(delta.Magnitude, 0.001)
		cameraYaw = math.atan2(-flat.X, -flat.Z)
		cameraPitch = math.clamp(math.asin(math.clamp(delta.Y / dist3, -1, 1)), MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
		orbitRotation = CFrame.fromOrientation(cameraPitch, cameraYaw, 0)
	else
		-- livre: o mouse manda o tempo todo, não só quando destravado à toa
		local mouseDelta = UserInputService:GetMouseDelta()
		cameraYaw -= mouseDelta.X * MOUSE_SENSITIVITY
		cameraPitch = math.clamp(cameraPitch - mouseDelta.Y * MOUSE_SENSITIVITY, MIN_CAMERA_PITCH, MAX_CAMERA_PITCH)
		orbitRotation = CFrame.fromOrientation(cameraPitch, cameraYaw, 0)
		facingDir = orbitRotation.LookVector
	end
	local lookVector = orbitRotation.LookVector

	-- personagem sempre encara pra onde decidimos acima (só yaw). Durante um
	-- dash a gente NÃO reescreve o CFrame (isso mataria o impulso).
	hum.AutoRotate = false
	if os.clock() >= facingSuppressedUntil then
		local flatFacing = Vector3.new(facingDir.X, 0, facingDir.Z)
		if flatFacing.Magnitude > 0.1 then
			hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatFacing.Unit)
		end
	end

	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable

	-- travado: a crosshair sai do centro e vai pra cima do bicho na tela
	if tpos then
		local screenPoint, onScreen = cam:WorldToViewportPoint(tpos.Position)
		LockUi.setTargetPosition(onScreen and Vector2.new(screenPoint.X, screenPoint.Y) or nil)
	else
		LockUi.setTargetPosition(nil)
	end

	local distance = CAM_DISTANCE
	if tpos then
		local separation = (tpos.Position - hrp.Position).Magnitude
		distance = math.clamp(CAM_DISTANCE + separation * 0.12, CAM_DISTANCE, MAX_CAM_DISTANCE)
	end
	local pivot = hrp.Position + Vector3.new(0, CAM_HEIGHT, 0)
	local desiredPosition = pivot - lookVector * distance + orbitRotation.RightVector * SHOULDER_OFFSET

	local collisionOrigin = hrp.Position + Vector3.new(0, 3, 0)
	local rayDirection = desiredPosition - collisionOrigin
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { hrp.Parent, locked }
	rayParams.IgnoreWater = true
	local hit = Workspace:Raycast(collisionOrigin, rayDirection, rayParams)
	local safePosition = resolveCollision(
		collisionOrigin,
		desiredPosition,
		hit and hit.Distance or nil,
		WALL_PADDING
	)

	local desiredCFrame = CFrame.lookAt(safePosition, safePosition + lookVector)
	local alpha = 1 - math.exp(-CAMERA_SMOOTH * dt)
	smoothedCFrame = (smoothedCFrame or cam.CFrame):Lerp(desiredCFrame, alpha)
	cam.CFrame = smoothedCFrame
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

	player.CharacterRemoving:Connect(deactivateControl)
	player.CharacterAdded:Connect(activateControl)
	if player.Character then
		activateControl()
	end
	RunService:BindToRenderStep("AnomalyLockCam", Enum.RenderPriority.Camera.Value + 1, onRender)

	print("[CameraController] pronto — 3ª pessoa com mouse sempre no controle, R trava no alvo")
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
