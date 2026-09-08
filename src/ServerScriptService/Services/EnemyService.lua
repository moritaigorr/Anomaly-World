--!strict
-- EnemyService.lua  (SERVIDOR)
-- Cria as criaturas a partir de CreatureData (100% data-driven: criatura nova =
-- só uma tabela em CreatureData.lua). Movimento cinemático (root ancorado movido
-- por CFrame): simples, sem jitter de física.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CreatureData = require(ReplicatedStorage.Shared.CreatureData)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local PlayerState = require(script.Parent.PlayerState)
local CombatUtil = require(script.Parent.CombatUtil)

local EnemyService = {}

-- altura do chão em (x,z): a criatura nunca flutua nem afunda
local function groundYAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged("Enemy")
	local res = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -1000, 0), params)
	return res and res.Position.Y or 0
end

local function makeHealthBar(parent: BasePart, hum: Humanoid, nome: string, width: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(width, width * 0.28)
	bb.StudsOffset = Vector3.new(0, parent.Size.Y * 0.9, 0)
	bb.AlwaysOnTop = true
	bb.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.45)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.fromRGB(200, 215, 225)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = nome
	label.Parent = bb

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 0.4)
	bg.Position = UDim2.fromScale(0, 0.55)
	bg.BackgroundColor3 = Color3.fromRGB(20, 26, 31)
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(210, 70, 70)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	hum.HealthChanged:Connect(function(h)
		fill.Size = UDim2.fromScale(math.clamp(h / hum.MaxHealth, 0, 1), 1)
	end)
end

-- sorteia uma criatura entre as permitidas na zona (respeitando os pesos)
local function rollForZone(zone)
	local pool = {}
	local total = 0
	for _, id in zone.creatures do
		local def = CreatureData.byId(id)
		if def then
			table.insert(pool, def)
			total += def.weight
		end
	end
	if #pool == 0 then
		return CreatureData.roll()
	end
	local pick = math.random() * total
	for _, def in pool do
		pick -= def.weight
		if pick <= 0 then
			return def
		end
	end
	return pool[1]
end

