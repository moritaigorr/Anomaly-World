--!strict
-- CombatStance.lua
-- Equipamento visual: várias armas pra escolher, mas só uma segurada por vez
-- (igual todo RPG — a mão direita não segura duas coisas), mais a aura do
-- poder na mão esquerda. Só visual — o dano continua vindo só da habilidade
-- (Z/X/C/V), não da arma. Protótipo cinza, sem malha/animação importada.
--
-- NOTA: sem pose de braço. O avatar atual do Roblox usa um rig novo com
-- AnimationConstraint + BallSocketConstraint (fisicamente simulado) em vez
-- do Motor6D clássico — escrever o CFrame dos braços à força briga com essa
-- física e arremessa o personagem pelo mapa. Uma pose de guarda de verdade,
-- nesse rig, precisa de uma Animation de verdade (Studio -> Avatar ->
-- Animation Editor) tocada pelo Animator. Fica pro próximo passo.

local CombatStance = {}

local SWORD_COLOR = Color3.fromRGB(205, 210, 220)
local HILT_COLOR = Color3.fromRGB(35, 32, 30)
local POMMEL_COLOR = Color3.fromRGB(150, 122, 40) -- latão, contraste com o aço
local HAMMER_HEAD_COLOR = Color3.fromRGB(120, 126, 134)
local LEATHER_COLOR = Color3.fromRGB(74, 50, 32) -- embrulho de couro nos cabos, mais avermelhado que o resto
local AURA_COLOR = Color3.fromRGB(47, 212, 194)

local function findHands(character: Model, hum: Humanoid): (BasePart?, BasePart?)
	if hum.RigType == Enum.HumanoidRigType.R15 then
		return character:FindFirstChild("RightHand") :: BasePart?, character:FindFirstChild("LeftHand") :: BasePart?
	end
	return character:FindFirstChild("Right Arm") :: BasePart?, character:FindFirstChild("Left Arm") :: BasePart?
end

local function weldTo(host: BasePart, piece: BasePart)
	piece.Anchored = false
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = piece
	weld.Parent = piece
end

-- pegada: onde o punho fica dentro da mão e pra que eixo a arma aponta.
-- A mão do rig atual tem os eixos locais TROCADOS do que parece óbvio — o
-- eixo que "parece" pra cima (Y local) na verdade aponta pra trás do
-- personagem. O eixo que realmente sobe é o Z local (LookVector aponta pra
-- baixo, então -LookVector, ou seja +Z, aponta pra cima). Por isso a base
-- da transformação gira -90° em X: isso faz o "para cima" da arma (que a
-- gente constrói ao longo do eixo Y de cada peça) coincidir com o +Z real
-- da mão em vez do Y errado. Compartilhada por todas as armas abaixo.
local GRIP_TRANSFORM = CFrame.new(0, -0.02, 0.06) * CFrame.Angles(math.rad(-90), 0, math.rad(8))

local function finishWeapon(model: Model, rightHand: BasePart, primary: BasePart)
	for _, piece in model:GetChildren() do
		local part = piece :: BasePart
		weldTo(rightHand, part)
		part.Transparency = 1 -- começa guardada; só aparece quando equipada
	end
	model.PrimaryPart = primary
	model.Parent = rightHand.Parent
end

-- ============================== armas ==============================

-- espada: pomo, cabo cilíndrico, guarda em cruz, lâmina com friso e ponta
-- em cunha (mesma que já existia)
local function buildSword(rightHand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "AnomalySword"

	local pommel = Instance.new("Part")
	pommel.Name = "Pommel"
	pommel.Shape = Enum.PartType.Ball
	pommel.Size = Vector3.new(0.22, 0.22, 0.22)
	pommel.Material = Enum.Material.Metal
	pommel.Color = POMMEL_COLOR
	pommel.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, -0.32, 0)
	pommel.Parent = model

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Shape = Enum.PartType.Cylinder
	grip.Size = Vector3.new(0.5, 0.24, 0.24)
	grip.Material = Enum.Material.Fabric
	grip.Color = HILT_COLOR
	grip.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.Angles(0, 0, math.rad(90))
	grip.Parent = model

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(1.0, 0.14, 0.26)
	guard.Material = Enum.Material.Metal
	guard.Color = POMMEL_COLOR
	guard.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 0.32, 0)
	guard.Parent = model

	local bladeBody = Instance.new("Part")
	bladeBody.Name = "Blade"
	bladeBody.Size = Vector3.new(0.16, 1.9, 0.46)
	bladeBody.Material = Enum.Material.Metal
	bladeBody.Color = SWORD_COLOR
	bladeBody.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 0.32 + 0.07 + 0.95, 0)
	bladeBody.Parent = model

	local fuller = Instance.new("Part")
	fuller.Name = "Fuller"
	fuller.Size = Vector3.new(0.06, 1.8, 0.16)
	fuller.Material = Enum.Material.Metal
	fuller.Color = Color3.fromRGB(165, 172, 182)
	fuller.CFrame = bladeBody.CFrame * CFrame.new(0.06, 0, 0)
	fuller.Parent = model

	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.5, 0.16, 0.46)
	tip.Material = Enum.Material.Metal
	tip.Color = SWORD_COLOR
	tip.CFrame = bladeBody.CFrame * CFrame.new(0, 1.9 / 2 + 0.25, 0) * CFrame.Angles(0, 0, math.rad(-90))
	tip.Parent = model

	finishWeapon(model, rightHand, bladeBody)
	return model
