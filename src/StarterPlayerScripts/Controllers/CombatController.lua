--!strict
-- CombatController.lua  (CLIENTE)
-- Todo o "game feel": números de dano, hit-stop (punch de câmera), screen shake
-- e VFX dos poderes. É barato e é o que faz o combate parecer bom.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.Shared.Net)
local CombatFeedback = Net.get("CombatFeedback")
local AnimController = require(script.Parent.AnimController)

local CombatController = {}
local shakeAmount = 0
local swingIndex = 0
local lastSwing = 0

-- ---------- toast de aviso (eventos, boss, drops) ----------
local toastGui: ScreenGui? = nil
local function notify(text: string, color: Color3?)
	if not toastGui then
		local player = Players.LocalPlayer
		toastGui = Instance.new("ScreenGui")
		toastGui.Name = "AnomalyToasts"
		toastGui.ResetOnSpawn = false
		toastGui.IgnoreGuiInset = true
		toastGui.Parent = player:WaitForChild("PlayerGui")
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 640, 0, 44)
	label.Position = UDim2.new(0.5, -320, 0, 80)
	label.BackgroundColor3 = Color3.fromRGB(16, 22, 28)
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.Code
	label.TextColor3 = color or Color3.fromRGB(47, 212, 194)
	label.TextScaled = true
	label.Text = text
	label.Parent = toastGui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke", label)
	stroke.Color = color or Color3.fromRGB(47, 212, 194)
	stroke.Thickness = 1.5

	TweenService:Create(label, TweenInfo.new(0.4), { Position = UDim2.new(0.5, -320, 0, 110) }):Play()
	task.delay(3.5, function()
		TweenService:Create(label, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
		stroke.Enabled = false
		Debris:AddItem(label, 0.6)
	end)
end

-- ---------- número de dano flutuante ----------
local function damageNumber(position: Vector3, amount: number, crit: boolean)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position + Vector3.new(math.random(-2, 2), 2, math.random(-2, 2))
	part.Parent = Workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(crit and 5 or 3.5, crit and 2 or 1.5)
	bb.AlwaysOnTop = true
	bb.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = crit and (tostring(amount) .. "!") or tostring(amount)
	label.TextColor3 = crit and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = bb

	TweenService:Create(part, TweenInfo.new(0.8), {
		Position = part.Position + Vector3.new(0, 6, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(part, 0.85)
end

-- ---------- helpers de VFX ----------
local function localChar()
	local p = Players.LocalPlayer
	local c = p.Character
	return c, c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function neon(size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cf
	if shape then
		part.Shape = shape
	end
	part.Parent = Workspace
	return part
end

-- estouro genérico (parry/block)
local function burst(position: Vector3, color: Color3)
	local b = neon(Vector3.one * 2, CFrame.new(position + Vector3.new(0, 3, 0)), color, Enum.PartType.Ball)
	TweenService:Create(b, TweenInfo.new(0.3), { Size = Vector3.one * 14, Transparency = 1 }):Play()
	Debris:AddItem(b, 0.35)
end

-- X: raio caindo do céu no alvo
local function lightningBolt(position: Vector3, color: Color3)
	local bolt = neon(Vector3.new(1.4, 60, 1.4), CFrame.new(position + Vector3.new(0, 30, 0)), color)
	local flash = neon(Vector3.new(3, 3, 3), CFrame.new(position), color, Enum.PartType.Ball)
	TweenService:Create(bolt, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	TweenService:Create(flash, TweenInfo.new(0.3), { Size = Vector3.one * 16, Transparency = 1 }):Play()
	Debris:AddItem(bolt, 0.3)
	Debris:AddItem(flash, 0.35)
end

-- C: anel de tempestade expandindo no chão
local function stormRing(position: Vector3, color: Color3)
	local ring = neon(
		Vector3.new(1, 2, 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder
	)
	TweenService:Create(ring, TweenInfo.new(0.4), {
		Size = Vector3.new(1, 40, 40),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.45)
end

-- Z: rastro do dash a partir do jogador
local function dashStreak(color: Color3)
	local _, hrp = localChar()
	if not hrp then
		return
	end
	local streak = neon(Vector3.new(2, 2, 14), hrp.CFrame * CFrame.new(0, 0, -4), color)
	TweenService:Create(streak, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	Debris:AddItem(streak, 0.35)
end

-- V: aura de forma no personagem por alguns segundos
local function formAura(color: Color3)
	local char = localChar()
	if not char then
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.FillTransparency = 0.6
	hl.OutlineColor = color
	hl.Parent = char
	Debris:AddItem(hl, 8)
end

-- ---------- escudo de defesa (enquanto segura o bloqueio) ----------
local shield: Part? = nil

function CombatController.setBlocking(on: boolean)
	if on then
		if shield then
			return
		end
		local _, hrp = localChar()
		if not hrp then
			return
		end
		local p = Instance.new("Part")
		p.Name = "GuardShield"
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(6.5, 6.5, 3)
		p.Material = Enum.Material.ForceField
		p.Color = Color3.fromRGB(120, 200, 255)
		p.Transparency = 0.35
		p.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)
		p.Parent = Workspace
		shield = p
	else
		if shield then
			local s = shield
			shield = nil
			TweenService:Create(s, TweenInfo.new(0.15), { Transparency = 1 }):Play()
			Debris:AddItem(s, 0.2)
		end
	end
end

-- flash no escudo (parry) / quebra
local function shieldFlash(color: Color3)
	if not shield then
		return
	end
	local s = shield
	s.Color = color
	s.Transparency = 0
	TweenService:Create(s, TweenInfo.new(0.25), { Transparency = 0.35 }):Play()
	task.delay(0.3, function()
		if s and s.Parent then
			s.Color = Color3.fromRGB(120, 200, 255)
		end
	end)
end

-- M1: arco de golpe à frente do jogador
local function meleeSlash()
	local _, hrp = localChar()
	if not hrp then
		return
	end
	local slash = neon(
		Vector3.new(10, 0.4, 5),
		hrp.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(0, 0, math.rad(math.random(-20, 20))),
		Color3.fromRGB(255, 255, 255)
	)
	slash.Transparency = 0.2
	TweenService:Create(slash, TweenInfo.new(0.18), { Transparency = 1 }):Play()
	Debris:AddItem(slash, 0.22)
end

-- ---------- câmera: hit-stop punch + shake ----------
local function hitStop()
	shakeAmount = math.max(shakeAmount, 0.35)
end

function CombatController.predictSwing()
	-- feedback imediato do próprio golpe, antes da resposta do servidor
	shakeAmount = math.max(shakeAmount, 0.12)
	meleeSlash()
	-- cicla a animação do combo (swing1..swing4); reinicia se demorou
	local now = os.clock()
	if now - lastSwing > 0.9 then
		swingIndex = 0
	end
	lastSwing = now
	swingIndex = (swingIndex % 4) + 1
	AnimController.play("swing" .. swingIndex)
end

function CombatController.Start()
	CombatFeedback.OnClientEvent:Connect(function(data)
		if data.kind == "hit" then
			damageNumber(data.position, data.amount, data.crit == true)
			shakeAmount = math.max(shakeAmount, data.crit and 0.5 or 0.25)
		elseif data.kind == "hitstop" then
			hitStop()
		elseif data.kind == "power" then
			local color = data.color or Color3.fromRGB(120, 220, 255)
			if data.key == "Z" then
				dashStreak(color)
				shakeAmount = math.max(shakeAmount, 0.25)
			elseif data.key == "X" then
				lightningBolt(data.position, color)
				shakeAmount = math.max(shakeAmount, 0.55)
			elseif data.key == "C" then
				stormRing(data.position, color)
				shakeAmount = math.max(shakeAmount, 0.5)
			elseif data.key == "V" then
				formAura(color)
				shakeAmount = math.max(shakeAmount, 0.3)
			end
		elseif data.kind == "parry" then
			if data.position then
				burst(data.position, Color3.fromRGB(255, 240, 150))
			end
			shieldFlash(Color3.fromRGB(255, 230, 120))
			notify("PARRY!", Color3.fromRGB(255, 240, 150))
			shakeAmount = math.max(shakeAmount, 0.45)
		elseif data.kind == "blocked" then
			if data.position then
				burst(data.position, Color3.fromRGB(150, 170, 190))
			end
			shieldFlash(Color3.fromRGB(200, 220, 255))
			shakeAmount = math.max(shakeAmount, 0.15)
		elseif data.kind == "dodged" then
			shakeAmount = math.max(shakeAmount, 0.08)
		elseif data.kind == "guardBreak" then
			shieldFlash(Color3.fromRGB(255, 60, 60))
			CombatController.setBlocking(false) -- escudo estilhaça
			if data.position then
				burst(data.position, Color3.fromRGB(255, 60, 60))
			end
			notify("GUARDA QUEBRADA!", Color3.fromRGB(220, 60, 60))
			shakeAmount = math.max(shakeAmount, 0.7)
		elseif data.kind == "postureBreak" then
			if data.position then
				burst(data.position, Color3.fromRGB(255, 180, 60))
			end
			notify("GUARDA DO INIMIGO QUEBRADA — ataque!", Color3.fromRGB(255, 180, 60))
			shakeAmount = math.max(shakeAmount, 0.4)
		elseif data.kind == "heavy" then
			meleeSlash()
			shakeAmount = math.max(shakeAmount, 0.35)
		elseif data.kind == "ultimate" then
			if data.position then
				stormRing(data.position, Color3.fromRGB(255, 220, 120))
				burst(data.position, Color3.fromRGB(255, 220, 120))
			end
			shakeAmount = math.max(shakeAmount, 0.9)
		elseif data.kind == "notify" then
			notify(data.text, data.color)
		end
	end)

	-- escudo acompanha o personagem + shake da câmera
	RunService.RenderStepped:Connect(function(dt)
		if shield then
			local _, hrp = localChar()
			if hrp then
				shield.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)
			else
				CombatController.setBlocking(false)
			end
		end

		if shakeAmount <= 0.001 then
			return
		end
		local cam = Workspace.CurrentCamera
		local mag = shakeAmount
		cam.CFrame = cam.CFrame * CFrame.new(
			(math.random() - 0.5) * mag,
			(math.random() - 0.5) * mag,
			0
		)
		shakeAmount = math.max(0, shakeAmount - dt * 3)
	end)

	print("[CombatController] pronto")
end

return CombatController
