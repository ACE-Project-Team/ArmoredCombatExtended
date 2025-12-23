

function ACE_DoContraptionLegalCheck(CheckEnt) --In the future could allow true/false to stop the vehicle from working.

	CheckEnt.CanLegalCheck = CheckEnt.CanLegalCheck or false
	if not CheckEnt.CanLegalCheck then return end

	CheckEnt.CanLegalCheck = false
	timer.Simple(3, function() if IsValid(CheckEnt) then CheckEnt.CanLegalCheck = true end end) --Reallows the legal check after 3 seconds to prevent spam.

	local Contraption = CheckEnt:GetContraption() or {}
	if table.IsEmpty(Contraption) then return end

	-- Recompute armor points on-demand when performing a legality check.
	if ACE_EnsureArmor then
		ACE_EnsureArmor(Contraption, CheckEnt)
	end

	ACE_CheckLegalCont(Contraption)

end

function ACE_CheckLegalCont(Contraption)

	Contraption.OTWarnings = Contraption.OTWarnings or {} --Used to remember all the one time warnings.
	--Flag test
	local HasWarned = false

	-- Make sure armor points are up to date before evaluating limits.
	if Contraption.ACEArmorDirty and Contraption.GetACEBaseplate then
		ACE_EnsureArmor(Contraption, Contraption:GetACEBaseplate())
	end

	HasWarned = Contraption.OTWarnings.WarnedOverPoints or false
	if Contraption.ACEPoints > ACF.PointsLimit and not HasWarned then
		local Ply = Contraption:GetACEBaseplate():CPPIGetOwner()
		local AboveAmt = Contraption.ACEPoints - ACF.PointsLimit
		local msg = "[ACE] " .. Ply:Nick() .. " has a vehicle [" .. math.ceil(AboveAmt) .. "pts] over the limit costing [" .. math.ceil(Contraption.ACEPoints) .. "pts / " .. math.ceil(ACF.PointsLimit) .. "pts]"

		chatMessageGlobal( msg, Color( 255, 234, 0))

		Contraption.OTWarnings.WarnedOverPoints = true
	end

	--HasWarned = Contraption.OTWarnings.WarnedOverWeight or false
	if Contraption.totalMass > ACF.MaxWeight and not HasWarned then
		local Ply = Contraption:GetACEBaseplate():CPPIGetOwner()
		local AboveAmt = Contraption.totalMass - ACF.MaxWeight

		local msg = "[ACE] " .. Ply:Nick() .. " has a vehicle [" .. math.ceil(AboveAmt) .. "kg] over the limit, weighing [" .. math.ceil(Contraption.totalMass) .. "kg / " .. math.ceil(ACF.MaxWeight) .. "kg]"
		chatMessageGlobal( msg, Color( 255, 234, 0))

		Contraption.OTWarnings.WarnedOverWeight = true
	end

	--chatMessageGlobal( message, color)


end


-- Optional hook to override per-prop point cost (e.g., trace-based armor checks).
local function ACE_ApplyArmorOverride(ent, basePoints)
	local override = hook.Run("ACE_CustomArmorPointOverride", ent, basePoints)

	if override ~= nil then return override end

	return basePoints
end

local armorDebugCvar = CreateConVar("ace_armor_debugvis", "0", FCVAR_ARCHIVE, "Draw debug overlays for armor scan results.")

