--!strict
-- Assets.lua  (SERVIDOR)
-- Carrega modelos externos por ID e os posiciona no mundo.
--
-- SEGURANÇA: todo modelo passa por sanitize() que APAGA qualquer
-- Script/LocalScript/ModuleScript antes de entrar no jogo. O vetor de vírus em
-- free model é justamente o script escondido; geometria e textura são inertes.
--
-- Se um ID falhar, avisa e segue — o mundo procedural continua de pé.

local InsertService = game:GetService("InsertService")

local Build = require(script.Parent.Build)

local Assets = {}

-- Catálogo. targetSize = maior dimensão desejada, em studs.
-- CATÁLOGO VAZIO, de propósito.
--
-- Os quatro IDs que estavam aqui não servem:
--   TOWER, BRIDGE, DOOR  -> "User is not authorized to access Asset". Nunca
--                           carregaram; produziam três erros a cada build e as
--                           chamadas de posicionamento não faziam nada.
--   BLACKSMITH           -> carregava, mas como UM MeshPart de 34x29x26 studs
--                           com TextureID vazio e material Plastic: um blob
--                           cinza chapado, mais alto que qualquer casa, com
--                           colisão, plantado duas vezes dentro da cidade.
--
-- O carregador continua aqui porque é útil e seguro (ele apaga qualquer script
-- do modelo antes de entrar no jogo). Basta preencher o catálogo com IDs que a
-- conta realmente possua. Até lá, a ferraria é construída pelo World/Forge.lua,
-- com o mesmo kit das casas — coerente com a cidade por construção.
Assets.catalog = {}

local cache: { [string]: Model? } = {}
local failed: { [string]: boolean } = {}

-- contadores pra reportar no HUD se os modelos externos entraram ou não
Assets.placed = 0
Assets.errors = {} :: { string }

local function sanitize(inst: Instance): number
	local removed = 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
			removed += 1
		end
	end
	return removed
end

-- carrega (uma vez) e guarda o molde; usos seguintes são clones
local function template(name: string): Model?
	if cache[name] then
		return cache[name]
	end
	if failed[name] then
		return nil
	end
	local entry = Assets.catalog[name]
	if not entry then
		return nil
	end

	-- Duas formas de carregar. LoadAsset costuma falhar no Studio quando o lugar
	-- não está publicado; GetObjects funciona no Studio. Tentamos as duas.
	local container: Instance? = nil
	local lastErr: string? = nil

	local ok, result = pcall(function()
		return InsertService:LoadAsset(entry.id)
	end)
	if ok and result then
		container = result
	else
		lastErr = tostring(result)
		local ok2, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. tostring(entry.id))
		end)
		if ok2 and objs and #objs > 0 then
			-- GetObjects devolve uma lista; embrulha num Model
			local wrap = Instance.new("Model")
			wrap.Name = name
			for _, o in objs do
				o.Parent = wrap
			end
			container = wrap
		else
			lastErr = (lastErr or "") .. " | GetObjects: " .. tostring(objs)
		end
	end

	if not container then
		failed[name] = true
		local msg = ("%s: %s"):format(name, string.sub(tostring(lastErr), 1, 90))
		table.insert(Assets.errors, msg)
		warn(("[Assets] '%s' (%d) nao carregou: %s"):format(name, entry.id, tostring(lastErr)))
		return nil
	end
	local removed = sanitize(container)
	if removed > 0 then
		warn(("[Assets] %d script(s) removido(s) de '%s' (proteção)"):format(removed, name))
	end

	local model = container :: Model
	local inner = container:GetChildren()[1]
	if inner and inner:IsA("Model") then
		model = inner
	end

	-- prepara o molde: tudo ancorado e com um PrimaryPart válido
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true
		end
	end
	if not model.PrimaryPart then
		local p = model:FindFirstChildWhichIsA("BasePart", true)
		if not p then
			failed[name] = true
			warn("[Assets] '" .. name .. "' nao tem partes")
			return nil
		end
		model.PrimaryPart = p
	end

	-- MEDIR SÓ FUNCIONA COM O MODELO DENTRO DA DATAMODEL.
	-- Medindo com Parent = nil, GetExtentsSize devolve valor não confiável e a
	-- escala era pulada em silêncio — foi o que gerou o modelo gigante.
	model.Parent = workspace

	local _, size = model:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > 0.01 then
		local scale = math.clamp(entry.targetSize / biggest, 0.0005, 8)
		local ok2, err2 = pcall(function()
			model:ScaleTo(scale)
		end)
		if not ok2 then
			warn(("[Assets] ScaleTo falhou em '%s': %s"):format(name, tostring(err2)))
		end
	else
		warn(("[Assets] '%s' mediu %s — nao deu pra escalar"):format(name, tostring(size)))
	end

	-- confere o resultado REAL depois de escalar
	local _, finalSize = model:GetBoundingBox()
	local finalBiggest = math.max(finalSize.X, finalSize.Y, finalSize.Z)
	print(
		("[Assets] %s: %.0fx%.0fx%.0f -> %.0fx%.0fx%.0f studs"):format(
			name,
			size.X,
			size.Y,
			size.Z,
			finalSize.X,
			finalSize.Y,
			finalSize.Z
		)
	)

	-- TRAVA DE SEGURANÇA: se mesmo assim ficou monstruoso, descarta.
	-- Um modelo gigante engole a cidade inteira e parece que tudo sumiu.
	if finalBiggest > entry.targetSize * 3 then
		warn(
			("[Assets] '%s' ficou grande demais (%.0f studs) — DESCARTADO pra nao engolir o mapa")
				:format(name, finalBiggest)
		)
		model:Destroy()
		failed[name] = true
		return nil
	end

	-- guarda fora do workspace: molde não pode aparecer no mundo
	model.Parent = game:GetService("ServerStorage")
	cache[name] = model
	return model
