

ACE = ACE or {}
ACE.CMTable = ACE.CMTable or {}
ACE.ActiveMissiles = ACE.ActiveMissiles or {}
ACE.Missile_Flares = {}

ACE.Missile_FlareUID = 0




function ACE.Missile_RegisterFlare(bdata)

	local test = ACE.Missile_Flares[bdata.Index] or {}
	if table.IsEmpty( test ) then return false end

	bdata.FlareUID = ACE.Missile_FlareUID
	ACE.Missile_Flares[bdata.Index] = ACE.Missile_FlareUID

	ACE.Missile_FlareUID = ACE.Missile_FlareUID + 1


	local flareObj = ACE.Countermeasure.Flare()
	flareObj:Configure(bdata)

	bdata.FlareObj = flareObj


	ACE.Missile_OnFlareSpawn(bdata)

end




function ACE.Missile_UnregisterFlare(bdata)

	local flareObj = bdata.FlareObj

	if flareObj then
		flareObj.Flare = nil
	end

	ACE.Missile_Flares[bdata.Index] = nil

end




function ACE.Missile_OnFlareSpawn(bdata)

	local flareObj = bdata.FlareObj

	local missiles = flareObj:ApplyToAll()

	for _, missile in pairs(missiles) do
		missile.Guidance.Override = flareObj
	end

end




function ACE.Missile_GetFlaresInCone(pos, dir, degs)

	local ret = {}

	local index = 1
	for flare, _ in pairs(ACE.CMTable) do

		if not flare:IsValid() then continue end

		if ACE.Missile_ConeContainsPos(pos, dir, degs, flare:GetPos()) then
			ret[index] = flare
			index = index + 1
		end

	end

	return ret

end




function ACE.Missile_GetMissilesInCone(radar, dir, degs)

	local ret = {}
	local pos = radar:LocalToWorld(radar:OBBCenter())

	for missile in pairs(ACE.ActiveMissiles) do

		if not IsValid(missile) then continue end

		local missilePos = missile:GetPos()

		local traceData = {
			start = pos,
			endpos = missilePos,
			mask = MASK_SOLID_BRUSHONLY,
			filter = radar
		}

		local traceResult = util.TraceLine(traceData)

		--debugoverlay.Line(pos, traceResult.HitPos, 0.25, Color(255, 0, 0), true) -- radar to missile
		--debugoverlay.Box(pos, Vector(-5, -5, -5), Vector(5, 5, 5), 0.25, Color(0, 255, 0, 150)) -- radar pos

		if traceResult.Fraction == 1 and ACE.Missile_ConeContainsPos(pos, dir, degs, missilePos) then
			ret[#ret + 1] = missile
		end

	end

	return ret

end




function ACE.Missile_GetMissilesInSphere(radar, radius)

	local ret = {}
	local pos = radar:LocalToWorld(radar:OBBCenter())

	local radSqr = radius * radius

	for missile in pairs(ACE.ActiveMissiles) do

		if not IsValid(missile) then continue end

		local missilePos = missile:GetPos()

		if pos:DistToSqr(missilePos) <= radSqr then

			local traceData = {
				start = pos,
				endpos = missilePos,
				mask = MASK_SOLID_BRUSHONLY,
				filter = radar
			}

			local traceResult = util.TraceLine(traceData)

			--debugoverlay.Line(pos, traceResult.HitPos, 0.25, Color(255, 0, 0), true) -- radar to missile
			--debugoverlay.Box(pos, Vector(-5, -5, -5), Vector(5, 5, 5), 0.25, Color(0, 255, 0, 150)) -- radar pos

			if traceResult.Fraction == 1 then
				ret[#ret + 1] = missile
			end
		end
	end

	return ret

end





-- Tests flare distraction effect upon all undistracted missiles, but does not perform the effect itself.  Returns a list of potentially affected missiles.
-- argument is the bullet in the acf bullet table which represents the flare - not the cm_flare object!
function ACE.Missile_GetAllMissilesWhichCanSee(pos)

	local ret = {}

	for missile, _ in pairs(ACE.ActiveMissiles) do

		local guidance = missile.Guidance

		if not guidance or guidance.Override or not guidance.ViewCone then
			continue
		end

		if ACE.Missile_ConeContainsPos(missile:GetPos(), missile:GetForward(), guidance.ViewCone, pos) then
			ret[#ret + 1] = missile
		end

	end

	return ret

end




function ACE.Missile_ConeContainsPos(conePos, coneDir, degs, pos)

	local minDot = math.cos( math.rad(degs) )

	local testDir = pos - conePos
	testDir:Normalize()

	local dot = coneDir:Dot(testDir)

	return dot >= minDot
end




function ACE.Missile_ApplyCountermeasures(missile, guidance)

	if guidance.Override then return end

	for _, measure in pairs(ACE.Countermeasure) do

		if not measure.ApplyContinuous then
			continue
		end

		if ACE.Missile_ApplyCountermeasure(missile, guidance, measure) then
			break
		end

	end

end




function ACE.Missile_ApplySpawnCountermeasures(missile, guidance)

	if guidance.Override then return end

	for _, measure in pairs(ACE.Countermeasure) do

		if measure.ApplyContinuous then
			continue
		end

		if ACE.Missile_ApplyCountermeasure(missile, guidance, measure) then
			break
		end

	end

end




function ACE.Missile_ApplyCountermeasure(missile, guidance, measure)

	if not measure.AppliesTo[guidance.Name] then
		return false
	end

	local override = measure.ApplyAll(missile, guidance)

	if override then
		guidance.Override = override
		return true
	end

end
