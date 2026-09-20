--!strict
-- GearService.lua  (SERVIDOR)
-- Dono de verdade de "qual arma o jogador tem equipada". O InventoryController
-- (cliente) só PEDE pra trocar de arma; aqui a gente valida contra o catálogo
-- e decide. O CombatService lê s.equippedWeapon daqui pra saber quais stats
-- usar — por isso isto não pode ser um estado só-visual do cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponData = require(ReplicatedStorage.Shared.WeaponData)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)

local EquipWeaponRequest = Net.get("EquipWeaponRequest")
local CombatFeedback = Net.get("CombatFeedback")

local GearService = {}

local function onEquipWeapon(player: Player, weaponId: any)
	local s = PlayerState.get(player)
	if not s then
		return
	end
	if typeof(weaponId) ~= "string" or not WeaponData[weaponId] then
		return -- id inexistente: nunca confia no cliente
	end

	-- clicar na arma já equipada desequipa — mesma semântica que a barra
	-- de inventário já usava quando isso era só visual.
	if s.equippedWeapon == weaponId then
		s.equippedWeapon = nil
	else
		s.equippedWeapon = weaponId
	end

	-- trocar de arma no meio de um combo não deve carregar o índice de uma
	-- tabela de ComboMult pra outra (podem ter tamanhos diferentes).
	s.comboIndex = 0
	s.comboUntil = 0

	local weapon = s.equippedWeapon and WeaponData[s.equippedWeapon]
	CombatFeedback:FireClient(player, {
		kind = "notify",
		text = weapon and ("ARMA EQUIPADA — " .. weapon.nome) or "DESARMADO",
		color = Color3.fromRGB(205, 210, 220),
	})
end

function GearService.Start()
	EquipWeaponRequest.OnServerEvent:Connect(onEquipWeapon)
	print("[GearService] pronto")
end

return GearService
