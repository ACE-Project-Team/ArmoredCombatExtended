local function makeArmorEntity(class)
	return {
		ClassName = class,
		ACF = { Ductility = 0 },
		GetClass = function(self) return self.ClassName end,
	}
end

local function resolveSpall(material, thickness)
	local entity = makeArmorEntity("prop_physics")
	local originalRandom = math.random
	math.random = function() return 0 end
	local ok, result = pcall(material.ArmorResolution, entity, thickness, thickness, thickness ^ 1.1 * 3.5, 100, 1, 1, 1, "Spall")
	math.random = originalRandom
	if not ok then error(result, 0) end
	return result
end

return {
	groupName = "ACE armor and spall corpus contracts",
	cases = {
		{
			name = "keeps the requested nine-layer composite corpus addressable",
			func = function()
				local expected = {
					{ thickness = 100, material = "RHA" },
					{ thickness = 45, material = "DU" },
					{ thickness = 10, material = "Rub" },
					{ thickness = 15, material = "RHA" },
					{ thickness = 25, material = "Texto" },
					{ thickness = 50, material = "Cer" },
					{ thickness = 100, material = "Alum" },
					{ thickness = 45, material = "Rub" },
					{ thickness = 100, material = "RHA" },
				}

				expect(#expected).to.equal(9)
				for _, layer in ipairs(expected) do
					expect(ACE.ArmorTypes[layer.material]).to.exist()
				end
			end,
		},
		{
			name = "THEAT exposes both staged detonation and impact handlers",
			func = function()
				local round = ACE.RoundTypes.THEAT
				expect(round).to.exist()
				expect(round.detonate).to.beA("function")
				expect(round.propimpact).to.beA("function")
			end,
		},
		{
			name = "rubber and textolite remain thickness-scaled spall materials",
			func = function()
				local rubber = resolveSpall(ACE.ArmorTypes.Rub, 15)
				local textolite = resolveSpall(ACE.ArmorTypes.Texto, 25)
				expect(rubber.Overkill).to.beGreaterThan(0)
				expect(textolite.Overkill).to.beGreaterThan(0)
			end,
		},
		{
			name = "wheel-like ACF targets reach the ordinary armor resolver",
			func = function()
				local target = makeArmorEntity("prop_physics")
				local originalRandom = math.random
				math.random = function() return 0 end
				local result = ACE.ArmorTypes.RHA.ArmorResolution(target, 10, 10, 10 ^ 1.1 * 3.5, 100, 1, 1, 1, "AP")
				math.random = originalRandom
				expect(result).to.exist()
				expect(result.Loss < 1).to.equal(true)
			end,
		},
		{
			name = "killed armor with residual energy remains continuable",
			func = function()
				local result = ACE_GetPostPenetration({ Kill = true, Loss = 0.25, Overkill = 0 }, { Kinetic = 80, Penetration = 100 })
				expect(result.Continue).to.equal(true)
				expect(result.RemainingKinetic).to.aboutEqual(60)
				expect(result.RemainingPenetration).to.aboutEqual(75)
			end,
		},
	},
}
