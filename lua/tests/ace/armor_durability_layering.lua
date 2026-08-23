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
	},
}
