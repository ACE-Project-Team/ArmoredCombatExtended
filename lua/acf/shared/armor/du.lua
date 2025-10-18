
local Material		= {}

Material.id			= "DU"
Material.name		= "Depleted Uranium"
Material.sname		= "DU"
Material.desc		= "Heavy yet extremely effective armor. Though costly, a slab of this can stop just about anything.\n Has some nasty secondary effects when penetrated. More effective at higher thicknesses."
Material.year		= 1970 -- Dont blame about this, ik that RHA has existed before this year but it would be cool to see: when?

Material.massMod	= 2.43
Material.curve		= 1.06 --Slight and almost unnoticable penalty to high thickness armor

--All effectiveness values multiply the Line of Sight armor values of armor.
--All Resiliance values are damage multipliers. Higher = more damage. Lower = less damage.

Material.effectiveness  = 3.0
Material.resiliance	= 0.9

Material.spallresist	= 1

Material.spallmult	= 3
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

			local HEWeight  = math.Min(maxPenetration * 0.001, 30) -- #nonukespls
			local Radius	= ACE_CalculateHERadius( HEWeight )
			local Owner	= (CPPI and Entity:CPPIGetOwner()) or NULL
			local EntPos	= Entity:GetPos()

			ACF_HE( EntPos , vector_up , HEWeight , HEWeight , Owner , Entity, Entity ) --ERABOOM

			--util.Effect not working during MP workaround. Waiting a while fixes the issue.
			timer.Simple(0.001, function()
				local Flash = EffectData()
					Flash:SetOrigin( EntPos )
					Flash:SetNormal( -vector_up )
					Flash:SetRadius( math.Round(math.max(Radius / 39.37 * 0.25, 1),2) )
				util.Effect( "ace_scaled_detonation", Flash )
			end)

			HitRes.Damage	= FrArea * resiliance * damageMult * ductilitymult		-- Inflicted Damage
			HitRes.Overkill = maxPenetration - armor					-- Remaining penetration
			HitRes.Loss	= armor / maxPenetration					-- Energy loss in percents

			return HitRes

		-- Penetration chance roll
		elseif penProb > math.random() then

			local Penetration = math.min( maxPenetration, losArmor * effectiveness)

			if maxPenetration > losArmor * effectiveness then

				local HEWeight  = math.Min(maxPenetration * 0.001, 30) -- #nonukespls
				local Radius	= ACE_CalculateHERadius( HEWeight )
				local Owner	= (CPPI and Entity:CPPIGetOwner()) or NULL
				local EntPos	= Entity:GetPos()

				ACF_HE( EntPos , vector_up , HEWeight , HEWeight , Owner , Entity, Entity ) --ERABOOM

				--util.Effect not working during MP workaround. Waiting a while fixes the issue.
				timer.Simple(0.001, function()
					local Flash = EffectData()
						Flash:SetOrigin( EntPos )
						Flash:SetNormal( -vector_up )
						Flash:SetRadius( math.Round(math.max(Radius / 39.37 * 0.25, 1),2) )
					util.Effect( "ace_scaled_detonation", Flash )
				end)
			end

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
