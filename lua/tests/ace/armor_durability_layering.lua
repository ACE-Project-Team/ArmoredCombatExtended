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
			name = "later plates in a stack resist solid shot less, never more",
			func = function()
				local plate = {
					ClassName = "prop_physics",
					ACE = { Ductility = 0, Material = "RHA" },
					GetClass = function(self) return self.ClassName end,
				}
				local energy = { Kinetic = 900, Momentum = 0, Penetration = 900 }
				local frArea = 3

				local maxPen = ACE.CalcPenetration(energy, frArea)
				plate.ACE.Armour = maxPen / (ACE.KELayerArmorMul + (1 - ACE.KELayerArmorMul) / 2)

				local originalRandom = math.random
				math.random = function() return 0.5 end
				local okFresh, fresh = pcall(ACE.CalcDamage, plate, energy, frArea, 0, "AP")
				local okLater, later = pcall(ACE.CalcDamage, plate, energy, frArea, 0, "AP", ACE.KELayerArmorMul)
				math.random = originalRandom
				if not okFresh then error(fresh, 0) end
				if not okLater then error(later, 0) end

				-- The same shot bounces off this plate when it is the first one hit, and
				-- penetrates it when it is a later plate in a stack (reduced effectiveness).
				expect(fresh.Overkill).to.equal(0)
				expect(later.Overkill > 0).to.equal(true)
			end,
		},
	},
}
