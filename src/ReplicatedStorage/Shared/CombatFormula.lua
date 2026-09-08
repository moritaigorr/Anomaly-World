--!strict
-- CombatFormula.lua
-- Fórmula de dano central. Puro (sem estado), roda igual no cliente e no servidor
-- para o cliente poder PREVER, mas quem aplica de verdade é sempre o servidor.

local Constants = require(script.Parent.Constants)

local CombatFormula = {}

export type DamageParams = {
	dmgBase: number,
	multArma: number?,
	multCombo: number?,
	multCore: number?,   -- inclui buff de forma (ex.: Thunder Form)
	mastery: number?,    -- pontos de domínio
	defesaAlvo: number?,
	forceCrit: boolean?, -- alguns poderes sempre critam
}

export type DamageResult = {
	dano: number,
	crit: boolean,
}

function CombatFormula.compute(params: DamageParams): DamageResult
	local base = params.dmgBase
	local multArma = params.multArma or 1
	local multCombo = params.multCombo or 1
	local multCore = params.multCore or 1
	local mastery = params.mastery or 0
	local defesa = params.defesaAlvo or 0

	local isCrit = params.forceCrit == true or (math.random() < Constants.Combat.CritChance)
	local critMult = isCrit and Constants.Combat.CritMult or 1

	local dano = (base * multArma * multCombo * multCore)
		* (1 + mastery * 0.01)
		* critMult
		- defesa

	dano = math.max(1, math.floor(dano + 0.5)) -- nunca zero, número inteiro legível

	return { dano = dano, crit = isCrit }
end

return CombatFormula
