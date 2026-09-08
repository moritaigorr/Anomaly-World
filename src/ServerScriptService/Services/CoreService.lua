--!strict
-- CoreService.lua  (SERVIDOR)
-- Executa os poderes da Anomaly Core equipada (Z/X/C/V), valida cooldown e aplica.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CoreData = require(ReplicatedStorage.Shared.CoreData)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)
local CombatUtil = require(script.Parent.CombatUtil)

local PowerRequest = Net.get("PowerRequest")
local CombatFeedback = Net.get("CombatFeedback")

local CoreService = {}

local VALID_KEYS = { Z = true, X = true, C = true, V = true }

-- valida o alvo travado que o cliente mandou (NUNCA confie cegamente no cliente)
local function validateLock(lockTarget: any, origin: Vector3): Model?
	if typeof(lockTarget) ~= "Instance" then
		return nil
	end
	local m = lockTarget :: Instance
	if not m:IsA("Model") or not CollectionService:HasTag(m, "Enemy") then
		return nil
	end
	local lhum = m:FindFirstChildOfClass("Humanoid")
	local lhrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not lhum or not lhrp or lhum.Health <= 0 then
		return nil
	end
	if (lhrp.Position - origin).Magnitude > 120 then
		return nil -- longe demais: rejeita
	end
	return m :: Model
end

local function onPower(player: Player, key: string, lockTarget: any)
	if not VALID_KEYS[key] then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = PlayerState.get(player)
	if not (hrp and hum and s) or hum.Health <= 0 then
		return
	end

	local core = CoreData[s.equippedCore]
	local ability = core and core.habilidades[key]
	if not ability then
		return
	end

	local now = os.clock()
	if now < s.stunUntil then
		return -- guarda quebrada: não pode usar poder
	end
	if now < (s.cooldowns[key] or 0) then
		return -- ainda em cooldown
	end
	s.cooldowns[key] = now + ability.cooldown

	local origin = hrp.Position
	local coreMult = PlayerState.getCoreMult(player)

	-- alvo travado (lock-on) validado; se houver, ele manda na mira
	local locked = validateLock(lockTarget, origin)
	local lockedRoot = locked and locked:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- direção da mira: se travado, aponta pro alvo; senão, a frente do personagem
	local look = hrp.CFrame.LookVector
	if lockedRoot then
		local d = lockedRoot.Position - origin
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then
			look = d.Unit
		end
	end

	-- alvo principal do X: o travado, senão o mais próximo à frente
	local mainTarget: Model? = nil
	if key == "X" then
		mainTarget = locked or CombatUtil.nearestInArc(origin, look, ability.range or 40)
	end

	-- posição do efeito visual
	local fxPos = origin
	if key == "X" and mainTarget then
		local thrp = mainTarget:FindFirstChild("HumanoidRootPart") :: BasePart?
		if thrp then
			fxPos = thrp.Position
		end
	end

	-- DISPARA O VISUAL PRIMEIRO: assim o poder sempre "sai", mesmo se algo falhar
	CombatFeedback:FireClient(player, {
		kind = "power",
		key = key,
		position = fxPos,
		color = core.cor,
	})

	-- efeito do poder (isolado: um erro aqui não engole o poder inteiro)
	local ok, err = pcall(function()
		if key == "Z" then
			-- Thunder Dash: impulso na direção da mira + dano em linha + i-frames
			s.iframeUntil = now + 0.2
			hrp.AssemblyLinearVelocity = look * 90 + Vector3.new(0, 8, 0)
			local hits = CombatUtil.enemiesInArc(origin, look, ability.range or 20, 0.3)
			if locked and not table.find(hits, locked) then
				table.insert(hits, locked) -- garante acerto no alvo travado
			end
			for _, enemy in hits do
				CombatUtil.damageEnemy(player, enemy, {
					dmgBase = ability.dano or 0,
					multCore = coreMult,
					mastery = s.mastery,
				})
			end
		elseif key == "X" then
			-- Lightning Strike: nuke no alvo (sempre crita)
			if mainTarget then
				CombatUtil.damageEnemy(player, mainTarget, {
					dmgBase = ability.dano or 0,
					multCore = coreMult,
					mastery = s.mastery,
					forceCrit = true,
				})
			end
		elseif key == "C" then
			-- Storm: dano em área ao redor do jogador
			for _, enemy in CombatUtil.enemiesInRadius(origin, ability.area or 15) do
				local ehrp = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
				local kb = ehrp and ((ehrp.Position - origin).Unit * 30 + Vector3.new(0, 25, 0)) or nil
				CombatUtil.damageEnemy(player, enemy, {
					dmgBase = ability.dano or 0,
					multCore = coreMult,
					mastery = s.mastery,
				}, kb)
			end
		elseif key == "V" then
			-- Thunder Form: buff de dano temporário
			s.formBuffUntil = now + (ability.duracao or 8)
			s.formBuffMult = ability.buff or 1.4
		end
	end)
	if not ok then
		warn("[CoreService] erro no poder " .. key .. ": " .. tostring(err))
	end
end

-- troca de Anomaly Core (T)
local SwapCoreRequest = Net.get("SwapCoreRequest")

local function onSwapCore(player: Player)
	local s = PlayerState.get(player)
	if not s then
		return
	end
	local order = CoreData.order or { "Thunder" }
	local idx = 1
	for i, name in order do
		if name == s.equippedCore then
			idx = i
			break
		end
	end
	local nextName = order[(idx % #order) + 1]
	s.equippedCore = nextName
	s.cooldowns = {} -- Core nova entra pronta

	local core = CoreData[nextName]
	CombatFeedback:FireClient(player, {
		kind = "notify",
		text = "CORE EQUIPADA — " .. (core and core.nome or nextName),
		color = core and core.cor or Color3.fromRGB(47, 212, 194),
	})
end

function CoreService.Start()
	PowerRequest.OnServerEvent:Connect(onPower)
	SwapCoreRequest.OnServerEvent:Connect(onSwapCore)
	print("[CoreService] pronto")
end

return CoreService
