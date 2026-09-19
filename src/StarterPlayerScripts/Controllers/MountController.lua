--!strict
-- MountController.lua  (CLIENTE)
-- Faz a montaria ANDAR. O servidor monta o esqueleto (MountService) e manda a
-- velocidade; aqui é onde as pernas se mexem.
--
-- POR QUE NO CLIENTE. Animação é apresentação pura: ninguém toma dano por causa
-- da perna do cavalo. Rodando aqui, sai a 60 fps de graça, sem custar nada ao
-- servidor e sem trafegar um único byte. Cada cliente anima TODAS as montarias
-- que enxerga, e como a fase vem da velocidade real da peça, todo mundo vê o
-- mesmo galope sem precisar sincronizar nada.
--
-- Escrevemos em Motor6D.Transform, não em C0: Transform é a linha da animação
-- (não replica, não suja o modelo, e volta ao lugar sozinho se isto aqui morrer).
-- O C0 fica sendo a pose de repouso que o servidor montou.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local MountController = {}

local TAG = "Montaria"
local TAU = math.pi * 2

-- Ordem do galope transverso: mão traseira, mão dianteira, e um instante de voo.
-- Os quatro deslocamentos de fase são o que separa "galope" de "quatro pernas
-- batendo junto igual brinquedo de corda".
local GAIT: { [string]: number } = {
	LB = 0.00,
	RB = 0.12,
	LF = 0.45,
	RF = 0.57,
}

-- Sons de LOCOMOÇÃO do R15: montado, quem pisa é o cavalo, não a bota do jogador.
--
-- Só os contínuos entram aqui. Os de evento (FreeFalling, Landing, Jumping,
-- GettingUp) ficam de fora de propósito por dois motivos: o RbxCharacterSounds
-- mexe no volume deles sozinho, com fade — guardar esse valor no meio de um
-- fade e "devolver" depois congela o som em zero pra sempre, que foi exatamente
-- o que aconteceu com o FreeFalling — e além disso aterrissar um pulo montado
-- DEVE fazer barulho. O que incomodava era a bota andando, e é só isso que cala.
local PASSOS: { [string]: boolean } = {
	Running = true,
	Climbing = true,
	Splash = true,
	Swimming = true,
}

type Rig = {
	model: Model,
	root: BasePart,
	body: Motor6D,
	neck: Motor6D?,
	tail: Motor6D?,
	hip: { [string]: Motor6D },
	knee: { [string]: Motor6D },
	fase: number,
	andar: number, -- 0 parado, 1 a galope (suavizado)
	-- guardado na entrada: quando o servidor destrói a montaria o ObjectValue
	-- "Rider" morre junto com ela, e aí não dá mais pra descobrir de quem era.
	-- Sem isto, desmontar nunca devolvia o som dos passos.
	cavaleiro: Model?,
}

local rigs: { [Model]: Rig } = {}
local mutados: { [Sound]: number } = {} -- som -> volume original

-- ------------------------------------------------------------------ montagem
local function achar(model: Model): Rig?
	local root = model:FindFirstChild("Root")
	local body = model:FindFirstChild("Body")
	if not (root and root:IsA("BasePart") and body and body:IsA("BasePart")) then
		return nil
	end
	local bodyJoint = root:FindFirstChild("Body")
	if not (bodyJoint and bodyJoint:IsA("Motor6D")) then
		return nil
	end

	local hip: { [string]: Motor6D } = {}
	local knee: { [string]: Motor6D } = {}
	for perna in GAIT do
		local h = body:FindFirstChild("Hip" .. perna)
		if h and h:IsA("Motor6D") then
			hip[perna] = h
			local upper = h.Part1
			local k = upper and upper:FindFirstChild("Knee" .. perna)
			if k and k:IsA("Motor6D") then
				knee[perna] = k
			end
		end
	end

	local neck = body:FindFirstChild("Neck")
	local tail = body:FindFirstChild("Tail")
	return {
		model = model,
		root = root,
		body = bodyJoint,
		neck = (neck and neck:IsA("Motor6D")) and neck or nil,
		tail = (tail and tail:IsA("Motor6D")) and tail or nil,
		hip = hip,
		knee = knee,
		fase = math.random(),
		andar = 0,
		cavaleiro = nil,
	}
end

-- ------------------------------------------------------------------ cavaleiro
local function calarPassos(char: Model, calar: boolean)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for _, d in hrp:GetChildren() do
		if d:IsA("Sound") and PASSOS[d.Name] then
			if calar then
				if mutados[d] == nil then
					mutados[d] = d.Volume
				end
				d.Volume = 0
			elseif mutados[d] then
				d.Volume = mutados[d]
				mutados[d] = nil
			end
		end
	end
end

-- O servidor já desligou o script Animate, mas a faixa de caminhada que JÁ
-- estava tocando é em loop e continua rodando até alguém mandar parar — e só o
-- dono do personagem consegue mandar. Era isso que fazia o boneco "andar"
-- sentado em cima do cavalo parado.
local function pararFaixas(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.15)
	end
end