end

-- adaga: a mesma silhueta da espada, só compacta — cabo curto com pomo,
-- guarda pequena, lâmina curta com friso e ponta em cunha
local function buildDagger(rightHand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "AnomalyDagger"

	local pommel = Instance.new("Part")
	pommel.Name = "Pommel"
	pommel.Shape = Enum.PartType.Ball
	pommel.Size = Vector3.new(0.15, 0.15, 0.15)
	pommel.Material = Enum.Material.Metal
	pommel.Color = POMMEL_COLOR
	pommel.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, -0.2, 0)
	pommel.Parent = model

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Shape = Enum.PartType.Cylinder
	grip.Size = Vector3.new(0.32, 0.18, 0.18)
	grip.Material = Enum.Material.Fabric
	grip.Color = HILT_COLOR
	grip.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.Angles(0, 0, math.rad(90))
	grip.Parent = model

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(0.55, 0.1, 0.2)
	guard.Material = Enum.Material.Metal
	guard.Color = POMMEL_COLOR
	guard.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 0.2, 0)
	guard.Parent = model

	local bladeBody = Instance.new("Part")
	bladeBody.Name = "Blade"
	bladeBody.Size = Vector3.new(0.12, 0.85, 0.3)
	bladeBody.Material = Enum.Material.Metal
	bladeBody.Color = SWORD_COLOR
	bladeBody.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 0.2 + 0.05 + 0.425, 0)
	bladeBody.Parent = model

	local fuller = Instance.new("Part")
	fuller.Name = "Fuller"
	fuller.Size = Vector3.new(0.05, 0.78, 0.1)
	fuller.Material = Enum.Material.Metal
	fuller.Color = Color3.fromRGB(165, 172, 182)
	fuller.CFrame = bladeBody.CFrame * CFrame.new(0.045, 0, 0)
	fuller.Parent = model

	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.3, 0.12, 0.3)
	tip.Material = Enum.Material.Metal
	tip.Color = SWORD_COLOR
	tip.CFrame = bladeBody.CFrame * CFrame.new(0, 0.85 / 2 + 0.15, 0) * CFrame.Angles(0, 0, math.rad(-90))
	tip.Parent = model

	finishWeapon(model, rightHand, bladeBody)
	return model
end

