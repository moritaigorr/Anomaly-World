--!strict
local RunService = game:GetService("RunService")

local BowPose = {}

local LEFT_TARGET_OFFSET = CFrame.new(-0.35, 0.55, -1.85)
local RIGHT_IDLE_OFFSET = CFrame.new(0.65, 0.55, -0.2)
local RIGHT_DRAW_OFFSET = CFrame.new(0.65, 0.72, 0.28)
local BODY_SIDE_ON_YAW = math.rad(-30)
local TORSO_SIDE_ON_YAW = math.rad(-15)
local SIDE_ON_YAW = BODY_SIDE_ON_YAW + TORSO_SIDE_ON_YAW

type PoseState = {
	connection: RBXScriptConnection?,
	preSimulationConnection: RBXScriptConnection?,
	leftTarget: BasePart,
	rightTarget: BasePart,
	leftTargetMotor: Motor6D,
	rightTargetMotor: Motor6D,
	leftIK: IKControl?,
	rightIK: IKControl?,
	rootJoint: Motor6D?,
	rootJointC0: CFrame?,
	rootConstraint: AnimationConstraint?,
	rootTransform: CFrame?,
	waist: Motor6D?,
	waistC0: CFrame?,
	waistConstraint: AnimationConstraint?,
	waistTransform: CFrame?,
	draw: number,
	tweenToken: number,
}
local states: {[Model]: PoseState} = setmetatable({}, {__mode = "k"}) :: any

