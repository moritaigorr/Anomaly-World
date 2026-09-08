-- Main.client.lua  (CLIENTE)
-- Ponto de entrada do cliente. Liga os controllers.

local Controllers = script.Parent.Controllers

local CombatController = require(Controllers.CombatController)
local HudController = require(Controllers.HudController)
local InputController = require(Controllers.InputController)
local CameraController = require(Controllers.CameraController)
local AnimController = require(Controllers.AnimController)
local InventoryController = require(Controllers.InventoryController)
local AuraController = require(Controllers.AuraController)

CombatController.Start()
HudController.Start()
CameraController.Start()
AnimController.Start()
InventoryController.Start()
AuraController.Start()
InputController.Start({
	CombatController = CombatController,
	AnimController = AnimController,
	CameraController = CameraController,
	HudController = HudController,
})

print("[Anomaly World] cliente iniciado — Marco 0")