end

-- coloca uma cópia no mundo. yRot em graus; assenta a base no chão por raycast.
function Assets.spawn(name: string, pos: Vector3, yRot: number?): Model?
	local tpl = template(name)
	if not tpl then
		return nil
	end
	local clone = tpl:Clone()
	-- parentear ANTES de medir (fora da DataModel a medida não é confiável)
	clone.Parent = Build.getRoot()

	-- mede o chão para a base encostar (sem enterrar nem flutuar)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { clone }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(pos.X, 400, pos.Z), Vector3.new(0, -900, 0), params)
	local groundY = hit and hit.Position.Y or 0

	-- 1) gira e posiciona no XZ
	clone:PivotTo(CFrame.new(pos.X, 0, pos.Z) * CFrame.Angles(0, math.rad(yRot or 0), 0))
	-- 2) mede JÁ girado e sobe o tanto exato pra base encostar no chão
	local bbCF, size = clone:GetBoundingBox()
	local bottom = bbCF.Position.Y - size.Y / 2
	clone:PivotTo(clone:GetPivot() + Vector3.new(0, groundY - bottom, 0))
	Assets.placed += 1
	return clone
end

-- Coloca os modelos nos lugares certos do mapa.
-- resumo curto pro carimbo do HUD: quais entraram e quais falharam
function Assets.statusLine(): string
	local okNames, badNames = {}, {}
	for name in Assets.catalog do
		if cache[name] then
			table.insert(okNames, name)
		else
			table.insert(badNames, name)
		end
	end
	if #badNames == 0 then
		return ("assets OK (%d pecas)"):format(Assets.placed)
	end
	if #okNames == 0 then
		return ("assets 0 — NENHUM carregou | %s"):format(Assets.errors[1] or "?")
	end
	return ("assets %d ok, falhou: %s"):format(#okNames, table.concat(badNames, ","))
end

function Assets.populate(_gateZ: number, _keepZ: number)
	-- Sem catálogo não há nada a posicionar. As construções que estes IDs
	-- deveriam trazer (ferraria, torres, pontes, portões) hoje são procedurais.
end

return Assets
