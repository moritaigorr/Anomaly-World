--!strict
-- CombatUtil.lua  (SERVIDOR)
-- Funções compartilhadas de mira e aplicação de dano nos inimigos.
-- Usado tanto pelo golpe corpo a corpo quanto pelos poderes da Core.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local Net = require(ReplicatedStorage.Shared.Net)
local Constants = require(ReplicatedStorage.Shared.Constants)
local PlayerState = require(script.Parent.PlayerState)

local CombatFeedback = Net.get("CombatFeedback")

local CombatUtil = {}

-- pega o HumanoidRootPart de um inimigo (Model taggeado "Enemy")
local function rootOf(model: Instance): BasePart?
	local m = model :: Model
	local hrp = m:FindFirstChild("HumanoidRootPart")
	return hrp :: BasePart?
end

-- inimigos vivos dentro de um raio de um ponto
function CombatUtil.enemiesInRadius(origin: Vector3, radius: number): { Model }
	local out = {}
	for _, enemy in CollectionService:GetTagged("Enemy") do
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		local hrp = rootOf(enemy)
		if hum and hrp and hum.Health > 0 then
			if (hrp.Position - origin).Magnitude <= radius then
				table.insert(out, enemy :: Model)
			end
		end
	end
	return out
end

-- inimigos num cone à frente (origin + direção). arc = dot mínimo.
function CombatUtil.enemiesInArc(origin: Vector3, look: Vector3, range: number, arc: number): { Model }
	local out = {}
	look = look.Unit
	for _, enemy in CollectionService:GetTagged("Enemy") do
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		local hrp = rootOf(enemy)
		if hum and hrp and hum.Health > 0 then
			local delta = hrp.Position - origin
			if delta.Magnitude <= range and look:Dot(delta.Unit) >= arc then
				table.insert(out, enemy :: Model)
			end
		end
	end
	return out
end

-- o inimigo mais próximo à frente (para nukes single-target como Lightning Strike)
function CombatUtil.nearestInArc(origin: Vector3, look: Vector3, range: number): Model?
	local best: Model? = nil
	local bestDist = math.huge
	for _, enemy in CombatUtil.enemiesInArc(origin, look, range, 0.1) do
		local hrp = rootOf(enemy) :: BasePart
		local d = (hrp.Position - origin).Magnitude
		if d < bestDist then
			bestDist = d
			best = enemy
		end
	end
	return best
end

-- aplica dano a um inimigo e avisa os clientes por perto (feedback visual)
function CombatUtil.damageEnemy(attacker: Player, enemy: Model, params, knockback: Vector3?)
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	local hrp = rootOf(enemy)
	if not hum or not hrp or hum.Health <= 0 then
		return
	end

	params.mastery = params.mastery or 0
	local result = CombatFormula.compute(params)
	hum:TakeDamage(result.dano)

	-- bater carrega o ultimate
	local st = PlayerState.get(attacker)
	if st then
		st.ultCharge = math.min(
			Constants.Ultimate.Max,
			st.ultCharge + result.dano * Constants.Ultimate.GainPerDamage
		)
	end

	if knockback and hrp then
		hrp.AssemblyLinearVelocity = knockback
	end

	CombatFeedback:FireAllClients({
		kind = "hit",
		position = hrp.Position,
		amount = result.dano,
		crit = result.crit,
		killed = hum.Health <= 0,
	})
	-- só quem bateu leva hit-stop (é feedback pessoal)
	CombatFeedback:FireClient(attacker, { kind = "hitstop" })
end

-- tira guarda (posture) de um inimigo; se zerar, ele fica atordoado e vulnerável.
-- Usado pelo parry e pelo ataque pesado.
function CombatUtil.damageEnemyPosture(enemy: Model, amount: number, notify: Player?)
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	local hrp = rootOf(enemy)
	if not hum or not hrp or hum.Health <= 0 then
		return
	end
	local maxP = enemy:GetAttribute("PostureMax") or Constants.Enemy.Posture
	local cur = enemy:GetAttribute("Posture") or maxP
	cur -= amount

	if cur <= 0 then
		-- GUARDA QUEBRADA: atordoa por mais tempo e devolve a posture cheia
		enemy:SetAttribute("Posture", maxP)
		local stun = enemy:GetAttribute("BreakStun") or Constants.Enemy.BreakStun
		enemy:SetAttribute("StunUntil", os.clock() + stun)
		CombatFeedback:FireAllClients({
			kind = "postureBreak",
			position = hrp.Position,
		})
	else
		enemy:SetAttribute("Posture", cur)
	end
end

-- aplica dano de um inimigo NO jogador, respeitando esquiva/parry/bloqueio.
-- attacker é o Model do inimigo (pra atordoar num parry).
function CombatUtil.damagePlayer(player: Player, amount: number, attacker: Model?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local s = PlayerState.get(player)
	if not hum or hum.Health <= 0 or not s then
		return
	end

	-- esquiva (i-frames do dash): dano zero
	if os.clock() < s.iframeUntil then
		CombatFeedback:FireClient(player, { kind = "dodged", position = hrp and hrp.Position })
		return
	end

	local now = os.clock()

	if s.blocking and now >= s.stunUntil then
		if now - s.blockStart <= Constants.Block.ParryWindow then
			-- PARRY: dano zero + atordoa o atacante + tira a guarda dele + carrega ult
			if attacker then
				attacker:SetAttribute("StunUntil", now + Constants.Block.ParryStun)
				CombatUtil.damageEnemyPosture(attacker, Constants.Block.ParryPostureDamage, player)
			end
			s.ultCharge = math.min(Constants.Ultimate.Max, s.ultCharge + Constants.Ultimate.GainPerParry)
			CombatFeedback:FireClient(player, { kind = "parry", position = hrp and hrp.Position })
			return
		else
			-- BLOQUEIO segurado: gasta guarda (posture)
			s.posture -= Constants.Block.BlockCost
			s.postureHitAt = now
			if s.posture <= 0 then
				-- GUARDA QUEBRADA: fica atordoado e o golpe entra inteiro
				s.posture = Constants.Posture.Max
				s.blocking = false
				s.stunUntil = now + Constants.Posture.BreakStun
				hum:TakeDamage(amount)
				CombatFeedback:FireClient(player, {
					kind = "guardBreak",
					position = hrp and hrp.Position,
				})
				return
			end
			local chip = math.floor(amount * Constants.Block.BlockChip + 0.5)
			if chip > 0 then
				hum:TakeDamage(chip)
			end
			CombatFeedback:FireClient(player, { kind = "blocked", position = hrp and hrp.Position })
			return
		end
	end

	hum:TakeDamage(amount)
end

return CombatUtil
