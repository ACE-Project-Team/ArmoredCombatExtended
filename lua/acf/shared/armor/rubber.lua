
local Material		= {}

Material.id			= "Rub"
Material.name		= "Rubber"
Material.sname		= "Rubber"
Material.desc		= "Another material that while useless against kinetic rounds, excels at stopping shaped charges and spall"
Material.year		= 1955

Material.massMod		= 0.2
Material.curve		= 0.93

Material.specialeffect  = 20 --Caliber to divide HEAT and spall caliber by when rubber catches the shells taking more of the energy. A caliber above this number results in a damage multiplier. ex 60mm/30 -> 2x

--All effectiveness values multiply the Line of Sight armor values of armor.
--All Resiliance values are damage multipliers. Higher = more damage. Lower = less damage.

Material.effectiveness  = 0.05 --Kinetic effectiveness. What sociopath builds a tank out of rubber?
Material.resiliance	= 0.5 --Resiliance against penetrating kinetic shells
Material.Catchresiliance = 1 --Resiliance Multiplier used for kinetic shells when they fail to penetrate the armor and are "caught"


Material.HEATeffectiveness = 3
Material.HEATresiliance = 2

Material.HEresiliance	= 6

Material.spallresist = 0.75

Material.spallmult	= 0.01 --While spall can pierce rubber, Rubber itself should not really spall.
Material.ArmorMul	= 0.05
Material.NormMult	= 0.05

Material.Stopshock	= true

