
local Material		= {}

Material.id			= "Aramid"
Material.name		= "Aramid"
Material.sname		= "Aramid"
Material.desc		= "Woven aramid fiber (Kevlar) in resin, used for helmets, soft body armor and spall liners. The fibers catch slow pistol rounds well but fast pointed rifle rounds cut through them."
Material.year		= 1971

-- Body armor material. It stays out of the armor prop tool so vehicle balance doesn't change.
Material.hidden		= true

Material.massMod		= 0.185 -- 1.44 g/cm³ against steel's 7.85
Material.BluntTransfer = 0.4 -- Share of a stopped bullet's energy that still reaches the body behind this armor. Fabric bulges a lot.
Material.curve		= 0.95

--All effectiveness values multiply the Line of Sight armor values of armor.
--All Resiliance values are damage multipliers. Higher = more damage. Lower = less damage.

Material.effectiveness  = 0.6
Material.resiliance	= 1.5

Material.spallresist	= 1.5

Material.spallmult	= 0.5
Material.ArmorMul	= 0.2
Material.NormMult	= 0.5

if SERVER then
	function Material.ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, _, damageMult, _)

		local HitRes = {}

		local curve		= Material.curve
		local effectiveness = Material.effectiveness
		local resiliance	= Material.resiliance

		local ductilityvalue = (Entity.ACE.Ductility or 0) * 1.25
		local ductilitymult    = 2 / (2 + ductilityvalue * 1.5)

		losArmor	= losArmor ^ curve

		-- No breaches: a round bigger than the fabric is thick still has to cut the fibers.
		-- Penetration probability, same curve as RHA
		local penProb = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / losArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997;

		if penProb > math.random() then

			local Penetration = math.min( maxPenetration, losArmor * effectiveness)

			HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) ^ 2 * FrArea * resiliance * damageMult * ductilitymult
			HitRes.Overkill = ( maxPenetration - Penetration )
			HitRes.Loss	= Penetration / maxPenetration

			return HitRes

		end

		-- Projectile did not penetrate
		local Penetration = math.min( maxPenetration , losArmor * effectiveness )

		HitRes.Damage	= ( Penetration / losArmorHealth / effectiveness ) * FrArea * resiliance * damageMult * ductilitymult
		HitRes.Overkill = 0
		HitRes.Loss	= 1

		return HitRes

	end
end

ACE.ArmorTypes[Material.id] = Material
