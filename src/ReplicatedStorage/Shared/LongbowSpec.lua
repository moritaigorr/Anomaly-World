--!strict
local Shared = script.Parent

local function assertTrue(value: boolean, message: string)
	if not value then
		error(message, 2)
	end
end

return function()
	local bowPoseModule = Shared:FindFirstChild("BowPose")
	assertTrue(bowPoseModule ~= nil and bowPoseModule:IsA("ModuleScript"), "BowPose module is missing")
	local constants = require(Shared.Constants)
	assertTrue(type(constants.Bow) == "table", "Constants.Bow is missing")
	assertTrue(constants.Bow.Range >= 100, "Bow range is too short")
	assertTrue(constants.Bow.DrawTime > 0, "Bow draw time must be positive")

	local stanceClone = Shared.CombatStance:Clone()
	stanceClone.Name = "_LongbowSpecCombatStance"
	stanceClone.Parent = Shared
	local CombatStance = require(stanceClone)
	local character = Instance.new("Model")
	character.Name = "LongbowSpecCharacter"
	local hum = Instance.new("Humanoid")
	hum.Parent = character
	for _, name in {"RightHand", "LeftHand", "Right Arm", "Left Arm", "RightUpperArm", "LeftUpperArm", "HumanoidRootPart", "LowerTorso", "UpperTorso"} do
		local hand = Instance.new("Part")
		hand.Name = name
		hand.Size = Vector3.new(1, 1, 1)
		hand.Anchored = true
		hand.Parent = character
	end
	local function makeConstraint(name: string, part0: BasePart, part1: BasePart): AnimationConstraint
		local attachment0 = Instance.new("Attachment")
		attachment0.Parent = part0
		local attachment1 = Instance.new("Attachment")
		attachment1.Parent = part1
		local constraint = Instance.new("AnimationConstraint")
		constraint.Name = name
		constraint.Attachment0 = attachment0
		constraint.Attachment1 = attachment1
		constraint.Parent = part1
		return constraint
	end
	local rootJoint = makeConstraint("Root", character.HumanoidRootPart :: BasePart, character.LowerTorso :: BasePart)
	makeConstraint("Waist", character.LowerTorso :: BasePart, character.UpperTorso :: BasePart)
	character.Parent = workspace

	CombatStance.setWeaponActive(character, "bow", true)
	local bow = character:FindFirstChild("AnomalyBow")
	assertTrue(bow ~= nil and bow:IsA("Model"), "Longbow was not created")
	local limbCount = 0
	for _, child in bow:GetChildren() do
		if child:IsA("BasePart") and string.match(child.Name, "^Limb") then
			limbCount += 1
		end
	end
	assertTrue(limbCount == 10, "Longbow must have 10 curved limb segments")
	assertTrue(bow:FindFirstChild("StringUpper") ~= nil, "Upper dynamic string is missing")
	assertTrue(bow:FindFirstChild("StringLower") ~= nil, "Lower dynamic string is missing")
	assertTrue(bow:FindFirstChild("ArrowRest") ~= nil, "Arrow rest is missing")
	local extent = bow:GetExtentsSize()
	assertTrue(math.max(extent.X, extent.Y, extent.Z) >= 4.5, "Longbow must be at least 4.5 studs tip-to-tip")
	assertTrue(bow:GetAttribute("GripHand") == "Left", "Longbow must be held in the left hand")
	local grip = bow:FindFirstChild("Grip")
	assertTrue(grip ~= nil and grip:IsA("BasePart"), "Longbow grip is missing")
	assertTrue(grip:FindFirstChild("BowGripMotor") ~= nil, "Bow grip motor is missing")

	CombatStance.setWeaponActive(character, "bow", false)
	CombatStance.setWeaponActive(character, "bow", true)
	local duplicateCount = 0
	for _, child in character:GetChildren() do
		if child.Name == "AnomalyBow" then duplicateCount += 1 end
	end
	assertTrue(duplicateCount == 1, "Equipping the longbow duplicated its model")

	local poseClone = bowPoseModule:Clone()
	poseClone.Name = "_LongbowSpecBowPose"
	poseClone.Parent = Shared
	local BowPose = require(poseClone)
	assertTrue(type(BowPose.applySideOnTransform) == "function", "Side-on torso transform is missing")
	local sideOn = BowPose.applySideOnTransform(CFrame.identity)
	assertTrue(math.abs(sideOn.LookVector.X) > 0.5, "Side-on torso transform does not rotate the body enough")
	local rootTransformBefore = rootJoint.Transform
	BowPose.activate(character)
	assertTrue(math.abs(rootJoint.Transform.LookVector.X) > 0.35, "Side-on bow stance must rotate the hips and legs, not only the torso")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local leftTarget = character:FindFirstChild("_BowLeftTarget") :: BasePart
	local rightTarget = character:FindFirstChild("_BowRightTarget") :: BasePart
	assertTrue(leftTarget ~= nil and rightTarget ~= nil, "Bow pose targets were not created")
	local rightIK = hum:FindFirstChild("_BowRightIK") :: IKControl?
	-- The wrist on this rig twists only +/-10 degrees, so a Transform (6DOF)
	-- target is unsatisfiable and the solver answers by throwing the arm above
	-- the head. Position keeps the solve inside what the joints can do.
	assertTrue(rightIK ~= nil and rightIK.Type == Enum.IKControlType.Position, "Rear bow hand must aim at a position, not a full rotation this rig cannot reach")
	assertTrue(rightIK.SmoothTime > 0, "Rear bow arm needs damping or the walk animation shakes it")
	local leftLocalBefore = root.CFrame:PointToObjectSpace(leftTarget.Position)
	root.CFrame *= CFrame.new(0, 0, -4)
	local leftLocalAfter = root.CFrame:PointToObjectSpace(leftTarget.Position)
	assertTrue((leftLocalAfter - leftLocalBefore).Magnitude < 0.02, "Bow arm target does not follow the moving character")
	local rightLocal = root.CFrame:PointToObjectSpace(rightTarget.Position)
	assertTrue(math.abs(leftLocalAfter.Z - rightLocal.Z) > math.abs(leftLocalAfter.X - rightLocal.X), "Bow hands are not aligned front-to-back for a side-on stance")
	BowPose.deactivate(character)
	assertTrue(rootJoint.Transform:FuzzyEq(rootTransformBefore, 0.001), "Bow stance did not restore the full-body transform")

	-- A control left behind by a lost pose state must be replaced, not joined:
	-- two solvers on one arm fight and fling it around.
	local stray = Instance.new("IKControl")
	stray.Name = "_BowRightIK"
	stray.Parent = hum
	BowPose.activate(character)
	local rightIKCount = 0
	for _, child in hum:GetChildren() do
		if child:IsA("IKControl") and child.Name == "_BowRightIK" then rightIKCount += 1 end
	end
	assertTrue(rightIKCount == 1, "A leftover IKControl was duplicated instead of replaced")
	BowPose.deactivate(character)
	poseClone:Destroy()

	local attackModule = Shared:FindFirstChild("BowAttack")
	assertTrue(attackModule ~= nil and attackModule:IsA("ModuleScript"), "BowAttack module is missing")
	local attackClone = attackModule:Clone()
	attackClone.Parent = Shared
	local BowAttack = require(attackClone)
	local firedWeapon: string? = nil
	local started = BowAttack.shoot(character, nil, function(_, weapon)
		firedWeapon = weapon
	end)
	assertTrue(started, "Bow attack did not start")
	task.wait(constants.Bow.DrawTime + 0.12)
	assertTrue(firedWeapon == "bow", "Bow attack did not route the bow weapon to the server")
	attackClone:Destroy()

	local projectileModule = Shared:FindFirstChild("BowProjectile")
	assertTrue(projectileModule ~= nil and projectileModule:IsA("ModuleScript"), "BowProjectile module is missing")
	local projectileClone = projectileModule:Clone()
	projectileClone.Parent = Shared
	local BowProjectile = require(projectileClone)
	local arrow = BowProjectile.create(workspace, Vector3.new(0, 10, 0), Vector3.new(0, 10, -100), character, constants.Bow)
	assertTrue(arrow.Name == "AnomalyArrow", "Bow projectile has the wrong name")
	assertTrue(math.abs(arrow.AssemblyLinearVelocity.Magnitude - constants.Bow.Speed) < 0.1, "Arrow speed does not match bow constants")
	assertTrue(arrow.CFrame.LookVector.Z < -0.9, "Arrow does not point toward the aim position")
	arrow:Destroy()
	projectileClone:Destroy()

	character:Destroy()
	stanceClone:Destroy()
	return true
end