-- machado: cabo de madeira com embrulho de couro + pomo, colar de metal,
-- cabeça em cunha (3 segmentos pra curva mais macia) saindo pro lado, e um
-- bico espigado do lado oposto (contrapeso, clássico de machado de fantasia)
local function buildAxe(rightHand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "AnomalyAxe"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(1.5, 0.14, 0.14)
	handle.Material = Enum.Material.Wood
	handle.Color = HILT_COLOR
	handle.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
	handle.Parent = model

	local wrap = Instance.new("Part")
	wrap.Name = "Wrap"
	wrap.Shape = Enum.PartType.Cylinder
	wrap.Size = Vector3.new(0.34, 0.17, 0.17)
	wrap.Material = Enum.Material.Fabric
	wrap.Color = LEATHER_COLOR
	wrap.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, -0.35, 0) * CFrame.Angles(0, 0, math.rad(90))
	wrap.Parent = model

	local buttCap = Instance.new("Part")
	buttCap.Name = "ButtCap"
	buttCap.Shape = Enum.PartType.Ball
	buttCap.Size = Vector3.new(0.17, 0.17, 0.17)
	buttCap.Material = Enum.Material.Metal
	buttCap.Color = POMMEL_COLOR
	buttCap.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, -0.55, 0)
	buttCap.Parent = model

	local collar = Instance.new("Part")
	collar.Name = "Collar"
	collar.Size = Vector3.new(0.2, 0.34, 0.34)
	collar.Material = Enum.Material.Metal
	collar.Color = POMMEL_COLOR
	collar.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 1.0, 0)
	collar.Parent = model

	-- bico traseiro: espigão pequeno do lado oposto à lâmina
	local spike = Instance.new("WedgePart")
	spike.Name = "Spike"
	spike.Size = Vector3.new(0.28, 0.18, 0.18)
	spike.Material = Enum.Material.Metal
	spike.Color = SWORD_COLOR
	spike.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(-0.2, 1.0, 0) * CFrame.Angles(0, 0, math.rad(-90))
	spike.Parent = model

	local bladeTop = Instance.new("WedgePart")
	bladeTop.Name = "BladeTop"
	bladeTop.Size = Vector3.new(0.42, 0.34, 0.5)
	bladeTop.Material = Enum.Material.Metal
	bladeTop.Color = SWORD_COLOR
	bladeTop.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0.42, 1.2, 0)
	bladeTop.Parent = model

	local bladeMid = Instance.new("WedgePart")
	bladeMid.Name = "BladeMid"
	bladeMid.Size = Vector3.new(0.55, 0.34, 0.5)
	bladeMid.Material = Enum.Material.Metal
	bladeMid.Color = SWORD_COLOR
	bladeMid.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0.36, 1.0, 0)
	bladeMid.Parent = model

	local bladeBottom = Instance.new("WedgePart")
	bladeBottom.Name = "BladeBottom"
	bladeBottom.Size = Vector3.new(0.42, 0.34, 0.5)
	bladeBottom.Material = Enum.Material.Metal
	bladeBottom.Color = SWORD_COLOR
	bladeBottom.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0.3, 0.8, 0) * CFrame.Angles(math.rad(180), 0, 0)
	bladeBottom.Parent = model

	finishWeapon(model, rightHand, handle)
	return model
end

-- martelo: cabo com embrulho de couro + pomo, e uma cabeça em "barbell" —
-- um núcleo fino ligando duas faces de impacto maiores, silhueta mais de
-- marreta de guerra do que um bloco liso
local function buildHammer(rightHand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "AnomalyHammer"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(1.5, 0.15, 0.15)
	handle.Material = Enum.Material.Wood
	handle.Color = HILT_COLOR
	handle.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90))
	handle.Parent = model

	local wrap = Instance.new("Part")
	wrap.Name = "Wrap"
	wrap.Shape = Enum.PartType.Cylinder
	wrap.Size = Vector3.new(0.36, 0.18, 0.18)
	wrap.Material = Enum.Material.Fabric
	wrap.Color = LEATHER_COLOR
	wrap.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, -0.32, 0) * CFrame.Angles(0, 0, math.rad(90))
	wrap.Parent = model

	local buttCap = Instance.new("Part")
	buttCap.Name = "ButtCap"
	buttCap.Shape = Enum.PartType.Ball
	buttCap.Size = Vector3.new(0.18, 0.18, 0.18)
	buttCap.Material = Enum.Material.Metal
	buttCap.Color = HAMMER_HEAD_COLOR
	buttCap.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, -0.52, 0)
	buttCap.Parent = model

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.new(0.7, 0.22, 0.24)
	core.Material = Enum.Material.Metal
	core.Color = HAMMER_HEAD_COLOR
	core.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0, 1.05, 0)
	core.Parent = model

	local faceA = Instance.new("Part")
	faceA.Name = "FaceA"
	faceA.Size = Vector3.new(0.36, 0.4, 0.4)
	faceA.Material = Enum.Material.Metal
	faceA.Color = HAMMER_HEAD_COLOR
	faceA.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(0.32, 1.05, 0)
	faceA.Parent = model

	local faceB = Instance.new("Part")
	faceB.Name = "FaceB"
	faceB.Size = Vector3.new(0.36, 0.4, 0.4)
	faceB.Material = Enum.Material.Metal
	faceB.Color = HAMMER_HEAD_COLOR
	faceB.CFrame = rightHand.CFrame * GRIP_TRANSFORM * CFrame.new(-0.32, 1.05, 0)
	faceB.Parent = model

	finishWeapon(model, rightHand, handle)
	return model
end

