--!strict
-- LockUi.lua
-- Crosshair central (sem ponto) + captura reversível do cursor pro controle
-- de câmera em terceira pessoa.

local UserInputService = game:GetService("UserInputService")

local LockUi = {}

local gui: ScreenGui? = nil
local crosshair: Frame? = nil
local active = false
local previousMouseBehavior: Enum.MouseBehavior? = nil
local previousMouseIconEnabled: boolean? = nil

local CROSSHAIR_COLOR = Color3.fromRGB(255, 255, 255)

local function makeBar(
	parent: GuiObject,
	name: string,
	size: UDim2,
	position: UDim2,
	anchorPoint: Vector2
): Frame
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.Size = size
	bar.Position = position
	bar.AnchorPoint = anchorPoint
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = CROSSHAIR_COLOR
	bar.ZIndex = 2
	bar.Parent = parent
	return bar
end

local function createGui(playerGui: PlayerGui): ScreenGui
	local existing = playerGui:FindFirstChild("DuelCrosshairGui")
	if existing and existing:IsA("ScreenGui") then
		crosshair = existing:FindFirstChild("Crosshair", true) :: Frame?
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DuelCrosshairGui"
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.fromOffset(18, 18)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = screenGui

	makeBar(crosshair, "Top", UDim2.fromOffset(2, 7), UDim2.fromScale(0.5, 0), Vector2.new(0.5, 0))
	makeBar(crosshair, "Bottom", UDim2.fromOffset(2, 7), UDim2.fromScale(0.5, 1), Vector2.new(0.5, 1))
	makeBar(crosshair, "Left", UDim2.fromOffset(7, 2), UDim2.fromScale(0, 0.5), Vector2.new(0, 0.5))
	makeBar(crosshair, "Right", UDim2.fromOffset(7, 2), UDim2.fromScale(1, 0.5), Vector2.new(1, 0.5))

	screenGui.Parent = playerGui
	return screenGui
end

-- move a crosshair pra cima do alvo travado (tela); nil = volta pro centro
function LockUi.setTargetPosition(screenPos: Vector2?)
	if not crosshair then
		return
	end
	if screenPos then
		crosshair.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
	else
		crosshair.Position = UDim2.fromScale(0.5, 0.5)
	end
end

function LockUi.setActive(playerGui: PlayerGui, shouldBeActive: boolean)
	if shouldBeActive then
		if not active then
			previousMouseBehavior = UserInputService.MouseBehavior
			previousMouseIconEnabled = UserInputService.MouseIconEnabled
		end
		active = true

		gui = gui or createGui(playerGui)
		if gui.Parent ~= playerGui then
			gui.Parent = playerGui
		end
		gui.Enabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		return
	end

	if gui then
		gui.Enabled = false
	end
	if active then
		UserInputService.MouseBehavior = previousMouseBehavior or Enum.MouseBehavior.Default
		if previousMouseIconEnabled ~= nil then
			UserInputService.MouseIconEnabled = previousMouseIconEnabled
		else
			UserInputService.MouseIconEnabled = true
		end
	end
	active = false
	previousMouseBehavior = nil
	previousMouseIconEnabled = nil
end

return LockUi
