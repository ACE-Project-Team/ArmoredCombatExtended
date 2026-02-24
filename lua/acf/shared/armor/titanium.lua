
local Material		= {}

Material.id			= "Ti"
Material.name		= "Titanium"
Material.sname		= "Titanium"
Material.desc		= "Lightweight and super resiliant. But E X P E N S I V E. 60% Lighter than RHA for a given thickness. Unlike aluminum works at high thicknesses but for a price."
Material.year		= 1950 -- Dont blame about this, ik that RHA has existed before this year but it would be cool to see: when?

Material.massMod		= 0.61
Material.curve		= 1 --Slight and almost unnoticable penalty to high thickness armor

--All effectiveness values multiply the Line of Sight armor values of armor.
--All Resiliance values are damage multipliers. Higher = more damage. Lower = less damage.

Material.effectiveness  = 1.7
Material.resiliance	= 0.87

Material.spallresist	= 1

Material.spallmult	= 0.7
Material.ArmorMul	= 1
Material.NormMult	= 1

if SERVER then
	function Material.ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, _)

		local HitRes = {}

		local curve		= Material.curve
		local effectiveness = Material.effectiveness
		local resiliance	= Material.resiliance

		local ductilityvalue = (Entity.ACF.Ductility or 0) * 1.25 --The ductility value of the armor. Outputs 1 to -1 depending on max ductility
		local ductilitymult    = 2 / (2 + ductilityvalue * 1.5) -- Direct damage multiplier based on ductility.



		--(Entity.ACF.Ductility or 0)*2.5

		--2.5 = (100)/40. Multiplies the decimal ductility. Will make damage multiplier 2 or 1/2 at max ductility

		armor	= armor ^ curve
		losArmor	= losArmor ^ curve

		-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
		local breachProb = math.Clamp( (caliber / armor / effectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

		-- Penetration probability
		--The larger the number on the inside, the lower the penetration probability
		--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
		--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
		--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
		local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997;

		-- Breach chance roll
		if breachProb > math.random() and maxPenetration > armor then

			HitRes.Damage	= FrArea * resiliance * damageMult * ductilitymult		-- Inflicted Damage
			HitRes.Overkill = maxPenetration - armor					-- Remaining penetration
			HitRes.Loss	= armor / maxPenetration					-- Energy loss in percents

			return HitRes

		-- Penetration chance roll
		elseif penProb > math.random() then

			local Penetration = math.min( maxPenetration, losArmor * effectiveness)

			HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * resiliance * damageMult * ductilitymult
			HitRes.Overkill = ( maxPenetration - Penetration )
			HitRes.Loss	= Penetration / maxPenetration

			return HitRes

		end

		-- Projectile did not breach nor penetrate armor
		local Penetration = math.min( maxPenetration , losArmor * effectiveness )

		HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) * FrArea * resiliance * damageMult * ductilitymult
		HitRes.Overkill = 0
		HitRes.Loss	= 1

		return HitRes

	end
end

ACE.ArmorTypes[Material.id] = Material
