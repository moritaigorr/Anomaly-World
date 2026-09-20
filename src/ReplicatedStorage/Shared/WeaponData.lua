--!strict
-- WeaponData.lua
-- Dados puros de cada arma equipável. Arma nova = uma tabela aqui (mesmo
-- espírito de CoreData.lua). O id de cada entrada tem que bater com
-- CombatStance.WeaponOrder, pra visual e stats andarem juntos.
--
-- `light` = golpe leve (M1, combo). `heavy` = ataque pesado (F).
-- Armas sem golpe corpo a corpo (hoje só o arco) usam `ranged = true` e não
-- têm `light`/`heavy` — o CombatService sabe que precisa pular o golpe.
--
-- Sem arma equipada, o CombatService cai no fallback de Constants.Melee/
-- Constants.Heavy ("desarmado") — não nesta tabela.

export type WeaponLight = {
	BaseDamage: number,
	Range: number,
	Arc: number,
	CooldownPerHit: number,
	ComboMult: { number },
	KnockbackFinal: number,
}

export type WeaponHeavy = {
	Damage: number,
	Cooldown: number,
	Range: number,
	Arc: number,
	PostureDamage: number,
	Knockback: number,
}

export type Weapon = {
	id: string,
	nome: string,
	ranged: boolean?,
	light: WeaponLight?,
	heavy: WeaponHeavy?,
}

local WeaponData: { [string]: Weapon } = {}

-- ESPADA: baseline do jogo — os números que Constants.Melee/Heavy tinham
-- antes de existir gear funcional. Equilibrada de propósito.
WeaponData.sword = {
	id = "sword",
	nome = "Espada Anômala",
	light = {
		BaseDamage = 10,
		Range = 9,
		Arc = 0.35,
		CooldownPerHit = 0.28,
		ComboMult = { 1.0, 1.0, 1.35, 1.6 },
		KnockbackFinal = 45,
	},
	heavy = {
		Damage = 26,
		Cooldown = 1.1,
		Range = 10,
		Arc = 0.25,
		PostureDamage = 45,
		Knockback = 60,
	},
}

-- ADAGA: rápida e curta. Dano por golpe baixo, mas bate com muito mais
-- frequência — o DPS vem da velocidade, não do golpe individual.
WeaponData.dagger = {
	id = "dagger",
	nome = "Adaga Anômala",
	light = {
		BaseDamage = 7,
		Range = 6.5,
		Arc = 0.30,
		CooldownPerHit = 0.18,
		ComboMult = { 1.0, 1.0, 1.2, 1.5 },
		KnockbackFinal = 25,
	},
	heavy = {
		Damage = 18,
		Cooldown = 0.8,
		Range = 7,
		Arc = 0.28,
		PostureDamage = 30,
		Knockback = 40,
	},
}

-- MACHADO: quebra-guarda — o maior PostureDamage do pesado do grupo corpo a
-- corpo, às custas de ser mais lento que a espada.
WeaponData.axe = {
	id = "axe",
	nome = "Machado Anômalo",
	light = {
		BaseDamage = 13,
		Range = 8.5,
		Arc = 0.32,
		CooldownPerHit = 0.34,
		ComboMult = { 1.0, 1.0, 1.4, 1.7 },
		KnockbackFinal = 50,
	},
	heavy = {
		Damage = 30,
		Cooldown = 1.15,
		Range = 9.5,
		Arc = 0.25,
		PostureDamage = 60,
		Knockback = 65,
	},
}

-- MARTELO: a mais lenta e a que mais bate — maior dano e maior knockback,
-- tanto no leve quanto no pesado.
WeaponData.hammer = {
	id = "hammer",
	nome = "Martelo Anômalo",
	light = {
		BaseDamage = 17,
		Range = 8,
		Arc = 0.30,
		CooldownPerHit = 0.46,
		ComboMult = { 1.0, 1.0, 1.45, 1.85 },
		KnockbackFinal = 70,
	},
	heavy = {
		Damage = 38,
		Cooldown = 1.4,
		Range = 9,
		Arc = 0.22,
		PostureDamage = 70,
		Knockback = 90,
	},
}

-- ARCO: só o cadastro por enquanto. Sem `light`/`heavy` de propósito — o
-- disparo de verdade (BowAttack/BowProjectile) é um item separado do
-- roadmap. `ranged = true` avisa o CombatService pra não tentar golpe corpo
-- a corpo com o arco na mão.
WeaponData.bow = {
	id = "bow",
	nome = "Arco Anômalo",
	ranged = true,
}

return WeaponData
