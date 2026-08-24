return {
	groupName = "ACE soft-failure guard contracts",
	cases = {
		{
			name = "rejects unknown registry identifiers without throwing",
			func = function()
				expect(ACE.CheckMaterial("__missing_soft_failure_material__")).to.equal(false)
				expect(ACE.CheckRound("__missing_soft_failure_round__")).to.equal(false)
				expect(ACE.CheckGun("__missing_soft_failure_gun__")).to.equal(false)
				expect(ACE.CheckRack("__missing_soft_failure_rack__")).to.equal(false)
			end,
		},
		{
			name = "falls back safely for an unknown legacy material value",
			func = function()
				expect(ACE.GetMaterialData("__missing_soft_failure_material__")).to.equal(ACE.ArmorTypes.RHA)
				expect(ACE.GetMaterialData(999999)).to.equal(ACE.ArmorTypes.RHA)
			end,
		},
		{
			name = "handles invalid physical-parent inputs as a safe no-op",
			func = function()
				expect(ACE.GetPhysicalParent(NULL)).to.equal(nil)
			end,
		},
		{
			name = "keeps the primitive compatibility entry point total for invalid entities",
			func = function()
				expect(ACE.PrimitivePropertiesApplied).to.beA("function")
				local ok = pcall(function()
					ACE.PrimitivePropertiesApplied(NULL)
				end)
				expect(ok).to.equal(true)
			end,
		},
	},
}