local function entrou(model: Model)
	if rigs[model] then
		return
	end
	task.spawn(function()
		-- o modelo pode chegar antes das peças na replicação
		local rig: Rig? = nil
		for _ = 1, 40 do
			rig = achar(model)
			if rig or model.Parent == nil then
				break
			end
			task.wait(0.05)
		end
		if not rig or model.Parent == nil then
			return
		end
		rigs[model] = rig

		local riderValue = model:FindFirstChild("Rider")
		local char = riderValue and riderValue:IsA("ObjectValue") and riderValue.Value
		if char and char:IsA("Model") then
			rig.cavaleiro = char
			calarPassos(char, true)
			if char == player.Character then
				-- duas vezes de propósito: se o Animate ainda não tinha recebido
				-- o Disabled quando paramos, ele religa a caminhada, e a segunda
				-- passada limpa. Barato, e evita o boneco andando sentado.
				pararFaixas(char)
				task.delay(0.3, function()
					if char.Parent and char:GetAttribute("Montado") then
						pararFaixas(char)
					end
				end)
			end
		end
	end)
end

local function saiu(model: Model)
	local rig = rigs[model]
	rigs[model] = nil
	-- NÃO procure o "Rider" aqui: a tag some junto com o Destroy do modelo, e a
	-- essa altura o ObjectValue já foi destruído junto. Por isso guardamos.
	local char = rig and rig.cavaleiro
	if char and char.Parent then
		calarPassos(char, false)
	end
end

-- ------------------------------------------------------------------ o galope
local function animar(rig: Rig, dt: number, t: number)
	local vel = rig.root.AssemblyLinearVelocity
	local plano = Vector3.new(vel.X, 0, vel.Z)
	local rapidez = plano.Magnitude

	-- andando de ré as pernas giram ao contrário; sem isso o cavalo "rema"
	local frente = rig.root.CFrame.LookVector
	local sentido = plano:Dot(frente) < -1 and -1 or 1

	-- alvo suavizado: a passada acelera e desacelera junto com o cavalo em vez
	-- de ligar e desligar num quadro
	local alvo = math.clamp(rapidez / 34, 0, 1)
	rig.andar += (alvo - rig.andar) * math.min(dt * 9, 1)
	local a = rig.andar

	-- ciclos por segundo: a passada tem que casar com o chão passando embaixo,
	-- senão o cavalo patina
	local ciclos = 0.55 + math.clamp(rapidez / 26, 0, 2.4)
	rig.fase = (rig.fase + dt * ciclos * sentido) % 1

	for perna, off in GAIT do
		local th = (rig.fase + off) * TAU
		local hip = rig.hip[perna]
		if hip then
			hip.Transform = CFrame.Angles(math.sin(th) * 0.60 * a, 0, 0)
		end
		local knee = rig.knee[perna]
		if knee then
			-- o joelho só DOBRA (nunca estica pro lado errado): meia onda.
			-- Dianteira dobra pra trás, traseira pra frente — é o que separa
			-- cavalo de cachorro de brinquedo.
			local dobra = math.max(0, math.sin(th + 1.15))
			local lado = (perna == "LF" or perna == "RF") and -1 or 1
			knee.Transform = CFrame.Angles(dobra * 0.85 * a * lado, 0, 0)
		end
	end

	-- tronco: sobe duas vezes por ciclo (as duas batidas do galope) e cabeceia.
	-- Parado, respira devagar — cavalo imóvel de pedra denuncia o truque.
	local sobe = math.sin(rig.fase * TAU * 2) * 0.16 * a + math.sin(t * 1.5) * 0.035 * (1 - a)
	local cabeceio = math.sin(rig.fase * TAU) * 0.055 * a
	rig.body.Transform = CFrame.new(0, sobe, 0) * CFrame.Angles(cabeceio, 0, 0)

	if rig.neck then
		-- estica o pescoço na corrida e balança contra o tronco
		rig.neck.Transform = CFrame.Angles(math.sin(rig.fase * TAU + 0.9) * 0.09 * a + 0.07 * a, 0, 0)
	end
	if rig.tail then
		-- cauda arrasta pra trás com a velocidade e vai balançando sozinha
		rig.tail.Transform = CFrame.Angles(-0.28 * a + math.sin(t * 2.6) * 0.05, math.sin(t * 1.7) * 0.12, 0)
	end

	-- Reforça o silêncio. O RbxCharacterSounds mexe no volume dos passos sozinho
	-- conforme a velocidade, então zerar uma vez na montada não basta: ele
	-- religa a bota assim que o cavalo anda. Aqui é barato (8 escritas por
	-- cavaleiro montado) e imune ao que o script padrão resolver fazer.
	local char = rig.cavaleiro
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, s in hrp:GetChildren() do
				if s:IsA("Sound") and PASSOS[s.Name] and s.Volume > 0 then
					s.Volume = 0
				end
			end
		end
	end
end

function MountController.Start()
	for _, model in CollectionService:GetTagged(TAG) do
		if model:IsA("Model") then
			entrou(model)
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			entrou(inst)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if inst:IsA("Model") then
			saiu(inst)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for model, rig in rigs do
			if model.Parent == nil or rig.root.Parent == nil then
				rigs[model] = nil
			else
				animar(rig, dt, t)
			end
		end
	end)

	print("[MountController] pronto — montarias animadas no cliente")
end

return MountController
