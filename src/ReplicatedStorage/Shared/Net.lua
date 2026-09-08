--!strict
-- Net.lua
-- Cria (no servidor) e localiza (no cliente) todos os RemoteEvents num só lugar.
-- Assim ninguém precisa criar Remotes na mão no Studio.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTES = {
	"AttackRequest",  -- cliente -> servidor : golpe corpo a corpo (M1)
	"DashRequest",    -- cliente -> servidor : esquiva (Q)
	"BlockRequest",   -- cliente -> servidor : bloquear/parry (segurar botão direito)
	"HeavyRequest",   -- cliente -> servidor : ataque pesado (F)
	"UltimateRequest",-- cliente -> servidor : ultimate (G)
	"PowerRequest",   -- cliente -> servidor : poder da Core (Z/X/C/V)
	"SwapCoreRequest",-- cliente -> servidor : trocar de Anomaly Core (T)
	"SprintRequest",  -- cliente -> servidor : correr (segurar Shift)
	"MountRequest",   -- cliente -> servidor : montar/desmontar (H)
	"CombatFeedback", -- servidor -> cliente : impacto, números de dano, VFX
	"StateUpdate",    -- servidor -> cliente : HP, stamina, cooldowns (HUD)
}

local Net = {}
local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in REMOTES do
		if not folder:FindFirstChild(name) then
			local re = Instance.new("RemoteEvent")
			re.Name = name
			re.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
