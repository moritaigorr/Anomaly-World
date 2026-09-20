--!strict
-- CombatService.lua  (SERVIDOR)
-- Autoridade do golpe corpo a corpo (M1). O cliente só PEDE; aqui a gente valida
-- cooldown, alcance e mira, calcula o dano e aplica. Nunca confie no cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local BowProjectile = require(ReplicatedStorage.Shared.BowProjectile)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)
local CombatUtil = require(script.Parent.CombatUtil)

local AttackRequest = Net.get("AttackRequest")
local HeavyRequest = Net.get("HeavyRequest")
local UltimateRequest = Net.get("UltimateRequest")
local BowShootRequest = Net.get("BowShootRequest")
local CombatFeedback = Net.get("CombatFeedback")

local CombatService = {}

-- arma equipada, ou nil se estiver desarmado
local function weaponOf(s: PlayerState.State): WeaponData.Weapon?
	return s.equippedWeapon and WeaponData[s.equippedWeapon]
end

local function onAttack(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = PlayerState.get(player)
	if not (hrp and hum and s) or hum.Health <= 0 then
		return
	end

	local weapon = weaponOf(s)
	if weapon and weapon.ranged then
		return -- arco: sem golpe corpo a corpo por enquanto
	end
	local light = (weapon and weapon.light) or Constants.Melee

	local now = os.clock()
	if now < s.stunUntil then
		return -- guarda quebrada: não pode agir
	end
	if now < s.attackCdUntil then
		return -- ainda em recovery do golpe anterior
	end
	s.attackCdUntil = now + light.CooldownPerHit

	-- avança o combo (ou reinicia se a janela passou)
	if now > s.comboUntil then
		s.comboIndex = 1
	else
		s.comboIndex = math.min(s.comboIndex + 1, #light.ComboMult)
	end
	s.comboUntil = now + Constants.Melee.ComboWindow

	local comboMult = light.ComboMult[s.comboIndex]
	local isFinal = s.comboIndex >= #light.ComboMult

	local origin = hrp.Position
	local look = hrp.CFrame.LookVector
	local hits = CombatUtil.enemiesInArc(origin, look, light.Range, light.Arc)

	for _, enemy in hits do
		local kb: Vector3? = nil
		if isFinal then
			local ehrp = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
			if ehrp then
				kb = (ehrp.Position - origin).Unit * light.KnockbackFinal
					+ Vector3.new(0, 20, 0)
			end
		end
		CombatUtil.damageEnemy(player, enemy, {
			dmgBase = light.BaseDamage,
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

	local weapon = weaponOf(s)
	if weapon and weapon.ranged then
		return -- arco: sem golpe corpo a corpo por enquanto
	end
	local heavy = (weapon and weapon.heavy) or Constants.Heavy

	local now = os.clock()
	if now < s.stunUntil or now < s.heavyCdUntil then
		return
	end
	s.heavyCdUntil = now + heavy.Cooldown
	s.attackCdUntil = now + heavy.Cooldown -- trava o combo leve também
	s.comboIndex = 0

	local origin = hrp.Position
	local look = hrp.CFrame.LookVector
	for _, enemy in CombatUtil.enemiesInArc(origin, look, heavy.Range, heavy.Arc) do
		local ehrp = enemy:FindFirstChild("HumanoidRootPart") :: BasePart?
		local kb = ehrp
				and ((ehrp.Position - origin).Unit * heavy.Knockback + Vector3.new(0, 25, 0))
			or nil
		CombatUtil.damageEnemy(player, enemy, {
			dmgBase = heavy.Damage,
			multCore = PlayerState.getCoreMult(player),
			mastery = s.mastery,
		}, kb)
		CombatUtil.damageEnemyPosture(enemy, heavy.PostureDamage, player)
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

-- DISPARO DO ARCO: o cliente só manda a mira que ele calculou (câmera/olhar);
-- aqui a gente confere a arma, o cooldown e o alcance antes de soltar a
-- flecha de verdade. O dano só entra se a flecha (física, dona do servidor)
-- encostar num inimigo — dá pra desviar andando pro lado.
local function onBowShoot(player: Player, aim: any)
	if typeof(aim) ~= "Vector3" then
		return -- nunca confia no cliente
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = PlayerState.get(player)
	if not (hrp and hum and s) or hum.Health <= 0 then
		return
	end

	-- só o arco atira. Não basta "o cliente mandou": tem que bater com o que
	-- o servidor sabe que está equipado.
	if s.equippedWeapon ~= "bow" then
		return
	end

	local now = os.clock()
	if now < s.stunUntil or now < s.bowCdUntil then
		return
	end
	s.bowCdUntil = now + Constants.Bow.Cooldown

	local origin = hrp.Position
	local delta = aim - origin
	local target = if delta.Magnitude > Constants.Bow.Range
		then origin + delta.Unit * Constants.Bow.Range
		else aim

	local arrow = BowProjectile.create(Workspace, origin, target, char, Constants.Bow)
	local hasHit = false
	local connection: RBXScriptConnection
	connection = arrow.Touched:Connect(function(hit: BasePart)
		if hasHit then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		if not model or not CollectionService:HasTag(model, "Enemy") then
			return
		end
		hasHit = true
		connection:Disconnect()
		CombatUtil.damageEnemy(player, model, {
			dmgBase = Constants.Bow.Damage,
			multCore = PlayerState.getCoreMult(player),
			mastery = s.mastery,
		})
		s.mastery += 1
		arrow:Destroy()
	end)
end

function CombatService.Start()
	AttackRequest.OnServerEvent:Connect(onAttack)
	HeavyRequest.OnServerEvent:Connect(onHeavy)
	UltimateRequest.OnServerEvent:Connect(onUltimate)
	BowShootRequest.OnServerEvent:Connect(onBowShoot)
	print("[CombatService] pronto")
end

return CombatService