local function hand(character: Model, side: string): BasePart?
	return (character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")) :: BasePart?
end

local function makeTarget(character: Model, root: BasePart, name: string, offset: CFrame): (BasePart, Motor6D)
	local old = character:FindFirstChild(name)
	if old then old:Destroy() end
	local target = Instance.new("Part")
	target.Name = name
	target.Size = Vector3.new(0.12, 0.12, 0.12)
	target.Transparency = 1
	target.Anchored = false
	target.Massless = true
	target.CanCollide = false
	target.CanQuery = false
	target.CanTouch = false
	target.CFrame = root.CFrame * offset
	target.Parent = character

	local motor = Instance.new("Motor6D")
	motor.Name = name .. "Motor"
	motor.Part0 = root
	motor.Part1 = target
	motor.C0 = offset
	motor.C1 = CFrame.identity
	motor.Parent = target
	return target, motor
end

local function makeIK(humanoid: Humanoid, character: Model, side: string, target: BasePart): IKControl?
	local upper = character:FindFirstChild(side .. "UpperArm")
	local endPart = hand(character, side)
	if not upper or not endPart then return nil end
	local name = "_Bow" .. side .. "IK"
	-- activate() can run again without a matching deactivate() (respawn, or a
	-- second equip after the pose state was lost). Replace rather than add:
	-- two controls left on the same arm fight and throw it around.
	local previous = humanoid:FindFirstChild(name)
	if previous then previous:Destroy() end
	local ik = Instance.new("IKControl")
	ik.Name = name
	-- Position, never Transform. This rig's wrist twists only +/-10 degrees, so
	-- a full rotation target is unsatisfiable and the solver hunts for it by
	-- flinging the arm over the head.
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upper
	ik.EndEffector = endPart
	ik.Target = target
	ik.Weight = 1
	-- The draw arm sits where the walk animation swings hardest and needs a
	-- little damping; the bow arm holds steadier with none.
	ik.SmoothTime = if side == "Right" then 0.15 else 0
	ik.Enabled = true
	ik.Parent = humanoid
	return ik
end

local function findMotor(character: Model, name: string): Motor6D?
	local joint = character:FindFirstChild(name, true)
	return joint and joint:IsA("Motor6D") and joint or nil
end

local function findConstraint(character: Model, name: string): AnimationConstraint?
	local joint = character:FindFirstChild(name, true)
	return joint and joint:IsA("AnimationConstraint") and joint or nil
end

function BowPose.applySideOnTransform(base: CFrame): CFrame
	return base * CFrame.Angles(0, SIDE_ON_YAW, 0)
end

local function applyBodySideOnTransform(base: CFrame): CFrame
	return base * CFrame.Angles(0, BODY_SIDE_ON_YAW, 0)
end

local function applyTorsoSideOnTransform(base: CFrame): CFrame
	return base * CFrame.Angles(0, TORSO_SIDE_ON_YAW, 0)
end

local function setLine(part: BasePart?, from: Vector3, to: Vector3)
	if not part then return end
	local length = math.max((to - from).Magnitude, 0.03)
	part.Size = Vector3.new(0.035, length, 0.035)
	part.CFrame = CFrame.lookAt((from + to) * 0.5, to) * CFrame.Angles(math.pi / 2, 0, 0)
end

local function update(character: Model, state: PoseState)
	if not character.Parent then
		BowPose.deactivate(character)
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		state.leftTargetMotor.C0 = LEFT_TARGET_OFFSET
		state.rightTargetMotor.C0 = RIGHT_IDLE_OFFSET:Lerp(RIGHT_DRAW_OFFSET, state.draw)
	end

	local bow = character:FindFirstChild("AnomalyBow")
	if not bow or not bow:IsA("Model") then return end
	local grip = bow:FindFirstChild("Grip") :: BasePart?
	local gripMotor = grip and grip:FindFirstChild("BowGripMotor") :: Motor6D?
	local leftHand = hand(character, "Left")
	if root and leftHand and gripMotor then
		local desiredGrip = CFrame.fromMatrix(
			leftHand.Position,
			root.CFrame.UpVector,
			-root.CFrame.LookVector,
			root.CFrame.RightVector
		)
		gripMotor.C0 = leftHand.CFrame:ToObjectSpace(desiredGrip)
	end

	local top = bow:FindFirstChild("NockTop") :: BasePart?
	local bottom = bow:FindFirstChild("NockBottom") :: BasePart?
	local upper = bow:FindFirstChild("StringUpper") :: BasePart?
	local lower = bow:FindFirstChild("StringLower") :: BasePart?
	if not (top and bottom and upper and lower) then return end
	-- An undrawn string is straight between the nocks. The arrow rest sits a
	-- stud in front of that line, so anchoring to it bent the string forward
	-- into a slingshot V.
	local braced = (top.Position + bottom.Position) * 0.5
	local center = braced:Lerp(state.rightTarget.Position, state.draw)
	setLine(upper, top.Position, center)
	setLine(lower, center, bottom.Position)
end

function BowPose.activate(character: Model?)
	if not character or states[character] then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then return end

	local leftTarget, leftTargetMotor = makeTarget(character, root, "_BowLeftTarget", LEFT_TARGET_OFFSET)
	local rightTarget, rightTargetMotor = makeTarget(character, root, "_BowRightTarget", RIGHT_IDLE_OFFSET)
	local rootJoint = findMotor(character, "Root")
	local rootJointC0 = rootJoint and rootJoint.C0 or nil
	local rootConstraint = findConstraint(character, "Root")
	local rootTransform = rootConstraint and rootConstraint.Transform or nil
	local waist = findMotor(character, "Waist")
	local waistC0 = waist and waist.C0 or nil
	local waistConstraint = findConstraint(character, "Waist")
	local waistTransform = waistConstraint and waistConstraint.Transform or nil
	if rootJoint and rootJointC0 then
		rootJoint.C0 = applyBodySideOnTransform(rootJointC0)
	end
	if rootConstraint and rootTransform then
		rootConstraint.Transform = applyBodySideOnTransform(rootTransform)
	end
	if waist and waistC0 then
		waist.C0 = applyTorsoSideOnTransform(waistC0)
	end
	if waistConstraint and waistTransform then
		waistConstraint.Transform = applyTorsoSideOnTransform(waistTransform)
	end

	local state: PoseState = {
		connection = nil,
		preSimulationConnection = nil,
		leftTarget = leftTarget,
		rightTarget = rightTarget,
		leftTargetMotor = leftTargetMotor,
		rightTargetMotor = rightTargetMotor,
		leftIK = makeIK(humanoid, character, "Left", leftTarget),
		rightIK = makeIK(humanoid, character, "Right", rightTarget),
		rootJoint = rootJoint,
		rootJointC0 = rootJointC0,
		rootConstraint = rootConstraint,
		rootTransform = rootTransform,
		waist = waist,
		waistC0 = waistC0,
		waistConstraint = waistConstraint,
		waistTransform = waistTransform,
		draw = 0,
		tweenToken = 0,
	}
	states[character] = state
	character:SetAttribute("_BowDrawAmount", 0)
	character:SetAttribute("_BowSideOn", true)
	state.preSimulationConnection = RunService.PreSimulation:Connect(function()
		if state.rootConstraint and state.rootConstraint.Parent then
			state.rootConstraint.Transform = applyBodySideOnTransform(state.rootConstraint.Transform)
		end
		if state.waistConstraint and state.waistConstraint.Parent then
			state.waistConstraint.Transform = applyTorsoSideOnTransform(state.waistConstraint.Transform)
		end
	end)
	state.connection = RunService.RenderStepped:Connect(function()
		update(character, state)
	end)
	update(character, state)
end

function BowPose.deactivate(character: Model?)
	if not character then return end
	local state = states[character]
	if not state then return end
	state.tweenToken += 1
	if state.connection then state.connection:Disconnect() end
	if state.preSimulationConnection then state.preSimulationConnection:Disconnect() end
	if state.leftIK then state.leftIK:Destroy() end
	if state.rightIK then state.rightIK:Destroy() end
	if state.rootJoint and state.rootJoint.Parent and state.rootJointC0 then
		state.rootJoint.C0 = state.rootJointC0
	end
	if state.rootConstraint and state.rootConstraint.Parent and state.rootTransform then
		state.rootConstraint.Transform = state.rootTransform
	end
	if state.waist and state.waist.Parent and state.waistC0 then
		state.waist.C0 = state.waistC0
	end
	if state.waistConstraint and state.waistConstraint.Parent and state.waistTransform then
		state.waistConstraint.Transform = state.waistTransform
	end
	state.leftTarget:Destroy()
	state.rightTarget:Destroy()
	character:SetAttribute("_BowDrawAmount", nil)
	character:SetAttribute("_BowSideOn", nil)
	states[character] = nil
end

function BowPose.isActive(character: Model?): boolean
	return character ~= nil and states[character] ~= nil
end

function BowPose.getDrawAmount(character: Model?): number
	local state = character and states[character]
	return state and state.draw or 0
end

function BowPose.setDrawAmount(character: Model?, amount: number, duration: number?)
	if not character then return end
	if not states[character] then BowPose.activate(character) end
	local state = states[character]
	if not state then return end
	local goal = math.clamp(amount, 0, 1)
	state.tweenToken += 1
	local token = state.tweenToken
	local start = state.draw
	local seconds = math.max(duration or 0, 0)
	if seconds == 0 then
		state.draw = goal
		character:SetAttribute("_BowDrawAmount", goal)
		update(character, state)
		return
	end
	task.spawn(function()
		local began = os.clock()
		repeat
			if not states[character] or state.tweenToken ~= token then return end
			local alpha = math.clamp((os.clock() - began) / seconds, 0, 1)
			state.draw = start + (goal - start) * (1 - (1 - alpha) ^ 2)
			character:SetAttribute("_BowDrawAmount", state.draw)
			update(character, state)
			task.wait()
		until alpha >= 1
		state.draw = goal
		character:SetAttribute("_BowDrawAmount", goal)
		update(character, state)
	end)
end

return BowPose
