--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local BowPose = require(ReplicatedStorage.Shared.BowPose)

local BowAttack = {}
local busy: {[Model]: boolean} = setmetatable({}, {__mode = "k"}) :: any

function BowAttack.getAim(character: Model, camera: Camera?): Vector3
	local origin = character:GetPivot().Position
	local direction = character:GetPivot().LookVector
	if camera then
		local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5)
		local ray = camera:ViewportPointToRay(center.X, center.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character}
		local result = Workspace:Raycast(ray.Origin, ray.Direction * Constants.Bow.Range, params)
		return result and result.Position or ray.Origin + ray.Direction * Constants.Bow.Range
	end
	return origin + direction * Constants.Bow.Range
end

local function updatePreview(preview: BasePart, character: Model, aim: Vector3)
	local bow = character:FindFirstChild("AnomalyBow")
	local top = bow and bow:FindFirstChild("NockTop") :: BasePart?
	local bottom = bow and bow:FindFirstChild("NockBottom") :: BasePart?
	local rest = bow and bow:FindFirstChild("ArrowRest") :: BasePart?
	local pull = character:FindFirstChild("_BowRightTarget") :: BasePart?
	local center = rest and rest.Position or character:GetPivot().Position
	if top and bottom then center = (top.Position + bottom.Position) * 0.5 end
	if pull then center = center:Lerp(pull.Position, BowPose.getDrawAmount(character)) end
	local delta = aim - center
	local direction = delta.Magnitude > 0.01 and delta.Unit or character:GetPivot().LookVector
	preview.CFrame = CFrame.lookAt(center + direction * 1.15, center + direction * 2.15)
end

function BowAttack.shoot(character: Model?, camera: Camera?, fireServer: (Vector3, string) -> ()): boolean
	if not character or busy[character] or not character:FindFirstChild("AnomalyBow") then return false end
	busy[character] = true
	BowPose.activate(character)
	local aim = BowAttack.getAim(character, camera)
	local preview = Instance.new("Part")
	preview.Name = "NockedArrow"
	preview.Size = Vector3.new(0.075, 0.075, 2.3)
	preview.Material = Enum.Material.Wood
	preview.Color = Color3.fromRGB(112, 72, 38)
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = false
	preview.CanTouch = false
	preview.Parent = Workspace

	task.spawn(function()
		BowPose.setDrawAmount(character, 1, Constants.Bow.DrawTime)
		local started = os.clock()
		repeat
			if not character.Parent or not character:FindFirstChild("AnomalyBow") then
				if preview.Parent then preview:Destroy() end
				busy[character] = nil
				return
			end
			updatePreview(preview, character, aim)
			task.wait()
		until os.clock() - started >= Constants.Bow.DrawTime
		if preview.Parent then preview:Destroy() end
		fireServer(aim, "bow")
		BowPose.setDrawAmount(character, 0, 0.16)
		task.wait(0.18)
		busy[character] = nil
	end)
	return true
end

return BowAttack
