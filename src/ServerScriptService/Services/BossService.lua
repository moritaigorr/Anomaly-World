--!strict
-- BossService.lua  (SERVIDOR)
-- THE EXPERIMENT: boss com fases (100/70/40/10) que mudam velocidade, dano e
-- comportamento. É marcado com a tag "Enemy", então os golpes e poderes do jogador
-- (CombatUtil) já o acertam sem código extra aqui.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BossData = require(ReplicatedStorage.Shared.BossData)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)
local CombatUtil = require(script.Parent.CombatUtil)

local CombatFeedback = Net.get("CombatFeedback")

local BossService = {}

-- círculo ritual, bem longe da cidade (igual a Wilds.BOSS_POS)
local SPAWN_POS = Vector3.new(-300, 5, 300)
local RESPAWN_DELAY = 20

-- avisa TODOS os clientes (toast na tela)
local function broadcast(text: string, color: Color3?)
	CombatFeedback:FireAllClients({ kind = "notify", text = text, color = color })
end

-- fase atual pela fração de HP
local function phaseFor(boss, frac: number)
	local chosen = boss.phases[1]
	for _, p in boss.phases do
		if frac <= p.at then
			chosen = p
		end
	end
	return chosen
end

local function rollDrops(boss): { string }
	local got = {}
	for _, drop in boss.drops do
		if math.random() < drop.chance then
			table.insert(got, drop.item)
		end
	end
	return got
end