if SERVER then
	function Material.ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)

		local HitRes = {}

		local curve		= Material.curve
		local effectiveness = Material.effectiveness
		local resiliance	= Material.resiliance

		local ductilityvalue = (Entity.ACF.Ductility or 0) * 1.25 --The ductility value of the armor. Outputs 1 to -1 depending on max ductility
		local ductilitymult    = 2 / (2 + ductilityvalue * 1.5) -- Direct damage multiplier based on ductility.

		armor	= armor ^ curve
		losArmor	= losArmor ^ curve


		--=========================================================================================================\
		--------------------------------------------------------- For HEAT shells & Spall -------------------------->
		--=========================================================================================================/
		local validTypes = {
			["HEAT"] = true,
			["THEAT"] = true,
			["HEATFS"] = true,
			["THEATFS"] = true,
			["Spall"] = true
		}

		if validTypes[Type] then

			local specialeffectiveness  = Material.HEATeffectiveness
			local specialresiliance	= Material.HEATresiliance


			if Type == "Spall" then --Overrides effectiveness values if deflecting spall
				specialeffectiveness = Material.spallresist
				specialresiliance = Material.spallresist
			end

			local DmgResist = 0.01 + math.min(caliber * 10 / Material.specialeffect, 5) * 10 --Caliber in mm / specialeffect. Makes HEAT shells with a larger jet shred rubber more.

			local DmgResist = 1

			-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
			local breachProb = math.Clamp( (caliber / armor / specialeffectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

			-- Penetration probability
			--The larger the number on the inside, the lower the penetration probability
			--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
			--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
			--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
			local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * ( maxPenetration / losArmor / specialeffectiveness - 1 ))), 0.0015, 0.9985) - 0.0015) / 0.997;



			-- Breach chance roll
			if breachProb > math.random() and maxPenetration > armor then

				HitRes.Damage	= FrArea * specialresiliance * damageMult * ductilitymult		-- Inflicted Damage
				HitRes.Overkill = maxPenetration - armor											-- Remaining penetration
				HitRes.Loss	= armor / maxPenetration											-- Energy loss in percents

				return HitRes

			-- Penetration chance roll
			elseif penProb > math.random() then

				local Penetration = math.min( maxPenetration, losArmor * specialeffectiveness )

				HitRes.Damage = (Penetration / losArmorHealth / specialeffectiveness) ^ 2 * FrArea * specialresiliance * DmgResist * damageMult * ductilitymult
				HitRes.Overkill = (maxPenetration - Penetration)
				HitRes.Loss	= Penetration / maxPenetration

				return HitRes

			end

			-- Projectile did not breach nor penetrate armor
			local Penetration = math.min( maxPenetration , losArmor * specialeffectiveness )

			HitRes.Damage	= ( Penetration / losArmor / specialeffectiveness ) ^ 2 * FrArea * specialresiliance * DmgResist * damageMult * ductilitymult
			HitRes.Overkill = 0
			HitRes.Loss	= 1

			return HitRes
		--===============================================================================================\
		--------------------------------------------------------- For HE shells -------------------------->
		--===============================================================================================/
		elseif Type == "HE" then

			local HEresiliance = Material.HEresiliance

			-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
			local breachProb = math.Clamp( (caliber * 10 / armor / effectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.

			-- Penetration probability
			--The larger the number on the inside, the lower the penetration probability
			--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
			--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
			--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
			local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * ( maxPenetration / losArmor / effectiveness - 1 ))), 0.0015, 0.9985) - 0.0015) / 0.997;

			-- Breach chance roll
			if breachProb > math.random() and maxPenetration > armor then

				HitRes.Damage	= FrArea * HEresiliance  * damageMult * ductilitymult	-- Inflicted Damage
				HitRes.Overkill = maxPenetration - armor							-- Remaining penetration
				HitRes.Loss	= armor / maxPenetration							-- Energy loss in percents

				return HitRes

			-- Penetration chance roll
			elseif penProb > math.random() then

				local Penetration = math.min( maxPenetration, losArmor * effectiveness )

				HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * HEresiliance * damageMult * ductilitymult
				HitRes.Overkill = (maxPenetration - Penetration)
				HitRes.Loss	= Penetration / maxPenetration

				return HitRes

			end

			-- Projectile did not breach nor penetrate armor
			local Penetration = math.min( maxPenetration , losArmor * effectiveness )

			HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * HEresiliance * damageMult * ductilitymult
			HitRes.Overkill = 0
			HitRes.Loss	= 1

			return HitRes

		--===============================================================================================\
		--------------------------------------------------------- For AP shells -------------------------->
		--===============================================================================================/
		else

			-- Breach probability, chance of a shell to shoot clean through without doing much structural damage ignoring richochet and LOS armor.
			local breachProb = math.Clamp( (caliber * 10 / armor / effectiveness - 1.3) / 5.7 , 0, 1) -- If the caliber in mm is at least 1.3x the effective armor there is a chance to overmatch. At 7x the effective armor, 100% chance to overmatch.


			-- Penetration probability
			--The larger the number on the inside, the lower the penetration probability
			--Penetration/Armor ratios below 1 lead to ludicrously large numbers, making penetration nearly impossible.
			--Ratios of 1-2 lead to extremely small numbers around 1, causing penetration chances of ~40%-99%
			--Ratios larger than 2 lead to ludicrously small numbers, making penetration almost guarenteed.
			local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * ( maxPenetration / losArmor / effectiveness - 1 ))), 0.0015, 0.9985) - 0.0015) / 0.997;

			-- Breach chance roll
			if breachProb > math.random() and maxPenetration > armor then

				HitRes.Damage	= FrArea * resiliance * damageMult * ductilitymult						-- Inflicted Damage
				HitRes.Overkill = maxPenetration - armor						-- Remaining penetration
				HitRes.Loss	= armor / maxPenetration						-- Energy loss in percents

				return HitRes

			-- Penetration chance roll
			elseif penProb > math.random() then

				local Penetration = math.min( maxPenetration, losArmor * effectiveness )

				HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * resiliance * damageMult * ductilitymult
				HitRes.Overkill = (maxPenetration - Penetration)
				HitRes.Loss	= Penetration / maxPenetration

				return HitRes

			end

			-- Projectile did not breach nor penetrate armor
			local Penetration = math.min( maxPenetration , losArmor * effectiveness )

			HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * Material.Catchresiliance * damageMult * ductilitymult
			HitRes.Overkill = 0
			HitRes.Loss	= 1

			return HitRes

		end

	end
end

ACE.ArmorTypes[Material.id] = Material
