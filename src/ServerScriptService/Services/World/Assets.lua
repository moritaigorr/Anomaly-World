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
--
-- CATALOGO ATIVO.
-- PINE: "synty nature snow pine tree" (8933272965). Verificado ANTES de entrar:
-- 1 MeshPart, ZERO scripts, textura propria + SurfaceAppearance, 9,6 x 15,5 x
-- 9,6 studs de fabrica -- ou seja, ja na escala de uma arvore, sem precisar de
-- correcao. Substitui o pinheiro de primitivas, que por mais que eu ajustasse o
-- perfil continuava lendo como pilha de formas empilhadas.
-- BARREL: "Mesh Barrel" (9478941574). 2 MeshParts, zero scripts, 3,4 x 3,8.
-- Vem sem textura e com as cintas azuis, então é repintado na entrada pelo
-- campo `paint` -- casar o asset com a paleta da cidade é parte de adotá-lo.
--
-- KIT DE CONSTRUÇÃO, PEÇA POR PEÇA (asset 73888148623631, "Small Medieval
-- House 2"). Escolhido por ser REALISTA — pedra, telha, caixilho com almofada,
-- chaminé de tijolo — e não a estética de bloco colorido. E, principalmente,
-- por vir organizado em peças nomeadas: dá pra montar construções combinando
-- os módulos em vez de usar o modelo inteiro sempre igual.
--
-- Peças disponíveis no pacote:
--   Main House ......... corpo: paredes, telhado, mansarda, chaminé, madeirame
--   Extern Part ........ alpendre coberto com piso de tábua e esteios
--   (a fornalha do pacote nao entra: e uma UnionOperation solta que o
--    carregador nao consegue recortar de forma confiavel, e ninguem a usa)
--   Log Pile / Log Cutter / Smal Seat / Axe ... mobília de rua
--
-- O pacote é baixado UMA vez; todas as entradas abaixo saem do mesmo download.
local CASA = 73888148623631

Assets.catalog = {
	PINE = { id = 8933272965, targetSize = 16 },

	-- KIT DE MERCADO (90935751716804, "Medieval Market Pack"): tres barracas
	-- diferentes, tres caixotes e um barril, todos em mesh com textura. Tres
	-- modelos e nao um: praca com seis barracas IGUAIS denuncia geracao
	-- automatica mais que qualquer outra coisa na cidade.
	--
	-- Ja foram desativadas uma vez por "painel gigante / geometria caida". A
	-- causa nao era o asset: era posicionar pelo PIVO, que nao coincide com o
	-- volume visivel. Market.lua agora assenta pelo bounding box, igual ao que
	-- ja foi feito nas casas e na ferraria.
	BARRACA_A = { id = 90935751716804, child = "StallA", targetSize = 15 },
	BARRACA_B = { id = 90935751716804, child = "StallB", targetSize = 15 },
	BARRACA_C = { id = 90935751716804, child = "StallC", targetSize = 17 },
	CAIXOTE = { id = 90935751716804, child = "BoxA", targetSize = 4.6 },
	ENGRADADO = { id = 90935751716804, child = "BoxC", targetSize = 2.6 },

	-- MONTANHA: "Mesh Terrain Mountain Cliff Rock" (138567331315597). UM MeshPart
	-- de 168 x 40 x 176. Vem cor de arenito e sem textura, então é repintado pra
	-- rocha. A mesma malha serve de penhasco e de pedra solta: o que muda é o
	-- tamanho, e MeshPart.Size aceita escala nos três eixos (ao contrário de
	-- ScaleTo), o que permite esticar em altura sem engordar a base.
	MONTANHA = {
		id = 138567331315597,
		targetSize = 170,
		paint = { { match = "", color = Color3.fromRGB(96, 99, 106), material = Enum.Material.Rock } },
	},

	-- CASA: o pivo do modelo externo NAO fica no centro do volume visivel, e foi
	-- isso que fez as casas se cruzarem quando o lote foi calculado pelo pivo.
	-- A correcao esta em Town.kitHouse (recentra pelo bounding box) e o lote
	-- passou a 32 x 29, que e a pegada medida. Com isso o asset volta.
	CASA_CORPO = { id = CASA, child = "Main House", targetSize = 22 },
	CASA_ALPENDRE = { id = CASA, child = "Extern Part [Optional]", targetSize = 17 },
	LENHA = { id = CASA, child = "Log Pile", targetSize = 4.2 },
	CEPO = { id = CASA, child = "Log Cutter", targetSize = 2.4 },
	BANCO = { id = CASA, child = "Smal Seat", targetSize = 2.4 },

	BARREL = {
		id = 9478941574,
		targetSize = 3.8,
		paint = {
			{ match = "Bands", color = Build.C.IRON, material = Enum.Material.Metal },
			{ match = "Barrel", color = Build.C.WOOD_DARK, material = Enum.Material.Wood },
		},
	},
}

local cache: { [string]: Model? } = {}
local failed: { [string]: boolean } = {}
-- pacotes já baixados, indexados por id: vários itens do catálogo saem do mesmo
local pacotes: { [number]: Instance? } = {}

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

	-- pacote já baixado antes? reaproveita em vez de puxar de novo
	if pacotes[entry.id] then
		container = pacotes[entry.id]
	end

	local ok, result = false, nil
	if not container then
		ok, result = pcall(function()
			return InsertService:LoadAsset(entry.id)
		end)
	end
	if not container and ok and result then
		container = result
	elseif not container then
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

	-- UMA TENTATIVA SO ERA POUCO. O download depende da rede, e uma falha
	-- passageira marcava o asset como morto pela SESSAO INTEIRA -- foi assim
	-- que o alpendre das casas sumiu de um build pro outro, sem nada ter
	-- mudado no codigo. Duas tentativas extras, com uma pausa curta entre
	-- elas, resolvem o caso comum sem travar a construcao do mundo.
	if not container then
		for tentativa = 1, 2 do
			task.wait(0.4 * tentativa)
			local okR, objs = pcall(function()
				return game:GetObjects("rbxassetid://" .. tostring(entry.id))
			end)
			if okR and objs and #objs > 0 then
				local wrap = Instance.new("Model")
				wrap.Name = name
				for _, o in objs do
					o.Parent = wrap
				end
				container = wrap
				warn(("[Assets] '%s' carregou na tentativa %d"):format(name, tentativa + 1))
				break
			end
		end
	end

	if not container then
		failed[name] = true
		local msg = ("%s: %s"):format(name, string.sub(tostring(lastErr), 1, 90))
		table.insert(Assets.errors, msg)
		warn(("[Assets] '%s' (%d) nao carregou apos 3 tentativas: %s"):format(name, entry.id, tostring(lastErr)))
		return nil
	end
	local removed = sanitize(container)
	if removed > 0 then
		warn(("[Assets] %d script(s) removido(s) de '%s' (proteção)"):format(removed, name))
	end

	pacotes[entry.id] = container

	-- Recorta a peça pedida. Sem `child`, usa o primeiro Model (comportamento
	-- antigo). Com `child`, procura pelo nome — e `childIndex` desempata quando
	-- o pacote traz duas peças com o MESMO nome (é o caso de VictorianHouse,
	-- que aparece duas vezes em tamanhos diferentes).
	local model = container :: Model
	if entry.child then
		-- aceita Model E peça solta: nem toda peça do pacote vem embrulhada
		-- (a fornalha, por exemplo, é uma UnionOperation crua).
		local achados = {}
		for _, d in container:GetDescendants() do
			if d.Name == entry.child and (d:IsA("Model") or d:IsA("BasePart")) then
				table.insert(achados, d)
			end
		end
		local function volume(x: Instance): number
			if x:IsA("Model") then
				local _, sz = (x :: Model):GetBoundingBox()
				return sz.X * sz.Y * sz.Z
			end
			local sz = (x :: BasePart).Size
			return sz.X * sz.Y * sz.Z
		end
		table.sort(achados, function(a, b)
			return volume(a) > volume(b)
		end)
		local escolhido = achados[entry.childIndex or 1]
		if not escolhido then
			failed[name] = true
			warn(("[Assets] '%s': peca '%s' nao existe no pacote %d"):format(name, entry.child, entry.id))
			return nil
		end
		local copia = escolhido:Clone()
		if copia:IsA("Model") then
			model = copia
		else
			local wrap = Instance.new("Model")
			wrap.Name = name
			copia.Parent = wrap
			model = wrap
		end
	else
		local inner = container:GetChildren()[1]
		if inner and inner:IsA("Model") then
			model = inner
		end
	end

	-- Prepara o molde: tudo ancorado, e ENXUGA o custo.
	--
	-- Modelo de terceiro vem com CanCollide e CastShadow ligados em tudo,
	-- inclusive em caixilho de janela, tora de lenha e ripa de 20 centímetros.
	-- Multiplicado por 32 casas isso são milhares de cascos de colisão e de
	-- projeções de sombra que ninguém vê e que o jogador não deveria esbarrar.
	-- O corte é por tamanho: o que é estrutura continua sólido e projetando
	-- sombra, o que é enfeite passa a ser só pixel.
	local function isPassagePart(part: BasePart): boolean
		local node: Instance? = part
		while node and node ~= model do
			local label = string.lower(node.Name)
			if string.find(label, "door", 1, true)
				or string.find(label, "window", 1, true)
				or string.find(label, "glass", 1, true)
				or string.find(label, "handle", 1, true)
			then
				return true
			end
			node = node.Parent
		end
		return false
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			local maior = math.max(d.Size.X, d.Size.Y, d.Size.Z)
			-- Portas e janelas são passagem/decoração; o heurístico por tamanho
			-- antigo transformava o pacote inteiro "Doors & Windows" em parede.
			d.CanCollide = not isPassagePart(d) and maior >= 1.6
			d.CastShadow = maior >= 3.0
		end
	end

	-- REPINTURA. Asset de terceiro vem com a paleta de quem fez. Aplicar a nossa
	-- aqui, no molde, custa uma vez só e todo clone já nasce certo.
	if entry.paint then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				for _, regra in entry.paint do
					if string.find(d.Name, regra.match) then
						d.Color = regra.color
						d.Material = regra.material
						break
					end
				end
			end
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
-- Coloca uma montanha/penhasco com tamanho ABSOLUTO nos três eixos.
-- ScaleTo só escala junto; uma serra precisa ser mais alta que larga, então
-- aqui mexemos direto no Size do MeshPart, que aceita escala não uniforme.
function Assets.spawnRelief(pos: Vector3, larg: number, alt: number, prof: number, yRot: number, cor: Color3?): Model?
	local clone = Assets.spawn("MONTANHA", pos, yRot, 1, true)
	if not clone then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("MeshPart") then
			d.Size = Vector3.new(larg, alt, prof)
			if cor then
				d.Color = cor
			end
		end
	end
	-- reassenta depois de redimensionar e enterra a saia pra não sobrar aresta
	local cf, size = clone:GetBoundingBox()
	clone:PivotTo(clone:GetPivot() + Vector3.new(0, (pos.Y - size.Y * 0.14) - (cf.Position.Y - size.Y / 2), 0))
	return clone
end

-- scale multiplica o molde (variedade sem precisar de outro item no catalogo).
-- collide = false tira a colisao: numa floresta de centenas de arvores, casco de
-- colisao por arvore custa caro E prende o jogador em galho invisivel.
function Assets.spawn(name: string, pos: Vector3, yRot: number?, scale: number?, collide: boolean?): Model?
	local tpl = template(name)
	if not tpl then
		return nil
	end
	local clone = tpl:Clone()
	-- parentear ANTES de medir (fora da DataModel a medida não é confiável)
	clone.Parent = Build.getRoot()
	if scale and math.abs(scale - 1) > 0.01 then
		pcall(function()
			clone:ScaleTo(scale)
		end)
	end
	if collide == false then
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end

	-- mede o chão para a base encostar (sem enterrar nem flutuar).
	-- Só o Terrain conta: um raycast amplo podia acertar telhados, pontes ou
	-- outra decoração construída antes e assentar o asset em cima dela.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local hit = workspace:Raycast(Vector3.new(pos.X, 400, pos.Z), Vector3.new(0, -900, 0), params)
	local groundY = hit and hit.Position.Y or 0

	-- 1) gira e posiciona no XZ
	clone:PivotTo(CFrame.new(pos.X, 0, pos.Z) * CFrame.Angles(0, math.rad(yRot or 0), 0))

	-- 2) CENTRA PELO VOLUME VISÍVEL, não pelo pivô.
	-- O pivô que vem no asset raramente coincide com o meio da geometria. Ao
	-- posicionar pelo pivô, o modelo assenta deslocado do ponto pedido — e foi
	-- exatamente isso que fez as casas se cruzarem nos lotes, a ferraria
	-- afundar 12 studs e as barracas parecerem "caídas". Corrigir aqui, uma
	-- vez, vale pra todo asset do catálogo em vez de repetir a conta em cada
	-- chamador.
	local bbCF, size = clone:GetBoundingBox()
	clone:PivotTo(clone:GetPivot() + Vector3.new(pos.X - bbCF.Position.X, 0, pos.Z - bbCF.Position.Z))

	-- 3) mede DE NOVO (já girado e centrado) e sobe o tanto exato pra base
	-- encostar no chão. Modelo com submodelos recalcula a caixa depois do
	-- primeiro PivotTo, então a segunda medição não é desperdício.
	bbCF, size = clone:GetBoundingBox()
	local bottom = bbCF.Position.Y - size.Y / 2
	clone:PivotTo(clone:GetPivot() + Vector3.new(0, groundY - bottom, 0))
	local fimCF, fimSize = clone:GetBoundingBox()
	local fimBottom = fimCF.Position.Y - fimSize.Y / 2
	if math.abs(fimBottom - groundY) > 0.01 then
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, groundY - fimBottom, 0))
	end
	-- Alguns modelos de catálogo têm o pivô deslocado do centro da malha.
	-- Depois do primeiro assentamento, mede a posição real da base e repete o
	-- raycast nela; isso evita casas flutuando ou enterradas em terreno inclinado.
	local settledCF, settledSize = clone:GetBoundingBox()
	local baseHit = workspace:Raycast(
		Vector3.new(settledCF.Position.X, 400, settledCF.Position.Z),
		Vector3.new(0, -900, 0),
		params
	)
	if baseHit then
		local settledBottom = settledCF.Position.Y - settledSize.Y / 2
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, baseHit.Position.Y - settledBottom, 0))
	end
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