local function slam(hrp: BasePart, damage: number, bossModel: Model)
	-- telegrafa no chão, espera, depois aplica dano em área (justo: dá pra sair)
	local warn = Instance.new("Part")
	warn.Anchored = true
	warn.CanCollide = false
	warn.Shape = Enum.PartType.Cylinder
	warn.Size = Vector3.new(0.4, 36, 36)
	warn.CFrame = CFrame.new(hrp.Position - Vector3.new(0, hrp.Size.Y / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	warn.Color = Color3.fromRGB(255, 80, 80)
	warn.Material = Enum.Material.Neon
	warn.Transparency = 0.5
	warn.Parent = workspace

	task.delay(0.8, function()
		local center = warn.Position
		warn:Destroy()
		for _, player in Players:GetPlayers() do
			local c = player.Character
			local phrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local phum = c and c:FindFirstChildOfClass("Humanoid")
			if phrp and phum and phum.Health > 0 then
				local flat = (phrp.Position - center)
				flat = Vector3.new(flat.X, 0, flat.Z)
				if flat.Magnitude <= 18 then
					CombatUtil.damagePlayer(player, damage, bossModel)
				end
			end
		end
	end)
end

local function spawnBoss()
	local boss = BossData.Experiment

	local model = Instance.new("Model")
	model.Name = boss.nome

	-- o root é o próprio corpo do boss (visível, ancorado)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(8, 9, 8)
	hrp.Shape = Enum.PartType.Ball
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Material = Enum.Material.Glass
	hrp.Color = boss.color
	hrp.Transparency = 0.12
	hrp.Reflectance = 0.1
	hrp.Parent = model
	local bodyPart = hrp -- HealthChanged recolore o corpo (que é o root)

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = boss.health
	hum.Health = boss.health
	hum.Parent = model

	model.PrimaryPart = hrp
	-- assenta o boss no chão (raycast), qualquer que seja o mapa
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(SPAWN_POS + Vector3.new(0, 300, 0), Vector3.new(0, -1000, 0), rp)
	local restY = (hit and hit.Position.Y or 0) + hrp.Size.Y / 2
	hrp.CFrame = CFrame.new(SPAWN_POS.X, restY, SPAWN_POS.Z)

	-- ------- decoração ancorada que segue o corpo (sem física/solda) -------
	local decor: { { part: BasePart, offset: CFrame } } = {}
	local function addDecor(part: BasePart, offset: CFrame)
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Parent = model
		table.insert(decor, { part = part, offset = offset })
	end

	-- núcleo emissivo
	local corePart = Instance.new("Part")
	corePart.Shape = Enum.PartType.Ball
	corePart.Size = Vector3.new(4, 4, 4)
	corePart.Material = Enum.Material.Neon
	corePart.Color = boss.trueFormColor
	addDecor(corePart, CFrame.new(0, 0, 0))

	-- espinhos ao redor
	for i = 1, 8 do
		local ang = (i / 8) * math.pi * 2
		local spike = Instance.new("Part")
		spike.Size = Vector3.new(1.2, 5, 1.2)
		spike.Material = Enum.Material.SmoothPlastic
		spike.Color = Color3.fromRGB(30, 15, 15)
		addDecor(
			spike,
			CFrame.new(math.cos(ang) * 4, 0, math.sin(ang) * 4) * CFrame.Angles(math.rad(90), ang, 0)
		)
	end

	-- dois olhos brilhantes
	for _, side in { -2, 2 } do
		local eye = Instance.new("Part")
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(1.4, 1.4, 1.4)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 230, 120)
		addDecor(eye, CFrame.new(side, 1.5, -3.4))
	end

	local function updateDecor()
		for _, d in decor do
			d.part.CFrame = hrp.CFrame * d.offset
		end
	end
	updateDecor()

	-- barra de HP grande
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10, 1.2)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.AlwaysOnTop = true
	bb.Parent = hrp
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 0.5)
	bg.BackgroundColor3 = Color3.fromRGB(20, 26, 31)
	bg.BorderSizePixel = 0
	bg.Parent = bb
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.5)
	title.Position = UDim2.fromScale(0, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(255, 90, 90)
	title.TextScaled = true
	title.Text = boss.nome
	title.Parent = bb

	-- boss tem muito mais guarda: quebrar exige vários parries/pesados
	model:SetAttribute("PostureMax", 220)
	model:SetAttribute("Posture", 220)
	model:SetAttribute("BreakStun", 4)

	CollectionService:AddTag(model, "Enemy")
	model.Parent = workspace
	broadcast("☠ O TÚMULO SE ABRIU — " .. boss.nome .. " despertou!", boss.trueFormColor)

	local nextAttack = 0
	local nextSlam = 0
	local currentPhaseName = ""

	hum.HealthChanged:Connect(function(h)
		local frac = h / hum.MaxHealth
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		local phase = phaseFor(boss, frac)
		if phase.name ~= currentPhaseName then
			currentPhaseName = phase.name
			broadcast(boss.nome .. " → " .. phase.name, boss.color)
			bodyPart.Color = (phase.name == "TRUE FORM") and boss.trueFormColor or boss.color
		end
	end)

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if hum.Health <= 0 then
			return
		end
		updateDecor()
		if os.clock() < (model:GetAttribute("StunUntil") or 0) then
			return -- atordoado por parry
		end
		local frac = hum.Health / hum.MaxHealth
		local phase = phaseFor(boss, frac)

		-- alvo mais próximo
		local target: BasePart? = nil
		local best = math.huge
		for _, player in Players:GetPlayers() do
			local c = player.Character
			local phrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local phum = c and c:FindFirstChildOfClass("Humanoid")
			if phrp and phum and phum.Health > 0 then
				local d = (phrp.Position - hrp.Position).Magnitude
				if d < best then
					best = d
					target = phrp
				end
			end
		end
		if not target then
			return
		end

		local to = target.Position - hrp.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		local now = os.clock()

		if flat.Magnitude > boss.attackRange then
			local step = flat.Unit * phase.speed * dt
			local newPos = hrp.Position + step
			hrp.CFrame = CFrame.lookAt(
				Vector3.new(newPos.X, restY, newPos.Z),
				Vector3.new(target.Position.X, restY, target.Position.Z)
			)
		elseif now >= nextAttack then
			local WINDUP = 0.6
			nextAttack = now + boss.attackCooldown + WINDUP
			local player = Players:GetPlayerFromCharacter(target.Parent)

			-- TELEGRAPH: o boss "carrega" antes de bater (janela pra parry/esquiva)
			local dmg = phase.damage
			local originalColor = bodyPart.Color
			bodyPart.Color = Color3.fromRGB(255, 150, 150)
			task.delay(WINDUP, function()
				if hum.Health <= 0 or not bodyPart.Parent then
					return
				end
				bodyPart.Color = originalColor
				if os.clock() < (model:GetAttribute("StunUntil") or 0) then
					return -- atordoado: o golpe não sai
				end
				local pc = player and player.Character
				local phrp = pc and pc:FindFirstChild("HumanoidRootPart") :: BasePart?
				if player and phrp and (phrp.Position - hrp.Position).Magnitude <= boss.attackRange + 4 then
					CombatUtil.damagePlayer(player, dmg, model)
				end
			end)
		end

		-- ataque de área nas fases avançadas
		if phase.slam and now >= nextSlam then
			nextSlam = now + 3.5
			slam(hrp, phase.damage, model)
		end
	end)

	hum.Died:Connect(function()
		conn:Disconnect()
		CollectionService:RemoveTag(model, "Enemy")

		-- recompensa o jogador mais próximo
		local reward: Player? = nil
		local best = math.huge
		for _, player in Players:GetPlayers() do
			local c = player.Character
			local phrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if phrp then
				local d = (phrp.Position - hrp.Position).Magnitude
				if d < best then
					best = d
					reward = player
				end
			end
		end

		local drops = rollDrops(boss)
		if reward then
			local s = PlayerState.get(reward)
			if s then
				s.money += boss.moneyReward
				s.bossKills += 1
				for _, item in drops do
					s.inventory[item] = (s.inventory[item] or 0) + 1
				end
			end
		end

		if #drops > 0 then
			broadcast(boss.nome .. " derrotado! Drop: " .. table.concat(drops, ", "), boss.trueFormColor)
		else
			broadcast(boss.nome .. " derrotado! (sem drop raro desta vez)", boss.color)
		end

		task.delay(2, function()
			model:Destroy()
		end)
		task.delay(RESPAWN_DELAY, spawnBoss)
	end)
end

function BossService.Start()
	task.delay(5, spawnBoss) -- deixa o jogador se ambientar antes do boss surgir
	print("[BossService] THE EXPERIMENT agendado")
end

return BossService
