--!strict
-- PlayerState.lua  (SERVIDOR)
-- Estado em memória de cada jogador. No Marco 0 nada é salvo em disco — isso é
-- de propósito. Persistência (ProfileService) entra no Marco 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local CombatFeedback = Net.get("CombatFeedback")

export type State = {
	stamina: number,
	iframeUntil: number,   -- os.clock() até quando está invulnerável
	dashCdUntil: number,
	attackCdUntil: number, -- ritmo entre golpes do combo
	blocking: boolean,     -- segurando o bloqueio
	blockStart: number,    -- os.clock() de quando começou a bloquear (janela de parry)
	sprinting: boolean,    -- correndo AGORA (drena stamina enquanto se move)
	sprintHeld: boolean,   -- Shift continua pressionado (intencao, nao estado)
	posture: number,       -- guarda restante
	postureHitAt: number,  -- última vez que a guarda levou dano
	stunUntil: number,     -- atordoado (guarda quebrada): não pode agir
	heavyCdUntil: number,  -- cooldown do ataque pesado
	ultCharge: number,     -- carga do ultimate
	comboIndex: number,
	comboUntil: number,    -- janela pra continuar o combo
	cooldowns: { [string]: number }, -- por poder da Core: Z/X/C/V -> os.clock() de liberação
	formBuffUntil: number, -- Thunder Form ativo até quando
	formBuffMult: number,
	equippedCore: string,
	mastery: number,
	money: number,
	bossKills: number,
	inventory: { [string]: number }, -- item -> quantidade (drops de boss)
	database: { [string]: boolean }, -- Anomaly Database: ANM-XXX descobertos
}

local PlayerState = {}
local states: { [Player]: State } = {}

function PlayerState.init(player: Player)
	states[player] = {
		stamina = Constants.Player.MaxStamina,
		iframeUntil = 0,
		dashCdUntil = 0,
		attackCdUntil = 0,
		blocking = false,
		blockStart = 0,
		sprinting = false,
		sprintHeld = false,
		posture = Constants.Posture.Max,
		postureHitAt = 0,
		stunUntil = 0,
		heavyCdUntil = 0,
		ultCharge = 0,
		comboIndex = 0,
		comboUntil = 0,
		cooldowns = {},
		formBuffUntil = 0,
		formBuffMult = 1,
		equippedCore = "Thunder", -- todo mundo começa com a Thunder no protótipo
		mastery = 0,
		money = 0,
		bossKills = 0,
		inventory = {},
		database = {},
	}
end

-- registra uma criatura no Anomaly Database (avisa se for inédita)
function PlayerState.discover(player: Player, id: string, nome: string)
	local s = states[player]
	if not s or s.database[id] then
		return
	end
	s.database[id] = true
	CombatFeedback:FireClient(player, {
		kind = "notify",
		text = "NOVA ANOMALIA CATALOGADA — " .. id .. " " .. nome,
		color = Color3.fromRGB(47, 212, 194),
	})
end

function PlayerState.get(player: Player): State?
	return states[player]
end

-- multiplicador de dano atual do jogador (inclui buff de forma se ativo)
function PlayerState.getCoreMult(player: Player): number
	local s = states[player]
	if not s then
		return 1
	end
	if os.clock() < s.formBuffUntil then
		return s.formBuffMult
	end
	return 1
end

-- atordoado por guarda quebrada: não pode atacar/usar poder/esquivar
function PlayerState.isStunned(player: Player): boolean
	local s = states[player]
	return s ~= nil and os.clock() < s.stunUntil
end

-- reseta o estado de combate (chamado ao renascer)
function PlayerState.resetCombat(player: Player)
	local s = states[player]
	if not s then
		return
	end
	s.posture = Constants.Posture.Max
	s.stunUntil = 0
	s.blocking = false
	s.sprinting = false
	s.sprintHeld = false
	s.comboIndex = 0
	s.stamina = Constants.Player.MaxStamina
end

function PlayerState.isInvulnerable(player: Player): boolean
	local s = states[player]
	return s ~= nil and os.clock() < s.iframeUntil
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return PlayerState
