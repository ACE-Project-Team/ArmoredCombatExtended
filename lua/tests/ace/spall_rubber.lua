local function makeEntity(name)
	return {
		name = name,
		ACE = { Ductility = 0 },
		GetClass = function() return "prop_physics" end,
		GetPhysicsObject = function() return nil end,
	}
end

local function withSpallTraceStubs(callback)
	local original = {
		TraceLine = util.TraceLine,
		Decal = util.Decal,
		ACFCheck = _G.ACE_Check,
		ACFCheckClips = _G.ACE_CheckClips,
		ACFDamage = _G.ACE_Damage,
		ACFAPKill = _G.ACE_APKill,
		ACFHitAngle = _G.ACE_GetHitAngle,
		GetMaterialData = ACE.GetMaterialData,
		VectorRand = _G.VectorRand,
		Line = debugoverlay.Line,
		CritEnts = ACE.CritEnts,
		SpallTrace = ACE.SpallTraces[1],
		SpallTraceMaxDepth = ACE.SpallTraceMaxDepth,
	}

	local ok, err = pcall(callback)

	util.TraceLine = original.TraceLine
	util.Decal = original.Decal
	_G.ACE_Check = original.ACFCheck
	_G.ACE_CheckClips = original.ACFCheckClips
	_G.ACE_Damage = original.ACFDamage
	_G.ACE_APKill = original.ACFAPKill
	_G.ACE_GetHitAngle = original.ACFHitAngle
	ACE.GetMaterialData = original.GetMaterialData
	_G.VectorRand = original.VectorRand
	debugoverlay.Line = original.Line
	ACE.CritEnts = original.CritEnts
	ACE.SpallTraces[1] = original.SpallTrace
	ACE.SpallTraceMaxDepth = original.SpallTraceMaxDepth

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
					local entity = { ACE = { Ductility = 0 } }
					local result = rubber.ArmorResolution(entity, 15, 15, 15 ^ 1.1 * 3.5, 100, 1, 1, 1, "Spall")
					local expectedLoss = 15 ^ 0.93 * 0.15 / 100

					expect(rubber.spallresist).to.equal(0.15)
					expect(result.Overkill).to.beGreaterThan(0)
					expect(result.Loss).to.aboutEqual(expectedLoss)
				end)
			end,
		},
		{
			name = "carries one killed fragment's remaining energy through a recursive layer",
			func = function()
				local front = makeEntity("front")
				local rear = makeEntity("rear")
				local seen = {}
				local traces = 0

				withSpallTraceStubs(function()
					ACE.CritEnts = {}
					ACE.SpallTraces[1] = {
						start = Vector(0, 0, 0),
						endpos = Vector(0, 100, 0),
						filter = {},
						mins = Vector(0, 0, 0),
						maxs = Vector(0, 0, 0),
					}

					_G.ACE_Check = function() return true end
					_G.ACE_CheckClips = function() return false end
					_G.ACE_GetHitAngle = function() return 0 end
					_G.ACE_APKill = function() return nil end
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
					_G.ACE_Damage = function(entity, energy)
						seen[#seen + 1] = { entity = entity, penetration = energy.Penetration, kinetic = energy.Kinetic }

						if entity == front then
							return { Overkill = 10, Loss = 0.25, Kill = true }
						end

						return { Overkill = 0, Loss = 1, Kill = false }
					end

					ACE.SpallTrace(Vector(1, 0, 0), 1, { Penetration = 100, Kinetic = 80 }, 1, nil, 100)
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
		{
			name = "terminates recursive spall when the same layer is visited again",
			func = function()
				local plate = makeEntity("cycle")
				local traces = 0

				withSpallTraceStubs(function()
					ACE.SpallTraces[1] = {
						start = Vector(0, 0, 0),
						endpos = Vector(0, 100, 0),
						filter = {},
						mins = Vector(0, 0, 0),
						maxs = Vector(0, 0, 0),
					}

					_G.ACE_Check = function() return true end
					_G.ACE_CheckClips = function() return false end
					_G.ACE_GetHitAngle = function() return 0 end
					_G.ACE_APKill = function() return nil end
					_G.VectorRand = function() return Vector(0, 0, 0) end
					ACE.GetMaterialData = function() return { spallresist = 1 } end
					util.Decal = function() end
					debugoverlay.Line = function() end
					util.TraceLine = function()
						traces = traces + 1

						return {
							Hit = true,
							Entity = plate,
							HitNormal = Vector(-1, 0, 0),
							StartPos = Vector(0, 0, 0),
							HitPos = Vector(10, 0, 0),
						}
					end
					_G.ACE_Damage = function()
						return { Overkill = 10, Loss = 0.25, Kill = false }
					end

					ACE.SpallTrace(Vector(1, 0, 0), 1, { Penetration = 100, Kinetic = 80 }, 1, nil, 100)
					expect(ACE.SpallTraces[1].TerminationReason).to.equal("repeated_visit")
				end)

				expect(traces).to.equal(2)
			end,
		},
		{
			name = "terminates recursive spall at the explicit depth budget",
			func = function()
				local traces = 0

				withSpallTraceStubs(function()
					ACE.SpallTraceMaxDepth = 3
					ACE.SpallTraces[1] = {
						start = Vector(0, 0, 0),
						endpos = Vector(0, 100, 0),
						filter = {},
						mins = Vector(0, 0, 0),
						maxs = Vector(0, 0, 0),
					}

					_G.ACE_Check = function() return true end
					_G.ACE_CheckClips = function() return false end
					_G.ACE_GetHitAngle = function() return 0 end
					_G.ACE_APKill = function() return nil end
					_G.VectorRand = function() return Vector(0, 0, 0) end
					ACE.GetMaterialData = function() return { spallresist = 1 } end
					util.Decal = function() end
					debugoverlay.Line = function() end
					util.TraceLine = function()
						traces = traces + 1
						local plate = makeEntity("layer-" .. traces)

						return {
							Hit = true,
							Entity = plate,
							HitNormal = Vector(-1, 0, 0),
							StartPos = Vector(traces - 1, 0, 0),
							HitPos = Vector(traces, 0, 0),
						}
					end
					_G.ACE_Damage = function()
						return { Overkill = 10, Loss = 0.01, Kill = false }
					end

					ACE.SpallTrace(Vector(1, 0, 0), 1, { Penetration = 100, Kinetic = 80 }, 1, nil, 100)
					expect(ACE.SpallTraces[1].TerminationReason).to.equal("depth_budget")
				end)

				expect(traces).to.equal(4)
			end,
		},
		{
			name = "records invalid entity termination without applying damage",
			func = function()
				local damaged = false

				withSpallTraceStubs(function()
					ACE.SpallTraces[1] = {
						start = Vector(0, 0, 0),
						endpos = Vector(0, 100, 0),
						filter = {},
						mins = Vector(0, 0, 0),
						maxs = Vector(0, 0, 0),
					}

					_G.ACE_Check = function() return false end
					util.TraceLine = function()
						return {
							Hit = true,
							Entity = makeEntity("invalid"),
							StartPos = Vector(0, 0, 0),
							HitPos = Vector(10, 0, 0),
						}
					end
					_G.ACE_Damage = function()
						damaged = true
					end
					debugoverlay.Line = function() end

					ACE.SpallTrace(Vector(1, 0, 0), 1, { Penetration = 100, Kinetic = 80 }, 1, nil, 100)
					expect(ACE.SpallTraces[1].TerminationReason).to.equal("invalid_entity")
				end)

				expect(damaged).to.equal(false)
			end,
		},
		{
			name = "selected ricochet remains terminal at the ricochet cap",
			func = function()
				local original = {
					Damage = _G.ACE_Damage,
					HitAngle = _G.ACE_GetHitAngle,
					KEShove = _G.ACE_KEShove,
					GetConVar = _G.GetConVar,
					Rand = math.Rand,
				}

				local ok, err = pcall(function()
					_G.ACE_Damage = function() return { Loss = 0.8, Overkill = 1, Kill = false } end
					_G.ACE_GetHitAngle = function() return 89 end
					_G.ACE_KEShove = function() end
					_G.GetConVar = function() return { GetFloat = function() return 1 end } end
					math.Rand = function() return 0.5 end

					local result = ACE.RoundImpact({
						Ricochets = 5,
						Caliber = 1,
						Ricochet = 55,
						Flight = Vector(1, 0, 0),
						PenArea = 1,
						Type = "APFSDS",
						ShovePower = 1,
					}, 800, { Penetration = 100, Kinetic = 80 }, { ACE = { Armour = 100 } }, nil, nil)

					expect(result.RicochetSelected).to.equal(true)
					expect(result.Ricochet).to.equal(false)
					expect(result.PostPenetration.RemainingKinetic).to.aboutEqual(16)
					expect(result.PostPenetration.SpentKinetic).to.aboutEqual(64)
				end)

				_G.ACE_Damage = original.Damage
				_G.ACE_GetHitAngle = original.HitAngle
				_G.ACE_KEShove = original.KEShove
				_G.GetConVar = original.GetConVar
				math.Rand = original.Rand

				if not ok then error(err, 0) end
			end,
		},
	},
}
