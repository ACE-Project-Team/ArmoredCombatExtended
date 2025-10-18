
local Material		= {}

Material.id			= "Cer"
Material.name		= "Ceramic"
Material.sname		= "Ceramic"
Material.desc		= "Ceramic is usually used as a material to ensure shells do not penetrate due to its high penetration resistance. Due to its frailty it is usually only used as a backing and is not meant to take the brunt of damage. Do not let it get penetrated or it will shatter."
Material.year		= 1955

Material.massMod		= 1.2
Material.curve		= 0.99

--All effectiveness values multiply the Line of Sight armor values of armor.
--All Resiliance values are damage multipliers. Higher = more damage. Lower = less damage.

Material.effectiveness  = 2.05
Material.resiliance	= 30

Material.spallresist	= 1

Material.spallmult	= 3.5
Material.ArmorMul	= 1.8
Material.NormMult	= 1.5

if SERVER then
	function Material.ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, _, damageMult, Type)

		local HitRes = {}

		local curve		= Material.curve
		local effectiveness = Material.effectiveness
		local resiliance	= Material.resiliance

		local ductilityvalue = (Entity.ACF.Ductility or 0) * 1.25 --The ductility value of the armor. Outputs 1 to -1 depending on max ductility
		local ductilitymult    = 4 / (4 + ductilityvalue * 1.5) -- Direct damage multiplier based on ductility.

		armor = armor ^ curve
		losArmor = losArmor ^ curve

		local dmul = ( losArmor / armor ) --Angled ceramic takes more damage. Fully angled ceramic takes up to 7x the damage

		local validTypes = {
			["HE"] = true,
			["HESH"] = true
		}

		if validTypes[Type] then
			dmul = dmul * 15
		end

		--Removed Breaches from Ceramic. This was hard to balance, complicated calculations, and shouldn't really happen.

		-- Penetration probability
		--The larger the number on the inside, the lower the penetration probability
		--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
		--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
		--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
		local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997;

		-- Penetration chance roll
		if penProb > math.random() then

			local Penetration = math.min( maxPenetration, losArmor * effectiveness )

			if maxPenetration > losArmor * effectiveness then
				dmul = dmul * 4 --Damage multiplier for ceramic when it gets penned. Is this enough shatter?
				Entity:EmitSound(Sound("physics/concrete/concrete_break2.wav"), 100, 100, 1, CHAN_WEAPON ) --I want to implement some sort of shatter sound. Would better be done through impact sounds.
			end

			HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * resiliance * damageMult * dmul * ductilitymult
			HitRes.Overkill = ( maxPenetration - Penetration )
			HitRes.Loss	= Penetration / maxPenetration

			return HitRes

		end

		-- Projectile did not breach nor penetrate armor
		local Penetration = math.min( maxPenetration , losArmor * effectiveness )

		HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) * FrArea * resiliance * damageMult * dmul * ductilitymult
		HitRes.Overkill = 0
		HitRes.Loss	= 1

		return HitRes

	end
end

ACE.ArmorTypes[Material.id] = Material