local function spawnCreature(zone)
	local def = rollForZone(zone)

	local model = Instance.new("Model")
	model.Name = def.nome

	-- o root é o corpo visível (ancorado)
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = def.size
	hrp.Shape = Enum.PartType.Ball
	hrp.Anchored = true
	hrp.CanCollide = false
	hrp.Material = Enum.Material.Glass
	hrp.Color = def.color
	hrp.Transparency = 0.2
	hrp.Reflectance = 0.05
	hrp.Parent = model

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = def.health
	hum.Health = def.health
	hum.Parent = model

	model.PrimaryPart = hrp

	-- decoração ancorada que segue o corpo (sem solda/física)
	local decor: { { part: BasePart, offset: CFrame } } = {}
	local function addDecor(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.Color = color
		p.Material = material
		p.Parent = model
		table.insert(decor, { part = p, offset = offset })
	end

	local scale = def.size.X / 3 -- proporcional ao tamanho da criatura
	addDecor(Vector3.one * 1.2 * scale, CFrame.new(0, 0, 0), def.coreColor, Enum.Material.Neon)
	for _, sx in { -0.7 * scale, 0.7 * scale } do
		addDecor(
			Vector3.one * 0.7 * scale,
			CFrame.new(sx, 0.3 * scale, -1.2 * scale),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		addDecor(
			Vector3.one * 0.34 * scale,
			CFrame.new(sx, 0.3 * scale, -1.45 * scale),
			Color3.fromRGB(15, 20, 25),
			Enum.Material.SmoothPlastic
		)
	end

	makeHealthBar(hrp, hum, def.nome, def.size.X * 1.6)

	-- guarda (posture) e identidade para o Anomaly Database
	model:SetAttribute("PostureMax", def.posture)
	model:SetAttribute("Posture", def.posture)
	model:SetAttribute("BreakStun", Constants.Enemy.BreakStun)
	model:SetAttribute("CreatureId", def.id)

	-- nasce dentro da SUA zona (nunca perto do vilarejo), assentado no chão
	local sx2, sz2 = ZoneData.randomPointIn(zone)
	local restY = groundYAt(sx2, sz2) + def.size.Y / 2
	hrp.CFrame = CFrame.new(sx2, restY, sz2)
	model:SetAttribute("Zone", zone.id)

	CollectionService:AddTag(model, "Enemy")
	model.Parent = workspace

	local function updateDecor()
		for _, d in decor do
			d.part.CFrame = hrp.CFrame * d.offset
		end
	end
	updateDecor()

	local nextAttack = 0

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if hum.Health <= 0 then
			return
		end
		updateDecor()
		if os.clock() < (model:GetAttribute("StunUntil") or 0) then
			return -- atordoado por parry / guarda quebrada
		end

		-- alvo mais próximo
		local target: BasePart? = nil
		local bestDist = Constants.Enemy.AggroRange
		for _, player in Players:GetPlayers() do
			local c = player.Character
			local phrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local phum = c and c:FindFirstChildOfClass("Humanoid")
			if phrp and phum and phum.Health > 0 then
				local d = (phrp.Position - hrp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					target = phrp
				end
			end
		end
		if not target then
			return
		end

		local to = target.Position - hrp.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		if flat.Magnitude > Constants.Enemy.AttackRange then
			local step = flat.Unit * def.speed * dt
			local newPos = hrp.Position + step
			hrp.CFrame = CFrame.lookAt(
				Vector3.new(newPos.X, restY, newPos.Z),
				Vector3.new(target.Position.X, restY, target.Position.Z)
			)
		else
			local now = os.clock()
			if now >= nextAttack then
				nextAttack = now + Constants.Enemy.AttackCooldown + def.windup
				local player = Players:GetPlayerFromCharacter(target.Parent)

				-- TELEGRAPH: avisa antes de bater (janela pra bloquear/esquivar)
				hrp.Color = Color3.fromRGB(255, 120, 120)
				local baseSize = def.size
				TweenService:Create(hrp, TweenInfo.new(def.windup), { Size = baseSize * 1.15 }):Play()

				task.delay(def.windup, function()
					if hum.Health <= 0 or not hrp.Parent then
						return
					end
					hrp.Color = def.color
					TweenService:Create(hrp, TweenInfo.new(0.12), { Size = baseSize }):Play()
					if os.clock() < (model:GetAttribute("StunUntil") or 0) then
						return -- atordoado no meio do golpe: não sai
					end
					local pc = player and player.Character
					local phrp = pc and pc:FindFirstChild("HumanoidRootPart") :: BasePart?
					if
						player
						and phrp
						and (phrp.Position - hrp.Position).Magnitude <= Constants.Enemy.AttackRange + 3
					then
						CombatUtil.damagePlayer(player, def.damage, model)
					end
				end)
			end
		end
	end)

	hum.Died:Connect(function()
		conn:Disconnect()

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
		if reward then
			local s = PlayerState.get(reward)
			if s then
				s.money += def.money
				PlayerState.discover(reward, def.id, def.nome) -- Anomaly Database
			end
			local rc = reward.Character
			local rhum = rc and rc:FindFirstChildOfClass("Humanoid")
			if rhum and rhum.Health > 0 then
				rhum.Health = math.min(rhum.MaxHealth, rhum.Health + Constants.Player.LifestealOnKill)
			end
		end

		CollectionService:RemoveTag(model, "Enemy")
		task.delay(1, function()
			model:Destroy()
		end)
		-- renasce na mesma zona
		task.delay(Constants.Enemy.RespawnDelay, function()
			spawnCreature(zone)
		end)
	end)
end

function EnemyService.Start()
	local total = 0
	for _, zone in ZoneData.zones do
		for _ = 1, zone.maxAlive do
			spawnCreature(zone)
			total += 1
		end
	end
	print("[EnemyService] " .. total .. " criaturas em " .. #ZoneData.zones .. " zonas")
end

return EnemyService
