--!strict
-- MovementService.lua  (SERVIDOR)
-- Toda a locomoção que o combate enxerga:
--   · Esquiva (Q)     — custa stamina e concede i-frames
--   · Corrida (Shift) — drena a MESMA stamina da esquiva enquanto você anda
--   · Regeneração de stamina
--
-- O bloqueio (botão direito) foi REMOVIDO do jogo. Não existe mais estado de
-- guarda, velocidade de guarda nem regeneração de posture aqui.
--
-- REGRA DESTE MÓDULO: ele é a ÚNICA autoridade que escreve Humanoid.WalkSpeed.
-- Dois escritores = a velocidade "pula" sozinha e ninguém entende por quê. Era
-- exatamente isso que o modelo de Toolbox "Sprint on shift" fazia: clonava um
-- LocalScript em cada personagem e mexia em WalkSpeed por fora, sem stamina e
-- sem validação de servidor. Se precisar de mais um estado de velocidade,
-- acrescente em applyWalkSpeed — não escreva WalkSpeed em outro lugar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local MountData = require(ReplicatedStorage.Shared.MountData)
local Net = require(ReplicatedStorage.Shared.Net)
local PlayerState = require(script.Parent.PlayerState)

local DashRequest = Net.get("DashRequest")
local SprintRequest = Net.get("SprintRequest")

local MovementService = {}

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

-- O ÚNICO ponto do jogo que escreve WalkSpeed. Prioridade: montaria > corrida > andar.
local function applyWalkSpeed(player: Player)
	local s = PlayerState.get(player)
	local hum = humanoidOf(player)
	if not (s and hum) then
		return
	end
	-- MONTADO tem prioridade: quem está no cavalo não está correndo — correr já
	-- teria desmontado.
	if s.mounted then
		local m = MountData.get(s.mounted)
		hum.WalkSpeed = m and m.speed or Constants.Move.Walk
	elseif s.sprinting then
		hum.WalkSpeed = Constants.Sprint.Speed
	else
		hum.WalkSpeed = Constants.Move.Walk
	end
end

-- não corre atordoado nem sem fôlego. O mínimo de stamina existe pra não deixar
-- a corrida engasgar (liga/desliga a cada meio segundo).
local function canStartSprint(s: PlayerState.State): boolean
	return not s.mounted -- a montaria já tem a velocidade dela
		and os.clock() >= s.stunUntil
		and s.stamina >= Constants.Sprint.MinToStart
end

-- Guardamos a INTENÇÃO (sprintHeld) separada do ESTADO (sprinting). Sem isso,
-- pedir corrida sem fôlego era recusado e nunca mais voltava: o jogador ficava
-- com Shift pressionado andando devagar, sem entender por quê. Com a intenção
-- guardada, o Heartbeat religa a corrida assim que o fôlego permite.
-- Exportado porque o MountService precisa reaplicar a velocidade ao montar e ao
-- desmontar. Ele CHAMA daqui em vez de escrever WalkSpeed por conta própria:
-- este módulo continua sendo o dono único da propriedade, que é a regra que
-- esta base já quebrou uma vez com o script de Toolbox.
MovementService.applyWalkSpeed = applyWalkSpeed

local function onSprint(player: Player, down: unknown)
	local s = PlayerState.get(player)
	if not s then
		return
	end

	s.sprintHeld = down == true
	if s.sprintHeld then
		s.sprinting = canStartSprint(s)
	else
		s.sprinting = false
	end

	applyWalkSpeed(player)
end

local function onDash(player: Player, direction: Vector3?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local s = PlayerState.get(player)
	if not (hrp and s) then
		return
	end

	local now = os.clock()
	if now < s.stunUntil then
		return -- atordoado: não pode esquivar
	end
	if now < s.dashCdUntil or s.stamina < Constants.Dash.StaminaCost then
		return
	end

	s.stamina -= Constants.Dash.StaminaCost
	s.dashCdUntil = now + Constants.Dash.Cooldown
	s.iframeUntil = now + Constants.Dash.IFrames
	-- NÃO aplicamos velocidade aqui: o personagem é controlado pelo cliente, então
	-- um impulso do servidor é sobrescrito pela física dele. O cliente dá o impulso;
	-- o servidor mantém a autoridade do que importa (stamina e i-frames).
end

function MovementService.Start()
	DashRequest.OnServerEvent:Connect(onDash)
	SprintRequest.OnServerEvent:Connect(onSprint)

	-- personagem novo nasce com o WalkSpeed padrão do Roblox; aqui garantimos que
	-- ele nasce com o NOSSO número, mesmo que alguém mude Constants.Move.Walk.
	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(applyWalkSpeed, player)
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
		applyWalkSpeed(player)
	end

	-- stamina
	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local s = PlayerState.get(player)
			if s then
				-- correr só cobra enquanto o personagem realmente se desloca: segurar
				-- Shift parado não pode consumir stamina (e não pode travar o regen).
				local hum = humanoidOf(player)
				local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0

				-- Shift ainda pressionado: a corrida volta sozinha quando o fôlego
				-- se recupera. Ninguém deveria martelar a tecla.
				if s.sprintHeld and not s.sprinting and canStartSprint(s) then
					s.sprinting = true
					applyWalkSpeed(player)
				end

				if s.sprinting and moving then
					s.stamina -= Constants.Sprint.StaminaPerSec * dt
					if s.stamina <= 0 then
						s.stamina = 0
						s.sprinting = false -- sem fôlego: a corrida cai sozinha
						applyWalkSpeed(player)
					end
				else
					s.stamina = math.min(
						Constants.Player.MaxStamina,
						s.stamina + Constants.Player.StaminaRegenPerSec * dt
					)
				end
			end
		end
	end)

	print("[MovementService] pronto — Shift corre, Q esquiva")
end

return MovementService
