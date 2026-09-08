--!strict
-- Harbor.lua  (SERVIDOR)
-- O porto no fiorde: píeres de madeira, barracões, guindaste e DRAKKARS.
-- Referências: a foto do porto islandês (cidade encaixada entre montanha e mar)
-- e Vinland Saga (navios longos com escudos na amurada e vela listrada).

local Build = require(script.Parent.Build)
local C = Build.C

local Harbor = {}

local WATER_Y = -1 -- superfície da água (ver Terra.lua)
local SHORE_X = 250 -- onde a terra ainda é firme

-- ------------------------------------------------------------- drakkar
-- Casco alongado com proa e popa erguidas, mastro, vela e escudos.
local function longship(pos: Vector3, ang: number, sailA: Color3, sailB: Color3)
	local base = CFrame.new(pos) * CFrame.Angles(0, ang, 0)
	local L, W, H = 46, 9, 5

	-- casco (fatias que estreitam nas pontas: dá forma de barco, não caixa)
	local slices = 11
	for i = 0, slices - 1 do
		local t = (i + 0.5) / slices
		local taper = math.sin(t * math.pi) -- 0 nas pontas, 1 no meio
		local segW = 1.6 + W * taper * 0.9
		local segH = H * (0.55 + taper * 0.45)
		Build.part({
			Size = Vector3.new(segW, segH, L / slices + 0.3),
			CFrame = base * CFrame.new(0, segH / 2, -L / 2 + (i + 0.5) * (L / slices)),
			Color = C.WOOD_DARK,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- amurada (faixa clara ao longo do topo)
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(0.6, 1.1, L * 0.82),
			CFrame = base * CFrame.new(s * (W / 2 - 0.4), H * 0.92, 0),
			Color = C.WOOD,
			Material = Enum.Material.Wood,
		})
	end
	-- proa e popa erguidas (a curva característica)
	for _, s in { 1, -1 } do
		for i = 0, 5 do
			local t = i / 5
			Build.part({
				Size = Vector3.new(1.5, 1.6, 3.2),
				CFrame = base
					* CFrame.new(0, H * 0.8 + t * 7, s * (L / 2 - 1 + t * 5))
					* CFrame.Angles(math.rad(s * -42), 0, 0),
				Color = C.WOOD_DARK,
				Material = Enum.Material.Wood,
				CastShadow = false,
			})
		end
		-- cabeça entalhada na ponta
		Build.part({
			Size = Vector3.new(1.4, 2.6, 2.6),
			CFrame = base * CFrame.new(0, H * 0.8 + 8, s * (L / 2 + 4.2))
				* CFrame.Angles(math.rad(s * -20), 0, 0),
			Color = C.WOOD,
			Material = Enum.Material.Wood,
			CastShadow = false,
		})
	end

	-- escudos pendurados na amurada (Vinland Saga)
	local shieldColors = { C.BANNER, C.BANNER_2, C.PLASTER, C.WOOD }
	for _, s in { -1, 1 } do
		for i = 0, 8 do
			local z = -L * 0.36 + i * (L * 0.72 / 8)
			local col = shieldColors[(i % #shieldColors) + 1]
			Build.cyl(
				base * CFrame.new(s * (W / 2 + 0.15), H * 0.75, z) * CFrame.Angles(0, 0, 0),
				0.35,
				3.4,
				col,
				Enum.Material.Wood
			)
			Build.cyl(
				base * CFrame.new(s * (W / 2 + 0.3), H * 0.75, z),
				0.25,
				1,
				C.TIMBER,
				Enum.Material.Metal
			)
		end
	end

	-- mastro + vela listrada
	Build.post(pos + Vector3.new(0, H, 0), 26, 1.2, C.WOOD_DARK, Enum.Material.Wood)
	Build.part({ -- verga
		Size = Vector3.new(22, 0.8, 0.8),
		CFrame = base * CFrame.new(0, H + 22, 0),
		Color = C.WOOD_DARK,
		Material = Enum.Material.Wood,
	})
	for i = 0, 5 do
		Build.part({
			Size = Vector3.new(3.4, 14, 0.3),
			CFrame = base * CFrame.new(-10.2 + i * 3.6, H + 15, 0),
			Color = (i % 2 == 0) and sailA or sailB,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- remos
	for _, s in { -1, 1 } do
		for i = 0, 6 do
			Build.cyl(
				base * CFrame.new(s * (W / 2 + 2.6), H * 0.55, -L * 0.3 + i * 4.4)
					* CFrame.Angles(0, 0, math.rad(s * 28)),
				7,
				0.5,
				C.WOOD,
				Enum.Material.Wood
			)
		end
	end
end

-- ------------------------------------------------------------- píer
local function pier(startPos: Vector3, length: number, width: number, ang: number)
	local base = CFrame.new(startPos) * CFrame.Angles(0, ang, 0)
	-- tabuado
	Build.part({
		Size = Vector3.new(width, 0.6, length),
		CFrame = base * CFrame.new(0, WATER_Y + 3, length / 2),
		Color = C.WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	-- estacas
	local n = math.floor(length / 8)
	for i = 0, n do
		for _, s in { -1, 1 } do
			Build.post(
				(base * CFrame.new(s * (width / 2 - 0.8), WATER_Y - 4, i * (length / n))).Position,
				8,
				1.1,
				C.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	-- cabeços de amarração
	for i = 1, n - 1, 2 do
		for _, s in { -1, 1 } do
			Build.post(
				(base * CFrame.new(s * (width / 2 - 0.6), WATER_Y + 3.3, i * (length / n))).Position,
				2,
				0.9,
				C.WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
end

-- barracão do porto (telhado A, mesma técnica das casas)
local function shed(pos: Vector3, w: number, d: number, ang: number)
	local base = CFrame.new(pos) * CFrame.Angles(0, ang, 0)
	local h = 8
	Build.part({
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2, 0),
		Color = C.WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	local rw, rh = w + 3, w * 0.5
	local half = rw / 2
	local slope = math.sqrt(half * half + rh * rh)
	local pitch = math.atan2(rh, half)
	for _, s in { -1, 1 } do
		Build.part({
			Size = Vector3.new(slope, 0.7, d + 3),
			CFrame = base * CFrame.new(s * (rw / 4), h + rh / 2, 0) * CFrame.Angles(0, 0, -s * pitch),
			Color = C.ROOF_SHINGLE,
			Material = Enum.Material.WoodPlanks,
		})
	end
	for i = 0, 4 do
		local frac = (i + 0.5) / 5
		Build.part({
			Size = Vector3.new(w * (1 - frac), rh / 5 + 0.15, 0.6),
			CFrame = base * CFrame.new(0, h + frac * rh, d / 2 - 0.2),
			Color = C.WOOD,
			Material = Enum.Material.WoodPlanks,
			CastShadow = false,
		})
	end
	Build.part({
		Size = Vector3.new(w * 0.45, 6, 0.4),
		CFrame = base * CFrame.new(0, 3, d / 2 + 0.2),
		Color = C.WOOD_DARK,
		Material = Enum.Material.Wood,
	})
end

function Harbor.build()
	-- cais de pedra na beira
	Build.part({
		Size = Vector3.new(26, 8, 200),
		CFrame = CFrame.new(SHORE_X + 8, WATER_Y + 1, 0),
		Color = C.STONE,
		Material = Enum.Material.Cobblestone,
	})
	-- estrada ligando o portão da cidade ao porto
	Build.part({
		Size = Vector3.new(240, 0.5, 16),
		CFrame = CFrame.new(SHORE_X - 110, 0.3, -60),
		Color = C.DIRT,
		Material = Enum.Material.Ground,
		CanCollide = false,
	})

	-- três píeres avançando pro fiorde
	for i = -1, 1 do
		pier(Vector3.new(SHORE_X + 20, 0, i * 62), 70, 10, math.rad(-90))
	end

	-- barracões e guindaste
	shed(Vector3.new(SHORE_X - 14, 5, -34), 20, 14, math.rad(90))
	shed(Vector3.new(SHORE_X - 14, 5, 30), 24, 15, math.rad(90))
	Build.post(Vector3.new(SHORE_X + 12, WATER_Y + 5, 8), 20, 1.6, C.WOOD_DARK, Enum.Material.Wood)
	Build.part({
		Size = Vector3.new(16, 1, 1),
		CFrame = CFrame.new(SHORE_X + 19, WATER_Y + 24, 8),
		Color = C.WOOD_DARK,
		Material = Enum.Material.Wood,
	})
	Build.cyl(
		CFrame.new(SHORE_X + 26, WATER_Y + 18, 8) * CFrame.Angles(0, 0, math.rad(90)),
		9,
		0.3,
		C.TIMBER,
		Enum.Material.Metal
	)

	-- drakkars atracados
	longship(Vector3.new(SHORE_X + 52, WATER_Y - 1.5, -62), math.rad(4), C.BANNER, C.PLASTER)
	longship(Vector3.new(SHORE_X + 52, WATER_Y - 1.5, 0), math.rad(-3), C.BANNER_2, C.PLASTER)
	longship(Vector3.new(SHORE_X + 78, WATER_Y - 1.5, 46), math.rad(12), C.BANNER, C.PLASTER_2)

	-- carga espalhada no cais
	for _ = 1, 30 do
		local x = SHORE_X + math.random(-2, 16)
		local z = math.random(-90, 90)
		if math.random() < 0.5 then
			Build.barrel(Vector3.new(x, WATER_Y + 5, z))
		else
			Build.crate(Vector3.new(x, WATER_Y + 5, z), 2 + math.random() * 1.6)
		end
	end
	-- lanternas do cais
	for z = -80, 80, 40 do
		Build.lantern(Vector3.new(SHORE_X + 16, WATER_Y + 5, z), true)
	end
end

return Harbor
