--!strict
-- CombatService.lua  (SERVIDOR)
-- Autoridade do golpe corpo a corpo (M1). O cliente só PEDE; aqui a gente valida
-- cooldown, alcance e mira, calcula o dano e aplica. Nunca confie no cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)
local CombatUtil = require(script.Parent.CombatUtil)

local AttackRequest = Net.get("AttackRequest")
local HeavyRequest = Net.get("HeavyRequest")
local UltimateRequest = Net.get("UltimateRequest")
local CombatFeedback = Net.get("CombatFeedback")

local CombatService = {}

local function onAttack(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = PlayerState.get(player)
	if not (hrp and hum and s) or hum.Health <= 0 then
		return
	end

	local now = os.clock()
	if now < s.stunUntil then
		return -- guarda quebrada: não pode agir
	end
	if now < s.attackCdUntil then
		return -- ainda em recovery do golpe anterior
	end
	s.attackCdUntil = now + Constants.Melee.CooldownPerHit

	-- avança o combo (ou reinicia se a janela passou)
	if now > s.comboUntil then
		s.comboIndex = 1
	else
		s.comboIndex = math.min(s.comboIndex + 1, #Constants.Melee.ComboMult)
	end
	s.comboUntil = now + Constants.Melee.ComboWindow

	local comboMult = Constants.Melee.ComboMult[s.comboIndex]
	local isFinal = s.comboIndex >= #Constants.Melee.ComboMult

	local origin = hrp.Position
	local look = hrp.CFrame.LookVector
	local hits = CombatUtil.enemiesInArc(origin, look, Constants.Melee.Range, Constants.Melee.Arc)

	for _, enemy in hits do
		local kb: Vector3? = nil
		if isFinal then
			local ehrp = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
			if ehrp then
				kb = (ehrp.Position - origin).Unit * Constants.Melee.KnockbackFinal
					+ Vector3.new(0, 20, 0)
			end
		end
		CombatUtil.damageEnemy(player, enemy, {
			dmgBase = Constants.Melee.BaseDamage,
			multCombo = comboMult,
			multCore = PlayerState.getCoreMult(player),
			mastery = s.mastery,
		}, kb)
	end

	-- pequena recompensa de mastery por acertar
	if #hits > 0 then
		s.mastery += #hits
	end
end

-- ATAQUE PESADO (F): lento, forte, e arrebenta a guarda do inimigo
local function onHeavy(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = PlayerState.get(player)
	if not (hrp and hum and s) or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < s.stunUntil or now < s.heavyCdUntil then
		return
	end
	s.heavyCdUntil = now + Constants.Heavy.Cooldown
	s.attackCdUntil = now + Constants.Heavy.Cooldown -- trava o combo leve também
	s.comboIndex = 0

	local origin = hrp.Position
	local look = hrp.CFrame.LookVector
	for _, enemy in CombatUtil.enemiesInArc(origin, look, Constants.Heavy.Range, Constants.Heavy.Arc) do
		local ehrp = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
		local kb = ehrp
				and ((ehrp.Position - origin).Unit * Constants.Heavy.Knockback + Vector3.new(0, 25, 0))
			or nil
		CombatUtil.damageEnemy(player, enemy, {
			dmgBase = Constants.Heavy.Damage,
			multCore = PlayerState.getCoreMult(player),
			mastery = s.mastery,
		}, kb)
		CombatUtil.damageEnemyPosture(enemy, Constants.Heavy.PostureDamage, player)
	end

	CombatFeedback:FireClient(player, { kind = "heavy", position = origin })
end

-- ULTIMATE (G): estouro em área quando a barra estiver cheia
local function onUltimate(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = PlayerState.get(player)
	if not (hrp and hum and s) or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < s.stunUntil or s.ultCharge < Constants.Ultimate.Max then
		return -- ainda não carregou
	end
	s.ultCharge = 0

	local origin = hrp.Position
	CombatFeedback:FireAllClients({ kind = "ultimate", position = origin })
	for _, enemy in CombatUtil.enemiesInRadius(origin, Constants.Ultimate.Radius) do
		CombatUtil.damageEnemy(player, enemy, {
			dmgBase = Constants.Ultimate.Damage,
			multCore = PlayerState.getCoreMult(player),
			mastery = s.mastery,
			forceCrit = true,
		})
		CombatUtil.damageEnemyPosture(enemy, 999, player) -- ultimate sempre quebra guarda
	end
end

function CombatService.Start()
	AttackRequest.OnServerEvent:Connect(onAttack)
	HeavyRequest.OnServerEvent:Connect(onHeavy)
	UltimateRequest.OnServerEvent:Connect(onUltimate)
	print("[CombatService] pronto")
end

return CombatService
