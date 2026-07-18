local function makeEntity(name)
	return {
		name = name,
		ACF = { Ductility = 0 },
		GetClass = function() return "prop_physics" end,
		GetPhysicsObject = function() return nil end,
	}
end

local function withSpallTraceStubs(callback)
	local original = {
		TraceLine = util.TraceLine,
		Decal = util.Decal,
		ACFCheck = _G.ACF_Check,
		ACFCheckClips = _G.ACF_CheckClips,
		ACFDamage = _G.ACF_Damage,
		ACFHitAngle = _G.ACF_GetHitAngle,
		GetMaterialData = ACE.GetMaterialData,
		VectorRand = _G.VectorRand,
		Line = debugoverlay.Line,
		CritEnts = ACE.CritEnts,
		Spall = ACE.Spall[1],
	}

	local ok, err = pcall(callback)

	util.TraceLine = original.TraceLine
	util.Decal = original.Decal
	_G.ACF_Check = original.ACFCheck
	_G.ACF_CheckClips = original.ACFCheckClips
	_G.ACF_Damage = original.ACFDamage
	_G.ACF_GetHitAngle = original.ACFHitAngle
	ACE.GetMaterialData = original.GetMaterialData
	_G.VectorRand = original.VectorRand
	debugoverlay.Line = original.Line
	ACE.CritEnts = original.CritEnts
	ACE.Spall[1] = original.Spall

	if not ok then error(err, 0) end
end

local function withSuccessfulArmorRoll(callback)
	local originalRandom = math.random
	math.random = function() return 0 end

	local ok, err = pcall(callback)

	math.random = originalRandom

	if not ok then error(err, 0) end
end

return {
	groupName = "ACE rubber spall behavior",
	cases = {
		{
			name = "routes spall through thickness-scaled ordinary rubber resolution",
			func = function()
				withSuccessfulArmorRoll(function()
					local rubber = ACE.ArmorTypes.Rub
					local entity = { ACF = { Ductility = 0 } }
					local result = rubber.ArmorResolution(entity, 15, 15, 15 ^ 1.1 * 3.5, 100, 1, 1, 1, "Spall")
					local expectedLoss = 15 ^ 0.93 * 0.15 / 100

					expect(rubber.spallresist).to.equal(0.15)
					expect(result.Overkill).to.beGreaterThan(0)
					expect(result.Loss).to.aboutEqual(expectedLoss)
				end)
			end,
		},
		{
			name = "carries one fragment's remaining energy through a recursive layer",
			func = function()
				local front = makeEntity("front")
				local rear = makeEntity("rear")
				local seen = {}
				local traces = 0

				withSpallTraceStubs(function()
					ACE.CritEnts = {}
					ACE.Spall[1] = {
						start = Vector(0, 0, 0),
						endpos = Vector(0, 100, 0),
						filter = {},
						mins = Vector(0, 0, 0),
						maxs = Vector(0, 0, 0),
					}

					_G.ACF_Check = function() return true end
					_G.ACF_CheckClips = function() return false end
					_G.ACF_GetHitAngle = function() return 0 end
					_G.VectorRand = function() return Vector(0, 0, 0) end
					ACE.GetMaterialData = function() return { spallresist = 1 } end
					util.Decal = function() end
					debugoverlay.Line = function() end
					local traceEnds = {}
					util.TraceLine = function(trace)
						traces = traces + 1
						traceEnds[traces] = trace.endpos
						local entity = traces == 1 and front or rear

						return {
							Hit = true,
							Entity = entity,
							HitNormal = Vector(-1, 0, 0),
							StartPos = Vector((traces - 1) * 100, 0, 0),
							HitPos = Vector(0, traces * 100, 0),
						}
					end
					_G.ACF_Damage = function(entity, energy)
						seen[#seen + 1] = { entity = entity, penetration = energy.Penetration, kinetic = energy.Kinetic }

						if entity == front then
							return { Overkill = 10, Loss = 0.25, Kill = false }
						end

						return { Overkill = 0, Loss = 1, Kill = false }
					end

					ACF_SpallTrace(Vector(1, 0, 0), 1, { Penetration = 100, Kinetic = 80 }, 1, nil, 100)
					expect(traceEnds[2].x).to.equal(0)
					expect(traceEnds[2].y).to.beGreaterThan(traceEnds[2].x + 100)
				end)

				expect(traces).to.equal(2)
				expect(#seen).to.equal(2)
				expect(seen[1].penetration).to.equal(100)
				expect(seen[1].kinetic).to.equal(80)
				expect(seen[2].penetration).to.equal(75)
				expect(seen[2].kinetic).to.equal(60)
			end,
		},
	},
}
