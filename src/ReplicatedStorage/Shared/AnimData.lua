--!strict
-- AnimData.lua
-- IDs das animações do jogo. DEIXE "" pra desligar (o sistema simplesmente não toca
-- nada, sem erro). Quando você tiver uma animação, cole o id aqui e ela toca sozinha.
--
-- COMO CONSEGUIR ANIMAÇÕES (com segurança):
--   1) Fazer as suas: Studio -> Avatar -> "Animation Editor". Anima seu rig,
--      exporta/publica, e o editor te dá um id "rbxassetid://XXXXXXXX".
--   2) Grátis prontas: Creator Store -> Animations (ou "animation packs" grátis).
--      Você mesmo verifica/insere e pega o id — assim sabe o que entrou no jogo.
--   3) Pacotes de animação de avatar oficiais da Roblox também são grátis.
--
-- Formato: "rbxassetid://0000000000"

local AnimData = {
	-- combate corpo a corpo (um por passo do combo; pode repetir o mesmo id)
	swing1 = "",
	swing2 = "",
	swing3 = "",
	swing4 = "",

	heavy = "",    -- ataque pesado (F)
	ultimate = "", -- ultimate (G)
	dodge = "",    -- esquiva (Q)

	-- poderes da Core
	powerZ = "",
	powerX = "",
	powerC = "",
	powerV = "",
}

return AnimData
