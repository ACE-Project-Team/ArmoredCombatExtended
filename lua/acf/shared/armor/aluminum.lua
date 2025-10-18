
local Material		= {}

Material.id			= "Alum"
Material.name		= "Aluminum"
Material.sname		= "Aluminum"
Material.desc		= "Aluminum is normally used by AFVs or light constructions, as it provides significantly more protection for a given weight. It is more costly and prone to spalling though."
Material.year		= 1955

Material.massMod		= 0.333
Material.curve		= 0.92

Material.effectiveness  = 0.8325
Material.resiliance	= 1.1
Material.HEATMul		= 5 --Multiplies damage of HEAT against aluminum. Originally 80. Someone REALLY hated aluminum against HEAT.

Material.spallresist	= 1.0

Material.spallmult	= 1.2
Material.ArmorMul	= 0.334
Material.NormMult	= 0.7

if SERVER then
	function Material.ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)

		local HitRes = {}

		local curve		= Material.curve
		local effectiveness = Material.effectiveness
		local resiliance	= Material.resiliance

		local ductilityvalue = (Entity.ACF.Ductility or 0) * 1.25 --The ductility value of the armor. Outputs 1 to -1 depending on max ductility
		local ductilitymult    = 2 / (2 + ductilityvalue * 1.5) -- Direct damage multiplier based on ductility.

		armor = armor ^ curve
		losArmor = losArmor ^ curve

		local DamageModifier = 1


		local validTypes = {
			["HEAT"] = true,
			["THEAT"] = true,
			["HEATFS"] = true,
			["THEATFS"] = true
		}

		if validTypes[Type] then

			DamageModifier = Material.HEATMul

		end

		-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
		local breachProb = math.Clamp( (caliber / armor / effectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

		-- Penetration probability
		--The larger the number on the inside, the lower the penetration probability
		--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
		--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
		--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
		local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997

		if breachProb > math.random() and maxPenetration > armor then			-- Breach chance roll

			HitRes.Damage	= FrArea * resiliance * DamageModifier * damageMult * ductilitymult						-- Inflicted Damage
			HitRes.Overkill = maxPenetration - armor						-- Remaining penetration
			HitRes.Loss	= armor / maxPenetration						-- Energy loss in percents

			return HitRes

		-- Penetration chance roll
		elseif penProb > math.random() then

			local Penetration = math.min( maxPenetration, losArmor * effectiveness )

			HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * DamageModifier * damageMult * resiliance * ductilitymult
			HitRes.Overkill = (maxPenetration - Penetration)
			HitRes.Loss	= Penetration / maxPenetration

			return HitRes

		end

		-- Projectile did not breach nor penetrate armor
		local Penetration = math.min( maxPenetration , losArmor * effectiveness)

		HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) * FrArea * DamageModifier * damageMult * resiliance * ductilitymult
		HitRes.Overkill = 0
		HitRes.Loss	= 1

		return HitRes

	end
end

ACE.ArmorTypes[Material.id] = Material
