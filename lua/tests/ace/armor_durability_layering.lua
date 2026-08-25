local function legacyHealth( Area, Ductility )
	return ( Area / ACE.Threshold ) * ( 1 + Ductility )
end

return {
	groupName = "ACE armor durability contracts",
	cases = {
		{
			name = "keeps legacy health at the reference thickness",
			func = function()
				local area = 40000
				expect(ACE.CalcHealth(area, 0, ACE.HealthRefmm)).to.equal(legacyHealth(area, 0))
				expect(ACE.CalcHealth(area, 0.8, ACE.HealthRefmm)).to.equal(legacyHealth(area, 0.8))
			end,
		},
		{
			name = "scales health linearly with armor thickness",
			func = function()
				local area = 40000
				local base = ACE.CalcHealth(area, 0, ACE.HealthRefmm)
				expect(ACE.CalcHealth(area, 0, ACE.HealthRefmm * 30)).to.equal(base * 30)
				expect(ACE.CalcHealth(area, 0, ACE.HealthRefmm * 0.5)).to.equal(base * 0.5)
			end,
		},
		{
			name = "keeps health invariant when a plate is split",
			func = function()
				local whole = ACE.CalcHealth(40000, 0, 100)
				local quarters = 4 * ACE.CalcHealth(10000, 0, 100)
				expect(math.abs(whole - quarters) < 1e-9).to.equal(true)
			end,
		},
		{
			name = "destroys degenerate zero-area props instead of making them unkillable",
			func = function()
				expect(ACE.CalcHealth(0, 0, 100)).to.equal(0)
			end,
		},
		{
			name = "blocks kinetic damage below the plate energy threshold",
			func = function()
				local plate = {
					ClassName = "prop_physics",
					ACE = { Ductility = 0, Material = "RHA" },
					GetClass = function(self) return self.ClassName end,
				}
				local energy = { Kinetic = 900, Momentum = 0, Penetration = 900 }
				local frArea = 3
				local maxPen = ACE.CalcPenetration(energy, frArea)
				plate.ACE.Armour = maxPen / (ACE.KineticDamageThreshold - 0.05)

				local result = ACE.CalcDamage(plate, energy, frArea, 0, "AP")
				expect(result.KineticThresholdFailed).to.equal(true)
				expect(result.Damage).to.equal(0)
			end,
		},
		{
			name = "allows kinetic damage at the plate energy threshold",
			func = function()
				local plate = {
					ClassName = "prop_physics",
					ACE = { Ductility = 0, Material = "RHA" },
					GetClass = function(self) return self.ClassName end,
				}
				local energy = { Kinetic = 900, Momentum = 0, Penetration = 900 }
				local frArea = 3
				local maxPen = ACE.CalcPenetration(energy, frArea)
				plate.ACE.Armour = maxPen / 0.7

				local result = ACE.CalcDamage(plate, energy, frArea, 0, "AP")
				expect(result.KineticThresholdFailed).to.equal(nil)
			end,
		},
		{
			name = "does not gate zero-thickness armor",
			func = function()
				local plate = {
					ClassName = "prop_physics",
					ACE = { Armour = 0, Ductility = 0, Material = "RHA" },
					GetClass = function(self) return self.ClassName end,
				}
				local result = ACE.CalcDamage(plate, { Kinetic = 900, Momentum = 0, Penetration = 900 }, 3, 0, "AP")
				expect(result.KineticThresholdFailed).to.equal(nil)
			end,
		},
		{
			name = "does not gate non-kinetic armor damage",
			func = function()
				local plate = {
					ClassName = "prop_physics",
					ACE = { Armour = 10000, Ductility = 0, Material = "RHA" },
					GetClass = function(self) return self.ClassName end,
				}
				local result = ACE.CalcDamage(plate, { Kinetic = 1, Momentum = 0, Penetration = 1 }, 3, 0, "HE")
				expect(result.KineticThresholdFailed).to.equal(nil)
			end,
		},
	},
}
