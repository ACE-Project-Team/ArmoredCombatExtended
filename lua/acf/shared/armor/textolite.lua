
local Material    = {}

Material.id       = "Texto"
Material.name     = "Textolite"
Material.sname    = "Textolite"
Material.desc     = "Fiberglass based material, this material provides decent protection agaisnt both chemical especially and kinetic rounds, while taking reduced damage from explosions."
Material.year     = 1955

Material.massMod  = 0.35
Material.curve    = 0.94

--All effectiveness values multiply the Line of Sight armor values of armor.
--All Resiliance values are damage multipliers. Higher = more damage. Lower = less damage.

Material.effectiveness        = 0.5
Material.HEATeffectiveness    = 1.2
Material.HEeffectiveness      = 0.9
Material.resiliance           = 2
Material.HEATresiliance       = 0.5
Material.HEresiliance         = 0.75

Material.spallresist          = 1

Material.spallmult            = 0.7
Material.ArmorMul             = 0.23
Material.NormMult             = 0.5

if SERVER then
	function Material.ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, _, Type)

		local HitRes = {}

		local curve		= Material.curve
		local effectiveness = Material.effectiveness
		local resiliance	= Material.resiliance

		local ductilityvalue = (Entity.ACF.Ductility or 0) * 1.25 --The ductility value of the armor. Outputs 1 to -1 depending on max ductility
		local ductilitymult    = 2 / (2 + ductilityvalue * 1.5) -- Direct damage multiplier based on ductility.
		armor	= armor ^ curve
		losArmor	= losArmor ^ curve

		local HeatTypes = { -- 
			HEAT = true,
			THEAT = true,
			HEATFS = true,
			THEATFS = true,
		}

		local OtherImpactType = { -- 
			HE = true,
			Spall = true,
			HESH = true,
		}

		if HeatTypes[Type] then

			local HEATeffectiveness = Material.HEATeffectiveness
			local HEATresiliance = Material.HEATresiliance

			-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
			local breachProb = math.Clamp( (caliber / armor / HEATeffectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

			-- Penetration probability
			--The larger the number on the inside, the lower the penetration probability
			--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
			--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
			--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
			local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / HEATeffectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997;

			if breachProb > math.random() and maxPenetration > armor * HEATeffectiveness then			-- Breach chance roll

				HitRes.Damage	= FrArea * HEATresiliance * ductilitymult						-- Inflicted Damage
				HitRes.Overkill = maxPenetration - armor * HEATeffectiveness						-- Remaining penetration
				HitRes.Loss	= armor * HEATeffectiveness / maxPenetration						-- Energy loss in percents

				return HitRes

			-- Penetration chance roll
			elseif penProb > math.random() then

				local Penetration = math.min( maxPenetration, losArmor * HEATeffectiveness )

				HitRes.Damage	= ( Penetration / losArmorHealth / HEATeffectiveness ) ^ 2 * FrArea * HEATresiliance * ductilitymult
				HitRes.Overkill = (maxPenetration - Penetration)
				HitRes.Loss	= Penetration / maxPenetration

				return HitRes

			end

			-- Projectile did not breach nor penetrate armor
			local Penetration = math.min( maxPenetration , losArmor * HEATeffectiveness )

			HitRes.Damage	= ( Penetration / losArmor / HEATeffectiveness ) ^ 2 * FrArea * HEATresiliance * ductilitymult
			HitRes.Overkill = 0
			HitRes.Loss	= 1

			return HitRes

		elseif OtherImpactType[Type] then

			local HEeffectiveness = Material.HEeffectiveness
			local HEresiliance = Material.HEresiliance

			-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
			local breachProb = math.Clamp( (caliber * 10 / armor / HEeffectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

			-- Penetration probability
			--The larger the number on the inside, the lower the penetration probability
			--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
			--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
			--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
			local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / HEeffectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997;

			-- Breach chance roll
			if breachProb > math.random() and maxPenetration > armor then

				HitRes.Damage	= FrArea * HEresiliance * ductilitymult						-- Inflicted Damage
				HitRes.Overkill = maxPenetration - armor						-- Remaining penetration
				HitRes.Loss	= armor / maxPenetration						-- Energy loss in percents

				return HitRes

			-- Penetration chance roll
			elseif penProb > math.random() then

				local Penetration = math.min( maxPenetration, losArmor * HEeffectiveness )

				HitRes.Damage	= ( Penetration / losArmorHealth / HEeffectiveness ) ^ 2 * FrArea * HEresiliance * ductilitymult
				HitRes.Overkill = (maxPenetration - Penetration)
				HitRes.Loss	= Penetration / maxPenetration

				return HitRes

			end

			-- Projectile did not breach nor penetrate armor
			local Penetration = math.min( maxPenetration , losArmor * HEeffectiveness )

			HitRes.Damage	= ( Penetration / losArmorHealth / HEeffectiveness ) ^ 2 * FrArea * HEresiliance * ductilitymult
			HitRes.Overkill = 0
			HitRes.Loss	= 1

			return HitRes

		else

			-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
			local breachProb = math.Clamp( (caliber * 10 / armor / effectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

			-- Penetration probability
			--The larger the number on the inside, the lower the penetration probability
			--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
			--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
			--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
			local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997;

			if breachProb > math.random() and maxPenetration > armor then			-- Breach chance roll

				HitRes.Damage	= FrArea * resiliance * ductilitymult							-- Inflicted Damage
				HitRes.Overkill = maxPenetration - armor						-- Remaining penetration
				HitRes.Loss	= armor / maxPenetration						-- Energy loss in percents

				return HitRes

			elseif penProb > math.random() then								-- Penetration chance roll

				local Penetration = math.min( maxPenetration, losArmor * effectiveness )
				HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness) ^ 2 * FrArea * resiliance * ductilitymult
				HitRes.Overkill = (maxPenetration - Penetration)
				HitRes.Loss	= Penetration / maxPenetration

				return HitRes

			end

			-- Projectile did not breach nor penetrate armor
			local Penetration = math.min( maxPenetration , losArmor * effectiveness )

			HitRes.Damage    = ( Penetration / losArmorHealth / effectiveness ) * FrArea * resiliance * ductilitymult
			HitRes.Overkill  = 0
			HitRes.Loss      = 1

			return HitRes

		end

	end
end

ACE.ArmorTypes[Material.id] = Material