-- Best-effort contraption scanner for average frontal/side armor by surface area.
-- Mirrors the E2 "FINAL Frontal Armor Surface Area Scanner" logic in a simplified per-prop form.
local function ACE_CalcContraptionArmor(ent)
	if not IsValid(ent) then return 0, 0 end

	local contraption = ent.GetContraption and ent:GetContraption() or nil
	local contraptionId = contraption and ACE_GetContraptionIndex and ACE_GetContraptionIndex(contraption) or (ent.ACF and ent.ACF.ContraptionId)
	local contraptionEnts = {}

	-- Prefer cfw contraption ents if available.
	if contraption and contraption.ents then
		for candidate in pairs(contraption.ents) do
			if IsValid(candidate) then
				contraptionEnts[#contraptionEnts + 1] = candidate
			end
		end
	elseif contraptionId then
		-- Fallback: match by contraption id we stored earlier.
		for _, candidate in ipairs(ACE.contraptionEnts or {}) do
			if not IsValid(candidate) then continue end
			local candACF = candidate.ACF
			if not candACF or candACF.ContraptionId ~= contraptionId then continue end
			contraptionEnts[#contraptionEnts + 1] = candidate
		end
	end

	-- Fallback: include the entity itself if nothing was found.
	if #contraptionEnts == 0 then
		contraptionEnts[1] = ent
		--ACE_DebugArmor("No contraption set; falling back to single-entity scan for " .. tostring(ent))
	end

	-- Pick the main gun (largest caliber).
	local mainGun
	for _, candidate in ipairs(contraptionEnts) do
		if IsValid(candidate) and candidate:GetClass() == "acf_gun" and candidate:GetModel() != "20mmsl" and candidate:GetModel() != "40mmsl" then
			if not mainGun or (candidate.Caliber or 0) > (mainGun.Caliber or 0) then
				mainGun = candidate
			end
		end
	end

	-- Direction setup.
	local frontDir
	local sideDir
	if IsValid(mainGun) then
		frontDir = -mainGun:GetForward()
		sideDir = mainGun:GetRight()
	else
		frontDir = ent:GetForward() * -1
		sideDir = ent:GetRight()
	end

	local function getBoundsWorld(prop)
		local mins, maxs = prop:OBBMins(), prop:OBBMaxs()
		local corners = {
			Vector(mins.x, mins.y, mins.z),
			Vector(mins.x, mins.y, maxs.z),
			Vector(mins.x, maxs.y, mins.z),
			Vector(mins.x, maxs.y, maxs.z),
			Vector(maxs.x, mins.y, mins.z),
			Vector(maxs.x, mins.y, maxs.z),
			Vector(maxs.x, maxs.y, mins.z),
			Vector(maxs.x, maxs.y, maxs.z)
		}

		for i, v in ipairs(corners) do
			corners[i] = prop:LocalToWorld(v)
		end

		return corners
	end

	local function findUp(prop)
		local corners = getBoundsWorld(prop)
		local best, bestZ = corners[1], corners[1].z
		for i = 2, #corners do
			if corners[i].z > bestZ then
				best = corners[i]
				bestZ = corners[i].z
			end
		end
		return prop:WorldToLocal(best)
	end

	local function findLeft(prop, sideDir, basePos)
		local corners = getBoundsWorld(prop)
		local target = basePos + sideDir * 1000
		local best, bestDist = corners[1], corners[1]:Distance(target)
		for i = 2, #corners do
			local d = corners[i]:Distance(target)
			if d < bestDist then
				best = corners[i]
				bestDist = d
			end
		end
		return prop:WorldToLocal(best)
	end

	-- Critical components (targets)
	local criticals = {}
	for _, cent in ipairs(contraptionEnts) do
		if not IsValid(cent) then continue end
		local cls = cent:GetClass()
		if cls == "acf_ammo" or cls == "acf_fueltank" or cls == "acf_engine" or cls == "ace_crewseat_gunner" or cls == "ace_crewseat_loader" or cls == "ace_crewseat_driver" then
			criticals[#criticals + 1] = cent
		end
	end

	local ignoredArmor = {
		acf_gun = true,
		acf_rack = true,
		ace_crewseat_gunner = true,
		ace_crewseat_loader = true,
		ace_crewseat_driver = true
	}

	local function projectedData(comp, dir)
		dir = dir:GetNormalized()
		local upHint = math.abs(dir.z) < 0.99 and Vector(0, 0, 1) or Vector(1, 0, 0)
		local u = dir:Cross(upHint):GetNormalized()
		local v = dir:Cross(u):GetNormalized()

		local corners = getBoundsWorld(comp)
		local minU, maxU = math.huge, -math.huge
		local minV, maxV = math.huge, -math.huge

		for _, wpos in ipairs(corners) do
			local pu = wpos:Dot(u)
			local pv = wpos:Dot(v)
			if pu < minU then minU = pu end
			if pu > maxU then maxU = pu end
			if pv < minV then minV = pv end
			if pv > maxV then maxV = pv end
		end

		local halfU = (maxU - minU) * 0.5
		local halfV = (maxV - minV) * 0.5
		local area = (maxU - minU) * (maxV - minV)

		return area, halfU, halfV, u, v
	end

	-- Move a point onto the outer face of an OBB along a given direction.
	local function pushPointToFace(comp, dir, pos)
		dir = dir:GetNormalized()
		local center = comp:WorldSpaceCenter()
		local centerDot = center:Dot(dir)

		local maxDiff = -math.huge
		local minDiff = math.huge
		for _, corner in ipairs(getBoundsWorld(comp)) do
			local diff = corner:Dot(dir) - centerDot
			if diff > maxDiff then maxDiff = diff end
			if diff < minDiff then minDiff = diff end
		end

		local targetDiff = maxDiff
		local ptDiff = pos:Dot(dir) - centerDot
		local delta = targetDiff - ptDiff

		return pos + dir * delta
	end

	local function losFiltered(startPos, endPos, targetComp)
		local filter = {}
		local total = 0
		local dir = (endPos - startPos):GetNormalized()
		local dbg = armorDebugCvar:GetBool()
		local hitTarget = false
		local hullMins = Vector(-2, -2, -2)
		local hullMaxs = Vector(2, 2, 2)

		for _ = 1, 128 do
			local tr = util.TraceHull({
				start = startPos,
				endpos = endPos,
				mins = hullMins,
				maxs = hullMaxs,
				filter = filter,
				mask = MASK_SOLID
			})

			if not tr.Hit then break end

			local hitEnt = tr.Entity
			if not IsValid(hitEnt) then break end

			local skip = false

			-- Ignore spheres made with MakeSpherical (no meaningful armor)
			if hitEnt.RenderOverride and tostring(hitEnt.RenderOverride):find("MakeSpherical") then
				skip = true
			end

			if not skip and hitEnt == targetComp then
				hitTarget = true
				break
			end

			if not skip then
				local cls = hitEnt:GetClass()
				local skipArmor = ignoredArmor[cls] or not ACF_Check(hitEnt)

				if skipArmor then
					skip = true
				elseif ACF_CheckClips(hitEnt, tr.HitPos) then
					skip = true
				end
			end

			if skip then
				filter[#filter + 1] = hitEnt
				startPos = tr.HitPos + dir * 0.1
			else
				local Mat = hitEnt.ACF.Material or "RHA"
				local MatData = ACE_GetMaterialData(Mat)
				local armor = hitEnt.ACF.Armour or 0
				local armorData = hitEnt.acfPropArmorData and hitEnt:acfPropArmorData()
				local eff = (armorData and armorData.Effectiveness) or (MatData and MatData.effectiveness) or 1
				local curve = (armorData and armorData.Curve) or 1
				local ang = ACF_GetHitAngle(tr.HitNormal, dir)
				local los

				if ang >= 89 then
					los = (armor ^ curve) * eff
				else
					local cosAng = math.max(math.cos(math.rad(ang)), 0.01)
					los = (armor / (cosAng ^ ACF.SlopeEffectFactor)) ^ curve
					los = los * eff
				end

				total = total + los

				if dbg and los > 100 then
					debugoverlay.Text(tr.HitPos, string.format("LOS %.1f", los), 30, true)
				end

				filter[#filter + 1] = hitEnt
				startPos = tr.HitPos + dir * 0.1
			end
		end

		if not hitTarget then
			return 0
		end

		return total
	end

	local countFront, countSide = 0, 0
	local accumFront, accumSide = 0, 0

	for _, comp in ipairs(criticals) do
		local center = comp:WorldSpaceCenter()
		local size = comp:OBBMaxs() - comp:OBBMins()
		local up = comp:GetUp()
		local right = comp:GetRight()

			local frontArea, frontHalfU, frontHalfV, frontU, frontV = projectedData(comp, frontDir)
			local sideArea, sideHalfU, sideHalfV, sideU, sideV = projectedData(comp, sideDir)

		local halfUp = up * (size.z * 0.5 * 0.95)
		local halfRight = right * (size.y * 0.5 * 0.95)

		local samples = {
			center + halfUp + halfRight,
			center + halfUp - halfRight,
			center - halfUp + halfRight,
			center - halfUp - halfRight,
			center -- center sample for coverage
		}
		local sampleCount = #samples
		local weightF = sampleCount > 0 and (frontArea / sampleCount) or 0
		local weightS = sampleCount > 0 and (sideArea / sampleCount) or 0

		local frontAng = frontDir:Angle()

		for _, pt in ipairs(samples) do
			local frontStart = pt - frontDir * 500
			local frontEnd   = pt 
			local sideStart  = pt - sideDir * 500
			local sideEnd    = pt 

			-- Front: take the forward trace only.
			local frontVal = losFiltered(frontStart, frontEnd, comp)

			-- Side: trace from both directions and take the lesser valid value.
			local sideValA  = losFiltered(sideStart, sideEnd, comp)
			local sideValB  = losFiltered(pt + sideDir * 500, pt - sideDir * 50, comp)
			local sideVal = math.min(sideValA > 0 and sideValA or math.huge, sideValB > 0 and sideValB or math.huge)
			if sideVal == math.huge then sideVal = 0 end
			local sideDirUsed = sideVal > 0 and ((sideValA > 0 and sideValA <= sideValB) and sideDir or -sideDir) or sideDir

			-- Area-weighted averaging; only include weights if we got a hit.
			if frontVal > 0 then
				accumFront = accumFront + frontVal * weightF
				countFront = countFront + weightF
			end

			if sideVal > 0 then
				accumSide = accumSide + sideVal * weightS
				countSide = countSide + weightS
			end

				if armorDebugCvar:GetBool() then
					local function colorFromVal(v)
						local ratio = math.min(math.max((v or 0) / 500, 0), 1)
						return 255 * ratio, 255 * (1 - ratio)
					end

						local thickness = 0.01
						local frontHalfUSample = frontHalfU * 0.5
						local frontHalfVSample = frontHalfV * 0.5
						local sideHalfUSample = sideHalfU * 0.5
						local sideHalfVSample = sideHalfV * 0.5

						if frontArea > 0 then
							local r, g = colorFromVal(frontVal)
							local frontPos = pushPointToFace(comp, -frontDir, pt)
							debugoverlay.BoxAngles(frontPos, Vector(-thickness, -frontHalfUSample, -frontHalfVSample), Vector(thickness, frontHalfUSample, frontHalfVSample), frontAng, 30, Color(r, g, 0, 0.01))
						end

						if sideArea > 0 then
							local r, g = colorFromVal(sideVal)
							local sidePos = pushPointToFace(comp, sideDirUsed, pt)
							local sideAng = sideDirUsed:Angle()
							debugoverlay.BoxAngles(sidePos, Vector(-thickness, -sideHalfUSample, -sideHalfVSample), Vector(thickness, sideHalfUSample, sideHalfVSample), sideAng, 30, Color(r, g, 0, 0.01))
						end
					end
				end
			end

	local avgFront = countFront > 0 and (accumFront / countFront) or 0
	local avgSide = countSide > 0 and (accumSide / countSide) or 0

	-- Side weighting (x2) per request.
	return avgFront, avgSide * 2
	end

function ACE_GetArmorScan(ent)
	return ACE_CalcContraptionArmor(ent)
end

-- Ensure contraption armor points are up to date and reflected in totals.
function ACE_EnsureArmor(Contraption, baseEnt)
	if not Contraption then return end
	if not Contraption.ACEArmorDirty then return end

	local base = baseEnt
	if (not IsValid(base)) and Contraption.GetACEBaseplate then
		base = Contraption:GetACEBaseplate()
	end

	local front = 0
	if IsValid(base) then
		local f, s = ACE_CalcContraptionArmor(base)
		front = f
		Contraption.ACEArmorFront = f
		Contraption.ACEArmorSide = s
	end

	local side = Contraption.ACEArmorSide or 0
	-- Final armor cost: (front + side*2) * 4
	local newArmorPts = (front + side * 2) * 4
	local oldArmor = Contraption.ACEPointsPerType and Contraption.ACEPointsPerType.Armor or 0

	Contraption.ACEPointsPerType = Contraption.ACEPointsPerType or {}
	Contraption.ACEPointsPerType.Armor = newArmorPts

	Contraption.ACEArmorPoints = newArmorPts
	Contraption.ACEArmorDirty = false

	local nonArmor = Contraption.ACEPointsNonArmor or 0
	Contraption.ACEPoints = nonArmor + newArmorPts

	if armorDebugCvar:GetBool() then
		print(string.format("[ACE ArmorDbg] Front=%.2f Side=%.2f Pts(x4)=%.2f", front or 0, side or 0, newArmorPts))
		if IsValid(base) then
			debugoverlay.Text(base:WorldSpaceCenter(), string.format("F %.2f | S %.2f | Pts(x4) %.2f", front or 0, side or 0, newArmorPts), 30, true)
		end
	end
end

function ACE_GetEntPoints(Ent, MassOverride)
	local Points = 0 --Use the specially assigned points if it has them
	--[[ Old mass/material-based point calculation retained for reference.
	if IsValid(Ent) then
		-- legacy mass/material calc here...
	end
	]]

	if not IsValid(Ent) then return 0 end

	local class = Ent:GetClass()
	if class == "prop_physics" or class == "primitive_shape" or class == "primitive_airfoil" or class == "primitive_rail_slider" or class == "primitive_slider" or class == "primitive_ladder" then
		-- Armor cost is handled at contraption-level (E2-style scan). Per-prop points are zero.
		return 0
	end

	Points = Points + (Ent.ACEPoints or 0)

	return Points
end

do
	--Used for setweight update checks. This is such a hacky way to do things.
	local PHYS    = FindMetaTable("PhysObj")
	local ACE_Override_SetMass = ACE_Override_SetMass or PHYS.SetMass
	function PHYS:SetMass(mass)

		local ent     = self:GetEntity()
		local oldPointValue = ent._AcePts or 0 -- The 'or 0' handles cases of ents connected before they had a physObj

		ent._AcePts = ACE_GetEntPoints(ent,mass)

		ACE_Override_SetMass(self,mass)

		local con = ent:GetContraption()

		if con then
			con.ACEPoints = con.ACEPoints + (ent._AcePts - oldPointValue)
		end
	end

	local FirepowerEnts = {
		["acf_rack"]                  = true,
		["acf_gun"]                   = true
	}
	local CrewEnts = {
		["ace_crewseat_gunner"]                  = true,
		["ace_crewseat_loader"]                  = true,
		["ace_crewseat_driver"]                   = true
	}
	local ElectronicEnts = {
		["ace_rwr_dir"]                  = true,
		["ace_rwr_sphere"]                  = true,
		["acf_missileradar"]                  = true,
		["acf_opticalcomputer"]                  = true,
		["ace_ecm"]                  = true,
		["ace_trackingradar"]                  = true,
		["ace_searchradar"]                  = true,
		["ace_irst"]                  = true,
		["ace_sonar"]                  = true,
		["ace_crewseat_driver"]                   = true
	}

	local function ACE_getPtsType(ClassName)
		local RetVal = "Armor"

		if ClassName == "prop_physics" then
			--Do nothing. Bypass to skip all the later checks for most common parts.
			RetVal = "Armor" --In circumstances like these, I HATE LINTER. Useless redundant callout but I have to have it to prevent the chain from being empty.
		elseif ClassName == "acf_engine" then
			RetVal = "Engines"
		elseif FirepowerEnts[ClassName] then
			RetVal = "Firepower"
		elseif ClassName == "acf_fueltank" then
			RetVal = "Fuel"
		elseif ClassName == "acf_ammo" then
			RetVal = "Ammo"
		elseif CrewEnts[ClassName] then
			RetVal = "Crew"
		elseif ElectronicEnts[ClassName] then
			RetVal = "Electronics"
		end

		return RetVal
	end

	local function ACE_InitPts(Class)
		Class.ACEPoints = 0
		Class.ACEPointsNonArmor = 0
		Class.ACEArmorPoints = 0
		Class.ACEArmorDirty = true

		Class.ACEPointsPerType = {}
		Class.ACEPointsPerType.Armor = 0
		Class.ACEPointsPerType.Engines = 0
		Class.ACEPointsPerType.Firepower = 0
		Class.ACEPointsPerType.Fuel = 0
		Class.ACEPointsPerType.Ammo = 0
		Class.ACEPointsPerType.Crew = 0
		Class.ACEPointsPerType.Electronics = 0
	end

	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)
	hook.Add("cfw.family.created", "ACE_InitPoints", ACE_InitPts)


	function ACE_AddPts(Class, Ent)
		if not IsValid(Ent) then return end

		local AcePts = ACE_GetEntPoints(Ent)

		Ent._AcePts     = AcePts

		local EClass = ACE_getPtsType(Ent:GetClass())

		if EClass == "Armor" then
			Class.ACEArmorDirty = true
		else
			Class.ACEPoints = Class.ACEPoints + AcePts
			Class.ACEPointsNonArmor = (Class.ACEPointsNonArmor or 0) + AcePts
			Class.ACEPointsPerType[EClass] = Class.ACEPointsPerType[EClass] + AcePts
		end
	end
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE_AddPts)
	hook.Add("cfw.family.added", "ACE_AddPoints", ACE_AddPts)

	function ACE_RemPts(Class, Ent)
		if not IsValid(Ent) then return end

		local EClass = ACE_getPtsType(Ent:GetClass())

		if EClass == "Armor" then
			Class.ACEArmorDirty = true
			return
		end

		local AcePts = Ent._AcePts or 0 -- avoid heavy recalcs on removal

		Class.ACEPoints = Class.ACEPoints - AcePts
		Class.ACEPointsNonArmor = (Class.ACEPointsNonArmor or 0) - AcePts

		Class.ACEPointsPerType[EClass] = Class.ACEPointsPerType[EClass] - AcePts
	end

	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE_RemPts)
	hook.Add("cfw.family.subbed", "ACE_RemPoints", ACE_RemPts)


end
