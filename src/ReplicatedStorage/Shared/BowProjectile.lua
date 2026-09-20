--!strict
local Debris = game:GetService("Debris")

local BowProjectile = {}

function BowProjectile.create(parent: Instance, origin: Vector3, aim: Vector3, shooterCharacter: Model?, config): BasePart
	local delta = aim - origin
	local direction = delta.Magnitude > 0.01 and delta.Unit or Vector3.new(0, 0, -1)
	local arrow = Instance.new("Part")
	arrow.Name = "AnomalyArrow"
	arrow.Size = Vector3.new(0.09, 0.09, 2.4)
	arrow.Material = Enum.Material.Wood
	arrow.Color = Color3.fromRGB(112, 72, 38)
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = true
	arrow.Massless = false
	arrow.CFrame = CFrame.lookAt(origin + direction * 1.2, origin + direction * 2.2)
	arrow:SetAttribute("ProjectileType", "LongbowArrow")
	if shooterCharacter then
		arrow:SetAttribute("ShooterCharacter", shooterCharacter.Name)
	end

	local head = Instance.new("WedgePart")
	head.Name = "ArrowHead"
	head.Size = Vector3.new(0.22, 0.22, 0.38)
	head.Material = Enum.Material.Metal
	head.Color = Color3.fromRGB(180, 185, 192)
	head.CanCollide = false
	head.CanQuery = false
	head.CanTouch = false
	head.Massless = true
	head.CFrame = arrow.CFrame * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.pi / 2, 0)
	head.Parent = arrow
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = arrow
	headWeld.Part1 = head
	headWeld.Parent = head

	for index, angle in {0, 90} do
		local feather = Instance.new("Part")
		feather.Name = "Fletching" .. index
		feather.Size = Vector3.new(0.28, 0.035, 0.42)
		feather.Material = Enum.Material.Fabric
		feather.Color = Color3.fromRGB(145, 34, 34)
		feather.CanCollide = false
		feather.CanQuery = false
		feather.CanTouch = false
		feather.Massless = true
		feather.CFrame = arrow.CFrame * CFrame.new(0, 0, 0.88) * CFrame.Angles(0, 0, math.rad(angle))
		feather.Parent = arrow
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arrow
		weld.Part1 = feather
		weld.Parent = feather
	end

	arrow.Parent = parent
	arrow.AssemblyLinearVelocity = direction * config.Speed
	pcall(function() arrow:SetNetworkOwner(nil) end)
	Debris:AddItem(arrow, config.Lifetime)
	return arrow
end

return BowProjectile