-- arco: cabo curto no meio + dois braços que curvam pra fora (cada um feito
-- de segmentos retos encadeados, indo do cabo até a ponta) + a corda esticada
-- ligando as duas pontas. Sem malha, então a curva é aproximada — dá pro
-- protótipo cinza.
local function buildBow(rightHand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "AnomalyBow"

	local baseCFrame = rightHand.CFrame * GRIP_TRANSFORM

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Shape = Enum.PartType.Cylinder
	grip.Size = Vector3.new(0.5, 0.14, 0.2)
	grip.Material = Enum.Material.Wood
	grip.Color = HILT_COLOR
	grip.CFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(90))
	grip.Parent = model

	local wrap = Instance.new("Part")
	wrap.Name = "Wrap"
	wrap.Shape = Enum.PartType.Cylinder
	wrap.Size = Vector3.new(0.22, 0.17, 0.24)
	wrap.Material = Enum.Material.Fabric
	wrap.Color = LEATHER_COLOR
	wrap.CFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(90))
	wrap.Parent = model

	local SEG_LEN = 0.55
	local SEG_ANGLE = math.rad(18)
	local SEG_COUNT = 3
	local THICK = 0.1

	-- monta um braço do arco: uma cadeia de segmentos que vai encurvando,
	-- devolve as CFrames do meio de cada segmento (pra criar as Parts) e a
	-- CFrame final (a ponta, onde a corda amarra)
	local function buildLimb(startCFrame: CFrame, bendSign: number): ({ CFrame }, CFrame)
		local segments: { CFrame } = {}
		local cf = startCFrame
		for _ = 1, SEG_COUNT do
			cf = cf * CFrame.Angles(0, 0, SEG_ANGLE * bendSign)
			table.insert(segments, cf * CFrame.new(0, SEG_LEN / 2, 0))
			cf = cf * CFrame.new(0, SEG_LEN, 0)
		end
		return segments, cf
	end

	local upperSegments, upperTip = buildLimb(baseCFrame * CFrame.new(0, 0.25, 0), 1)
	local lowerSegments, lowerTip = buildLimb(baseCFrame * CFrame.new(0, -0.25, 0), -1)

	local limbIndex = 0
	for _, segCFrame in upperSegments do
		limbIndex += 1
		local part = Instance.new("Part")
		part.Name = "Limb" .. limbIndex
		part.Size = Vector3.new(THICK, SEG_LEN, THICK * 1.6)
		part.Material = Enum.Material.Wood
		part.Color = HILT_COLOR
		part.CFrame = segCFrame
		part.Parent = model
	end
	for _, segCFrame in lowerSegments do
		limbIndex += 1
		local part = Instance.new("Part")
		part.Name = "Limb" .. limbIndex
		part.Size = Vector3.new(THICK, SEG_LEN, THICK * 1.6)
		part.Material = Enum.Material.Wood
		part.Color = HILT_COLOR
		part.CFrame = segCFrame
		part.Parent = model
	end

	-- nocks: capinhas nas pontas dos braços, onde a corda amarra
	local nockTop = Instance.new("Part")
	nockTop.Name = "NockTop"
	nockTop.Shape = Enum.PartType.Ball
	nockTop.Size = Vector3.new(0.13, 0.13, 0.13)
	nockTop.Material = Enum.Material.Metal
	nockTop.Color = POMMEL_COLOR
	nockTop.CFrame = upperTip
	nockTop.Parent = model

	local nockBottom = Instance.new("Part")
	nockBottom.Name = "NockBottom"
	nockBottom.Shape = Enum.PartType.Ball
	nockBottom.Size = Vector3.new(0.13, 0.13, 0.13)
	nockBottom.Material = Enum.Material.Metal
	nockBottom.Color = POMMEL_COLOR
	nockBottom.CFrame = lowerTip
	nockBottom.Parent = model

	-- corda: reta, ligando as duas pontas dos braços
	local topPos, bottomPos = upperTip.Position, lowerTip.Position
	local mid = (topPos + bottomPos) / 2
	local span = (topPos - bottomPos).Magnitude
	local bowString = Instance.new("Part")
	bowString.Name = "String"
	bowString.Size = Vector3.new(0.03, span, 0.03)
	bowString.Material = Enum.Material.Neon
	bowString.Color = Color3.fromRGB(230, 230, 230)
	bowString.CFrame = CFrame.new(mid, topPos) * CFrame.Angles(math.rad(90), 0, 0)
	bowString.Parent = model

	finishWeapon(model, rightHand, grip)
	return model
end

export type WeaponId = "sword" | "dagger" | "axe" | "hammer" | "bow"

local WEAPON_DEFS: { [string]: { name: string, build: (BasePart) -> Model } } = {
	sword = { name = "Espada Anômala", build = buildSword },
	dagger = { name = "Adaga Anômala", build = buildDagger },
	axe = { name = "Machado Anômalo", build = buildAxe },
	hammer = { name = "Martelo Anômalo", build = buildHammer },
	bow = { name = "Arco Anômalo", build = buildBow },
}

-- ordem de exibição no inventário
CombatStance.WeaponOrder = { "sword", "dagger", "axe", "hammer", "bow" }

function CombatStance.getWeaponName(weaponId: string): string?
	local def = WEAPON_DEFS[weaponId]
	return def and def.name
end

-- ============================== aura ==============================

-- esfera de energia flutuando sobre a palma esquerda, com luz e pulso
local function buildAura(leftHand: BasePart): BasePart
	local orb = Instance.new("Part")
	orb.Name = "AnomalyAura"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.9, 0.9, 0.9)
	orb.Material = Enum.Material.Neon
	orb.Color = AURA_COLOR
	orb.Transparency = 1 -- começa guardada; só aparece quando equipada
	orb.CFrame = leftHand.CFrame * CFrame.new(0, -0.55, 0)
	weldTo(leftHand, orb)
	orb.Parent = leftHand.Parent

	local light = Instance.new("PointLight")
	light.Color = AURA_COLOR
	light.Range = 10
	light.Brightness = 2.5
	light.Enabled = false
	light.Parent = orb

	-- pulso sutil de "energia acumulando"
	task.spawn(function()
		local t = 0
		while orb.Parent do
			t += task.wait(1 / 30)
			local pulse = 0.85 + math.sin(t * 3.2) * 0.15
			orb.Size = Vector3.new(0.9, 0.9, 0.9) * pulse
		end
	end)

	return orb
end

-- ============================== estado por personagem ==============================

type Gear = {
	weapons: { [string]: Model }, -- construídas sob demanda, na primeira vez que equipa cada uma
	equipped: string?,
	aura: BasePart,
}

local gearByCharacter: { [Model]: Gear } = setmetatable({}, { __mode = "k" }) :: any

local function ensureGear(character: Model, hum: Humanoid): Gear?
	local existing = gearByCharacter[character]
	if existing then
		return existing
	end
	local rightHand, leftHand = findHands(character, hum)
	if not rightHand or not leftHand then
		return nil
	end
	local gear: Gear = {
		weapons = {},
		equipped = nil,
		aura = buildAura(leftHand),
	}
	gearByCharacter[character] = gear
	return gear
end

local function setPartsVisible(model: Model, visible: boolean)
	for _, piece in model:GetChildren() do
		(piece :: BasePart).Transparency = visible and 0 or 1
	end
end

local function setAuraVisible(gear: Gear, visible: boolean)
	gear.aura.Transparency = visible and 0 or 1
	local light = gear.aura:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = visible
	end
end

-- equipa/guarda uma arma pelo id (CombatStance.WeaponOrder). Só uma arma
-- fica visível por vez — equipar uma nova guarda a anterior sozinha.
function CombatStance.setWeaponActive(character: Model?, weaponId: string, active: boolean)
	if not character then
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local gear = ensureGear(character, hum)
	if not gear then
		return
	end
	local rightHand = findHands(character, hum)
	if not rightHand then
		return
	end

	if active then
		if gear.equipped and gear.equipped ~= weaponId then
			local previous = gear.weapons[gear.equipped]
			if previous then
				setPartsVisible(previous, false)
			end
		end
		local def = WEAPON_DEFS[weaponId]
		if not def then
			return
		end
		local model = gear.weapons[weaponId]
		if not model then
			model = def.build(rightHand)
			gear.weapons[weaponId] = model
		end
		setPartsVisible(model, true)
		gear.equipped = weaponId
	elseif gear.equipped == weaponId then
		local model = gear.weapons[weaponId]
		if model then
			setPartsVisible(model, false)
		end
		gear.equipped = nil
	end
end

-- qual arma (se alguma) está equipada nesse personagem agora
function CombatStance.getEquippedWeapon(character: Model?): string?
	if not character then
		return nil
	end
	local gear = gearByCharacter[character]
	return gear and gear.equipped
end

-- liga/desliga só a aura (reservado pro dia que ela também virar um item de
-- inventário próprio, em vez de andar sempre junto da arma).
function CombatStance.setAuraActive(character: Model?, active: boolean)
	if not character then
		return
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local gear = ensureGear(character, hum)
	if gear then
		setAuraVisible(gear, active)
	end
end

return CombatStance
