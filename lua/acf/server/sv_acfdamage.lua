-- This file is meant for the advanced damage functions used by the Armored Combat Framework
ACE.Spall		= {}
ACE.CurSpallIndex = 0
ACE.SpallMax	= 250

-- optimization; reuse tables for ballistics traces
local TraceRes  = {}
local TraceInit = { output = TraceRes }

--Used for filter certain undesired ents inside of HE processing
ACF.HEFilter = {
	gmod_wire_hologram       = true,
	starfall_hologram        = true,
	prop_vehicle_crane       = true,
	prop_dynamic             = true,
	ace_debris               = true,
	sent_tanktracks_legacy   = true,
	sent_tanktracks_auto     = true,
	ace_flares               = true
}

--Used for tracebug HE workaround
ACE.CritEnts = {
	acf_gun                    = true,
	acf_ammo                   = true,
	acf_engine                 = true,
	acf_gearbox                = true,
	acf_fueltank               = true,
	acf_rack                   = true,
	ace_missile                = true,
	ace_missile_swep_guided    = true,
	prop_vehicle_prisoner_pod  = true,
	gmod_wire_gate             = true
}

--I don't want HE processing every ent that it has in range
function ACF_HEFind( Hitpos, Radius )

	local Table = {}
	for _, ent in pairs( ents.FindInSphere( Hitpos, Radius ) ) do
		--skip any undesired ent
		if ACF.HEFilter[ent:GetClass()] then continue end
		if not ent:IsSolid() then continue end
		if ent.Exploding then continue end

		table.insert( Table, ent )

	end

	return Table
end

local PI = math.pi

--[[----------------------------------------------------------------------------
    HE Physics Calculations
------------------------------------------------------------------------------]]

-- Gurney equation for initial fragment velocity
local function CalcGurneyFragVel(fillerMass, casingMass)
    local cmRatio = fillerMass / math.max(casingMass, 0.001)
    local velocity = ACF.GurneyConstant * math.sqrt(cmRatio) / math.sqrt(1 + cmRatio / 2)
    return velocity
end

-- Improved quadratic drag model for fragments
local function CalcFragVelAtDistance(v0, fragMass, distance)
    if v0 <= 0 or distance <= 0 then return v0 end

    local fragVolume = fragMass / ACF.FragDensity
    local fragDiameter = (fragVolume * 6 / math.pi) ^ (1/3)
    local fragArea = math.pi * (fragDiameter / 2) ^ 2

    local ballisticCoef = fragMass / (ACF.FragDragCoef * fragArea)
    local dragConstant = (ACF.FragAirDensity) / (2 * ballisticCoef)
    local velocityDecay = 1 / (1 + dragConstant * distance * (v0 / 1000))
    local velocity = v0 * velocityDecay

    return math.max(velocity, 0)
end

-- Fragment count based on casing mass and weapon size
local function CalcFragmentCount(fillerMass, casingMass)
    local totalMass = fillerMass + casingMass

    local avgFragMassGrams = 0.1 + totalMass * 0.3
    avgFragMassGrams = math.Clamp(avgFragMassGrams, 0.1, 5.0)

    local baseFrags = (casingMass * 1000) / avgFragMassGrams

    local maxFrags = ACF.MaxFragmentCount or 2000
    local cappedFrags = math.Clamp(math.floor(baseFrags), 2, maxFrags)

    -- Return both: capped (for per-frag mass/energy) and uncapped (for hit probability)
    return cappedFrags, math.floor(baseFrags)
end

-- Fragment area for penetration calculation
local function CalcFragmentArea(fragMass)
    local massGrams = fragMass * 1000
    local areaCm2 = 0.5 * (massGrams ^ (2/3))
    return areaCm2
end

-- Zone-based blast overpressure falloff
local function CalcBlastFeathering(distance, maxRadius)
    if distance >= maxRadius then return 0 end
    if distance <= 0 then return 1 end

    local ratio = distance / maxRadius

    if ratio < ACF.HENearFieldZone then
        return 1.0 - (ratio / ACF.HENearFieldZone) * 0.05
    elseif ratio < ACF.HEMidFieldZone then
        local midRatio = (ratio - ACF.HENearFieldZone) / (ACF.HEMidFieldZone - ACF.HENearFieldZone)
        return 0.95 - (midRatio ^ 1.5) * 0.65
    else
        local farRatio = (ratio - ACF.HEMidFieldZone) / (1 - ACF.HEMidFieldZone)
        return 0.3 * (1 - farRatio ^ 0.7)
    end
end

-- Fragment damage feathering with extended range support
local function CalcFragFeathering(distance, effectiveRadius, maxRadius, fillerMass)
    if distance <= 0 then return 1 end
    if distance >= maxRadius then return 0 end

    if distance <= effectiveRadius then
        -- Within effective range: high lethality with gradual falloff
        -- Minimum 20% damage at edge of effective range
        local ratio = distance / effectiveRadius
        local falloff = (1 - ratio ^ 1.8)  -- Slightly steeper than before
        return 0.20 + 0.80 * falloff
    else
        -- Extended range: MUCH more aggressive falloff
        -- Fragments at this range are tumbling, losing energy rapidly
        local extendedRatio = (distance - effectiveRadius) / (maxRadius - effectiveRadius)
        
        -- Smaller charges have almost no extended effectiveness
        local baseDamage = ACF.HEFragExtendedDamageMul or 0.06
        local chargeScale = math.Clamp((fillerMass or 0.5) / 1.0, 0.05, 1.0)  -- Scale to 1kg reference
        baseDamage = baseDamage * chargeScale
        
        -- Quadratic decay - starts at 20% (matching effective range edge), drops rapidly
        local decay = (1 - extendedRatio) ^ 2
        return 0.20 * decay + baseDamage * (1 - extendedRatio)
    end
end

-- Blast penetration at distance
local function CalcBlastPenAtDistance(power, distance, maxPenRadius)
    if distance >= maxPenRadius then return 0 end

    local maxPen = power / ACF.HEBlastPenetration

    if distance < maxPenRadius * 0.2 then
        return maxPen
    end

    local ratio = distance / maxPenRadius
    local falloff = 1 - (ratio ^ ACF.HEBlastPenLossExponent) * ACF.HEBlastPenLossAtMaxDist

    return maxPen * math.max(falloff, 0)
end

-- Check if detonation is near a surface
local function CheckSurfaceDetonation(hitPos, hitNormal)
    local checkDist = ACF.HESurfaceReflectDist
    
    -- Check downward (most common)
    local tr = util.TraceLine({
        start = hitPos,
        endpos = hitPos - Vector(0, 0, checkDist),
        mask = MASK_SOLID_BRUSHONLY
    })

    if tr.Hit then
        local dist = tr.HitPos:Distance(hitPos)
        if dist < checkDist then
            return true, tr.HitNormal, dist
        end
    end

    -- Check in all cardinal directions
    local directions = {
        Vector(0, 0, 1),
        Vector(1, 0, 0),
        Vector(-1, 0, 0),
        Vector(0, 1, 0),
        Vector(0, -1, 0),
    }

    for _, dir in ipairs(directions) do
        local tr2 = util.TraceLine({
            start = hitPos,
            endpos = hitPos + dir * checkDist,
            mask = MASK_SOLID_BRUSHONLY
        })

        if tr2.Hit then
            local dist = tr2.HitPos:Distance(hitPos)
            if dist < checkDist then
                return true, tr2.HitNormal, dist
            end
        end
    end

    if hitNormal and hitNormal:Length() > 0 then
        local backTrace = util.TraceLine({
            start = hitPos,
            endpos = hitPos - hitNormal * checkDist,
            mask = MASK_SOLID_BRUSHONLY
        })

        if backTrace.Hit then
            local dist = backTrace.HitPos:Distance(hitPos)
            if dist < checkDist then
                return true, backTrace.HitNormal, dist
            end
        end
    end

    return false, nil, 0
end

-- Get direction name for printing
local function GetDirectionName(vec)
    local pitch = vec:Angle().pitch
    local yaw = vec:Angle().yaw

    local vertical = ""
    if pitch < -30 then vertical = "Up-"
    elseif pitch > 30 then vertical = "Down-"
    end

    local horizontal = ""
    if yaw >= -22.5 and yaw < 22.5 then horizontal = "East"
    elseif yaw >= 22.5 and yaw < 67.5 then horizontal = "NorthEast"
    elseif yaw >= 67.5 and yaw < 112.5 then horizontal = "North"
    elseif yaw >= 112.5 and yaw < 157.5 then horizontal = "NorthWest"
    elseif yaw >= 157.5 or yaw < -157.5 then horizontal = "West"
    elseif yaw >= -157.5 and yaw < -112.5 then horizontal = "SouthWest"
    elseif yaw >= -112.5 and yaw < -67.5 then horizontal = "South"
    else horizontal = "SouthEast"
    end

    return vertical .. horizontal
end

-- Calculate the effective fragment range (where fragments retain ~25% velocity)
local function CalcFragmentEffectiveRange(fillerMass, casingMass)
    local fragVel = CalcGurneyFragVel(fillerMass, casingMass)
    local fragCount = CalcFragmentCount(fillerMass, casingMass)
    local fragMass = casingMass / math.max(fragCount, 1)

    local fragVolume = fragMass / ACF.FragDensity
    local fragDiameter = (fragVolume * 6 / math.pi) ^ (1/3)
    local fragArea = math.pi * (fragDiameter / 2) ^ 2
    local ballisticCoef = fragMass / (ACF.FragDragCoef * fragArea)
    local dragConstant = (ACF.FragAirDensity) / (2 * ballisticCoef)

    local effectiveVelRatio = ACF.HEFragEffectiveVelRatio or 0.25
    local targetVel = math.max(fragVel * effectiveVelRatio, ACF.MinLethalFragVel)

    if fragVel <= targetVel then return 0 end

    local effectiveRange = ((fragVel / targetVel) - 1) * 1000 / (dragConstant * fragVel)

    -- Convert to Source units - NO CAP HERE, cap in ACF_HE
    return effectiveRange * 39.37
end

-- Calculate the absolute maximum fragment range (where velocity = minimum lethal)
local function CalcFragmentMaxRange(fillerMass, casingMass)
    local fragVel = CalcGurneyFragVel(fillerMass, casingMass)
    local fragCount = CalcFragmentCount(fillerMass, casingMass)
    local fragMass = casingMass / math.max(fragCount, 1)

    local fragVolume = fragMass / ACF.FragDensity
    local fragDiameter = (fragVolume * 6 / math.pi) ^ (1/3)
    local fragArea = math.pi * (fragDiameter / 2) ^ 2
    local ballisticCoef = fragMass / (ACF.FragDragCoef * fragArea)
    local dragConstant = (ACF.FragAirDensity) / (2 * ballisticCoef)

    local minVel = ACF.MinLethalFragVel
    if fragVel <= minVel then return 0 end

    local maxRange = ((fragVel / minVel) - 1) * 1000 / (dragConstant * fragVel)

    -- Convert to Source units - NO CAP HERE, cap in ACF_HE
    return maxRange * 39.37
end

--[[----------------------------------------------------------------------------
    ACF_HE - Main HE Explosion Handler
------------------------------------------------------------------------------]]

function ACF_HE( Hitpos, HitNormal, FillerMass, FragMass, Inflictor, NoOcc, Gun, BlastPenMul )

    local StartTime = SysTime()

    local Stats = {
        Position = Hitpos,
        Inflictor = IsValid(Inflictor) and tostring(Inflictor) or "Unknown",
        FillerMass = FillerMass,
        FragMass = FragMass,
        TargetCount = 0,
        EntitiesHit = 0,
        EntitiesKilled = 0,
        CriticalEnts = 0,
        BlastPenHits = 0,
        Iterations = 0,
        PowerSpent = 0,
        TargetBreakdown = {},
        MissedTargets = {},
    }

    local Radius = ACE_CalculateHERadius(FillerMass)
    local Power  = FillerMass * ACF.HEPower

    -- Calculate fragment properties FIRST (needed for range scaling)
    local Fragments, FragmentsUncapped = CalcFragmentCount(FillerMass, FragMass)
    Fragments = math.max(tonumber(Fragments) or 0, 1)
    FragmentsUncapped = math.max(tonumber(FragmentsUncapped) or 0, 0)

    local FragWeight = (tonumber(FragMass) or 0) / Fragments
    local FragVel    = CalcGurneyFragVel(FillerMass, FragMass)
    local FragArea   = CalcFragmentArea(FragWeight)

    -- Physics-based fragment ranges (uncapped calculations)
    local FragEffectiveRadiusRaw = CalcFragmentEffectiveRange(FillerMass, FragMass)
    local FragMaxRadiusRaw       = CalcFragmentMaxRange(FillerMass, FragMass)

    -- Store raw values for stats
    local FragMaxRadiusRawOriginal = FragMaxRadiusRaw

    -- Performance cap
    local FragMaxCap = ACF.HEFragMaxRange or 7874  -- 200m

    -- ═══════════════════════════════════════════════════════════════════════
    -- RANGE SCALING
    -- ═══════════════════════════════════════════════════════════════════════

    local BaseEffectiveness = 0.40
    local ChargeSizeScale = math.Clamp(1.1 - FillerMass * 0.15, 0.50, 1.0)
    local VelocityBonus = math.Clamp(0.4 + FragVel / 2500, 0.5, 1.2)
    local CombinedScale = BaseEffectiveness * ChargeSizeScale * VelocityBonus

    FragEffectiveRadiusRaw = FragEffectiveRadiusRaw * CombinedScale
    FragMaxRadiusRaw = FragMaxRadiusRaw * CombinedScale

    -- ═══════════════════════════════════════════════════════════════════════
    -- MINIMUM RANGE FLOORS
    -- ═══════════════════════════════════════════════════════════════════════
    local MinEffectiveRange = Radius * 1.5
    local MinMaxRange = Radius * 2.5

    FragEffectiveRadiusRaw = math.max(FragEffectiveRadiusRaw, MinEffectiveRange)
    FragMaxRadiusRaw = math.max(FragMaxRadiusRaw, MinMaxRange)

    local ExtendedZoneMul = math.Clamp(1.4 + FillerMass * 0.2, 1.4, 1.8)

    local FragMaxRadius = math.min(FragMaxRadiusRaw, FragEffectiveRadiusRaw * ExtendedZoneMul, FragMaxCap)
    local FragEffectiveRadius = math.min(FragEffectiveRadiusRaw, FragMaxRadius)

    local FragRangeWasCapped = FragMaxRadiusRawOriginal > FragMaxCap or 
                               (FragMaxRadiusRaw > FragEffectiveRadiusRaw * ExtendedZoneMul)

    local FragRadius = FragMaxRadius

    local MaxSphere = 4 * PI * (Radius * 2.54) ^ 2
    local Amp       = math.min(Power / 2000, 50)

    Stats.BlastRadius = Radius
    Stats.FragRadius = FragMaxRadius
    Stats.FragEffectiveRadius = FragEffectiveRadius
    Stats.FragRangeWasCapped = FragRangeWasCapped
    Stats.FragMaxRadiusRaw = FragMaxRadiusRawOriginal
    Stats.Power = Power

    local IsSurfaceDet, SurfaceNormal, SurfaceDist = CheckSurfaceDetonation(Hitpos, HitNormal)
    local BaseSurfaceBoost = IsSurfaceDet and ACF.HESurfaceReflectMul or 1

    Stats.IsSurfaceDet = IsSurfaceDet
    Stats.SurfaceNormal = SurfaceNormal
    Stats.SurfaceDist = SurfaceDist

    Stats.Fragments = Fragments
    Stats.FragmentsUncapped = FragmentsUncapped
    Stats.FragWeight = FragWeight
    Stats.FragVel = FragVel
    Stats.FragArea = FragArea

    local HEBP = Power * (BlastPenMul or 1)
    local BlastPenRadius = 0
    local CanBlastPen = Power > ACF.HEBlastPenMinPow

    if CanBlastPen then
        BlastPenRadius = Radius / ACF.HEBlastPenRadiusMul
    end

    Stats.CanBlastPen = CanBlastPen
    Stats.MaxBlastPen = CanBlastPen and (HEBP / ACF.HEBlastPenetration) or 0
    Stats.BlastPenRadius = BlastPenRadius
    Stats.BlastPenMul = BlastPenMul

    local OccFilter = istable(NoOcc) and table.Copy(NoOcc) or { NoOcc }
    local LoopKill  = true

    local FRTargets = ACF_HEFind( Hitpos, FragRadius )
    Stats.TargetCount = #FRTargets

    if CanBlastPen then
        local RadSq = BlastPenRadius ^ 2
        local HEPen = HEBP / ACF.HEBlastPenetration

        local Blast = {
            Penetration = HEPen
        }

        for _, ent in pairs( ACE.critEnts ) do
            if not IsValid(ent) then continue end

            local epos = ent:GetPos()
            local SqDist = Hitpos:DistToSqr( epos )
            if SqDist > RadSq then continue end

            Stats.CriticalEnts = Stats.CriticalEnts + 1

            local Dist = math.sqrt(SqDist)
            local penAtDist = CalcBlastPenAtDistance(HEBP, Dist, BlastPenRadius)
            penAtDist = penAtDist

            local LosArmor = ACE_LOSMultiTrace(Hitpos, epos, penAtDist)

            if LosArmor < penAtDist then
                Blast.Penetration = penAtDist
                local BlastRes = ACF_Damage( ent, Blast, 1, 0, Inflictor, 0, Gun, "Frag" )

                Stats.EntitiesHit = Stats.EntitiesHit + 1
                Stats.BlastPenHits = Stats.BlastPenHits + 1

                if BlastRes and BlastRes.Kill then
                    local Debris = ACF_HEKill( ent, VectorRand(), Power * 0.0001, Hitpos )
                    table.insert( OccFilter, Debris )
                    LoopKill = true
                    Stats.EntitiesKilled = Stats.EntitiesKilled + 1
                end
            else
                table.insert(Stats.MissedTargets, {
                    Class = ent:GetClass(),
                    Distance = Dist / 39.37,
                    Reason = string.format("Armor blocked (%.0fmm > %.0fmm pen)", LosArmor, penAtDist)
                })
            end
        end
    end

    local IterationCount = 0
    local MaxIterations = 10
    local TotalPowerSpent = 0

    while LoopKill and Power > 0 and IterationCount < MaxIterations do

        LoopKill = false
        IterationCount = IterationCount + 1

        local PowerSpent = 0
        local Damage     = {}
        local TotalArea  = 0

        for i, Tar in ipairs(FRTargets) do

            if not IsValid(Tar) then continue end
            if Power <= 0 or Tar.Exploding then continue end

            local Type = ACF_Check(Tar)
            if Type then

                local TargetPos = Tar:GetPos()
                local TargetCenter = Tar:WorldSpaceCenter()

                TraceInit.start  = Hitpos
                TraceInit.endpos = TargetCenter
                TraceInit.filter = OccFilter

                util.TraceLine( TraceInit )

                if not TraceRes.Hit then
                    local Hitat = Tar:NearestPoint( Hitpos )

                    if Type == "Squishy" then
                        local hugenumber = 99999999999
                        local cldist = Hitpos:Distance( Hitat ) or hugenumber
                        local Tpos
                        local Tdis = hugenumber

                        local Eyes = Tar:LookupAttachment("eyes")
                        if Eyes then
                            local Eyeat = Tar:GetAttachment( Eyes )
                            if Eyeat then
                                Tpos = Eyeat.Pos
                                Tdis = Hitpos:Distance( Tpos ) or hugenumber
                                if Tdis < cldist then
                                    Hitat = Tpos
                                    cldist = Tdis
                                end
                            end
                        end

                        Tpos = TargetCenter
                        Tdis = Hitpos:Distance( Tpos ) or hugenumber
                        if Tdis < cldist then
                            Hitat = Tpos
                            cldist = Tdis
                        end
                    end

                    if Hitat == Hitpos then Hitat = TargetPos end

                    TraceInit.endpos = Hitat + (Hitat - Hitpos):GetNormalized() * 100
                    util.TraceHull( TraceInit )
                end

                if TraceRes.Hit and TraceRes.Entity == Tar then

                    FRTargets[i] = NULL
                    local Table  = {}

                    Table.Ent  = Tar
                    Table.Type = Type
                    Table.Class = Tar:GetClass()

                    if ACE.CritEnts[Tar:GetClass()] then
                        Table.LocalHitpos = WorldToLocal(Hitpos, Angle(0,0,0), TargetPos, Tar:GetAngles())
                        Table.IsCritical = true
                    end

                    Table.HitGroup = TraceRes.HitGroup or 0
                    Table.HitPos   = TraceRes.HitPos or TargetCenter or TargetPos
                    Table.Dist     = Hitpos:Distance(Table.HitPos)
                    Table.Vec      = (Table.HitPos - Hitpos):GetNormalized()
                    Table.Direction = Table.Vec

                    local Sphere       = math.max(4 * PI * (Table.Dist * 2.54) ^ 2, 1)
                    local AreaAdjusted = Tar.ACF.Area

                    Table.Area = math.min(AreaAdjusted / Sphere, 0.5) * MaxSphere * ACF.HEFragRadiusMul
                    table.insert(Damage, Table)

                    TotalArea = TotalArea + Table.Area

                end

            else
                FRTargets[i] = NULL
                table.insert( OccFilter, Tar )
            end

        end

        for _, Table in ipairs(Damage) do

            local Tar       = Table.Ent
            local TargetPos = Tar:GetPos()
            local DistMeters = Table.Dist / 39.37

            local BlastFeather = CalcBlastFeathering(Table.Dist, Radius)
            local FRFeathering = CalcFragFeathering(Table.Dist, FragEffectiveRadius, FragMaxRadius, FillerMass)

            -- Directional surface boost (Mach stem effect)
            local DirectionalSurfaceBoost = 1
            if IsSurfaceDet and SurfaceNormal then
                local dirToTarget = Table.Vec
                local dotToSurface = dirToTarget:Dot(SurfaceNormal)
                local surfaceAlignment = 1 - math.abs(dotToSurface)
                DirectionalSurfaceBoost = 1 + (BaseSurfaceBoost - 1) * surfaceAlignment
            end

            BlastFeather = BlastFeather * DirectionalSurfaceBoost

            local targetInfo = {
                Class = Table.Class,
                Distance = DistMeters,
                Direction = Table.Direction,
                BlastFeather = BlastFeather,
                FragFeather = FRFeathering,
                SurfaceBoost = DirectionalSurfaceBoost,
                Hit = false,
                Killed = false,
            }

            local AreaFraction   = Table.Area / TotalArea
            local PowerFraction  = Power * AreaFraction
            local AreaAdjusted   = (Tar.ACF.Area / ACF.Threshold) * BlastFeather * ACF.HEBlastDamageMul
            local FRAreaAdjusted = (Tar.ACF.Area / ACF.Threshold) * FRFeathering * ACF.HEFragDamageMul

            if FRAreaAdjusted <= 0 then
                table.insert(Stats.TargetBreakdown, targetInfo)
                continue
            end

            local Blast = {
                Penetration = PowerFraction ^ ACF.HEBlastPen * AreaAdjusted
            }

            local BlastRes
            local FragRes

            -- Fragment velocity at distance
            local FragVelAtDist = CalcFragVelAtDistance(FragVel, FragWeight, DistMeters)

            -- =========================
            -- REALISTIC FRAGMENT DISTRIBUTION
            -- =========================
            local FragHit = 0
            if DistMeters > 0.1 then
                local fragEffectiveAreaMul = 3
                local targetAreaM2 = (Tar.ACF.Area / 10000) * fragEffectiveAreaMul
                local sphereAreaM2 = 4 * PI * DistMeters ^ 2
                local solidAngleFraction = math.min(targetAreaM2 / sphereAreaM2, 0.5)

                FragHit = FragmentsUncapped * solidAngleFraction
                FragHit = math.min(FragHit, ACF.MaxFragmentsPerEnt)
            else
                FragHit = math.min(Fragments * 0.15, ACF.MaxFragmentsPerEnt)
            end

            -- Probabilistic hit for fractional expected values
            if FragHit > 0 and FragHit < 1 then
                if math.random() < FragHit then
                    FragHit = 1
                else
                    FragHit = 0
                end
            elseif FragHit >= 1 then
                local variance = 0.25
                local varianceMul = 1 + math.Rand(-variance, variance)
                FragHit = math.max(math.floor(FragHit * varianceMul + 0.5), 1)

                if math.random() < 0.05 then
                    FragHit = math.max(math.floor(FragHit * math.Rand(0.5, 1.5) + 0.5), 1)
                end
            end

            -- Only calculate frag KE if we actually have fragments hitting
			-- Only calculate frag KE if we actually have fragments hitting
			local FragKE = nil
			local FragDamageArea = nil

			if FragHit >= 1 and FragVelAtDist > ACF.MinLethalFragVel then
				-- Calculate KE for a SINGLE fragment first
				local SingleFragKE = ACF_Kinetic(FragVelAtDist * 39.37, FragWeight, 1500)
				
				if Table.Type == "Squishy" then
					-- Squishy targets: pass single fragment energy, damage function handles FragHit
					FragKE = SingleFragKE
					FragKE.FragHit = FragHit
					FragDamageArea = FragArea
				else
					-- Non-squishy targets: multiply the RESULTS by fragment count, not the mass input
					-- This correctly models multiple small fragments vs one large fragment
					FragKE = {
						Penetration = SingleFragKE.Penetration * FragHit,
						Kinetic = SingleFragKE.Kinetic * FragHit,
						Momentum = SingleFragKE.Momentum * FragHit
					}
					FragDamageArea = FragArea * FragHit
				end
			end

            -- =========================
            -- FRAGMENT OCCLUSION CHECK
            -- =========================
            local FragsBlocked = false
            local FragPenRemaining = 0
            local NearFieldDist = Radius * 0.15

            if FragKE and FragVelAtDist > ACF.MinLethalFragVel and FragHit >= 1 then
                local shouldTrace = Table.Dist > NearFieldDist and FragHit >= 0.5

                if shouldTrace then
                    local targetPoint = Table.HitPos or TargetPos
                    local startPoint  = Hitpos + (targetPoint - Hitpos):GetNormalized() * 1

                    local FragTrace = util.TraceLine({
                        start  = startPoint,
                        endpos = targetPoint,
                        filter = OccFilter,
                        mask   = MASK_SHOT
                    })

                    if FragTrace.Hit and FragTrace.Entity ~= Tar then
                        local BlockingEnt = FragTrace.Entity

                        if FragTrace.HitWorld then
                            FragsBlocked = true

                        elseif IsValid(BlockingEnt) and ACF_Check(BlockingEnt) then
                            local BlockerArmor = BlockingEnt.ACF.Armour or 0
                            local FragPen = (FragKE.Penetration / math.max(FragArea * FragHit, 0.01)) * ACF.KEtoRHA

                            if FragPen > BlockerArmor then
                                local PenRatio = math.max(1 - (BlockerArmor / FragPen), 0.1)
                                FragPenRemaining = PenRatio

                                FragKE.Penetration = FragKE.Penetration * PenRatio
                                FragKE.Kinetic = FragKE.Kinetic * PenRatio
                            else
                                FragsBlocked = true
                            end

                        elseif IsValid(BlockingEnt) then
                            FragsBlocked = true
                        end
                    end
                end
            end

            -- =========================
            -- APPLY DAMAGE
            -- =========================
            if ACE.CritEnts[Tar:GetClass()] then

                timer.Simple(0.03, function()
                    if not IsValid(Tar) then return end

                    local NewHitpos = LocalToWorld(
                        Table.LocalHitpos + Table.LocalHitpos:GetNormalized() * 3,
                        Angle(math.random(), math.random(), math.random()),
                        TargetPos,
                        Tar:GetAngles()
                    )
                    local NewHitat  = Tar:NearestPoint(NewHitpos)

                    local Occlusion = {
                        start = NewHitpos,
                        endpos = NewHitat + (NewHitat - NewHitpos):GetNormalized() * 100,
                        filter = NoOcc,
                    }
                    local Occ = util.TraceLine(Occlusion)

                    if not Occ.Hit and NewHitpos ~= NewHitat then
                        NewHitat = TargetPos
                        Occlusion.endpos = NewHitat + (NewHitat - NewHitpos):GetNormalized() * 100
                        Occ = util.TraceLine(Occlusion)
                    end

                    if not (Occ.Hit and Occ.Entity:EntIndex() ~= Tar:EntIndex())
                        and not (not Occ.Hit and NewHitpos ~= NewHitat) then

                        local localBlastRes = ACF_Damage(Tar, Blast, AreaAdjusted, 0, Inflictor, 0, Gun, "HE")

                        if FragKE and FragHit >= 1 and not FragsBlocked then
                            local localFragRes = ACF_Damage(Tar, FragKE, FragDamageArea, 0, Inflictor, Table.HitGroup, Gun, "Frag")

                            if (localBlastRes and localBlastRes.Kill) or (localFragRes and localFragRes.Kill) then
                                ACF_HEKill(Tar, (TargetPos - NewHitpos):GetNormalized(), PowerFraction, Hitpos)
                            else
                                ACF_KEShove(Tar, NewHitpos, (TargetPos - NewHitpos):GetNormalized(),
                                    PowerFraction * 1 * (GetConVar("acf_hepush"):GetFloat() or 1), Inflictor)
                            end
                        else
                            if localBlastRes and localBlastRes.Kill then
                                ACF_HEKill(Tar, (TargetPos - NewHitpos):GetNormalized(), PowerFraction, Hitpos)
                            else
                                ACF_KEShove(Tar, NewHitpos, (TargetPos - NewHitpos):GetNormalized(),
                                    PowerFraction * 1 * (GetConVar("acf_hepush"):GetFloat() or 1), Inflictor)
                            end
                        end
                    end
                end)

                BlastRes = ACF_CalcDamage(Tar, Blast, AreaAdjusted, 0)
                targetInfo.Hit = true
                Stats.EntitiesHit = Stats.EntitiesHit + 1

            else
                BlastRes = ACF_Damage(Tar, Blast, AreaAdjusted, 0, Inflictor, 0, Gun, "HE")

                if FragKE and FragVelAtDist > ACF.MinLethalFragVel and FragHit >= 1 and not FragsBlocked then
                    FragRes = ACF_Damage(Tar, FragKE, FragDamageArea, 0, Inflictor, Table.HitGroup, Gun, "Frag")
                end

                targetInfo.Hit = true
                targetInfo.FragsBlocked = FragsBlocked
                Stats.EntitiesHit = Stats.EntitiesHit + 1

                if (BlastRes and BlastRes.Kill) or (FragRes and FragRes.Kill) then
                    local Debris = ACF_HEKill(Tar, Table.Vec, PowerFraction, Hitpos)
                    table.insert(OccFilter, Debris)

                    LoopKill = true
                    targetInfo.Killed = true
                    Stats.EntitiesKilled = Stats.EntitiesKilled + 1
                else
                    ACF_KEShove(Tar, Hitpos, Table.Vec,
                        PowerFraction * 5 * (GetConVar("acf_hepush"):GetFloat() or 1), Inflictor)
                end
            end

            table.insert(Stats.TargetBreakdown, targetInfo)

            if BlastRes and BlastRes.Loss then
                PowerSpent = PowerSpent + PowerFraction * BlastRes.Loss / 2
            end
        end

        TotalPowerSpent = TotalPowerSpent + PowerSpent
        Power = math.max(Power - PowerSpent, 0)
    end

    Stats.Iterations = IterationCount
    Stats.PowerSpent = TotalPowerSpent
    Stats.PowerRemaining = Power

    local RadiusSQ = 15 * Radius ^ 2
    for _, Tar in ipairs(player.GetAll()) do
        if Tar:HasGodMode() then continue end
        local Difpos = (Tar:GetPos() - Hitpos)
        local PlayerDist = Difpos:LengthSqr() + 0.001

        if PlayerDist > RadiusSQ then continue end
        local DifAngle = Difpos:Angle()
        local RelAngle = (Angle(-DifAngle.pitch, DifAngle.yaw, 0)) - Tar:EyeAngles() + Angle(360, -180, 0)
        RelAngle = Angle(math.NormalizeAngle(RelAngle.pitch), math.NormalizeAngle(RelAngle.yaw))
        RelAngle = Angle(RelAngle.pitch > 0 and 1 or (RelAngle.pitch == 0 and 0 or -1), RelAngle.yaw > 0 and 1 or (RelAngle.yaw == 0 and 0 or -1), 0)

        PlayerDist = math.max(PlayerDist, 13949)

        local shakeBoost = IsSurfaceDet and BaseSurfaceBoost or 1

        Tar:ViewPunch( Angle(
            math.Clamp(RelAngle.pitch * Amp * shakeBoost * -120000 / PlayerDist * math.Rand(0.5, 1), -60, 60),
            math.Clamp(RelAngle.yaw * Amp * shakeBoost * -100000 / PlayerDist * math.Rand(0.5, 1), -60, 60),
            math.Clamp(RelAngle.yaw * Amp * shakeBoost * 50000 / PlayerDist * math.Rand(0.5, 1), -60, 60)
        ))
    end

    Stats.ProcessingTime = SysTime() - StartTime

end


--Handles normal spalling
function ACF_Spall( HitPos , HitVec , Filter , KE , Caliber , _ , Inflictor , Material) --_ = Armor

	--Don't use it if it's not allowed to
	if not ACF.Spalling then return end

	local Mat		= Material or "RHA"
	local MatData	= ACE_GetMaterialData( Mat )

	-- Spall damage
	local SpallMul	= MatData.spallmult or 1

	-- Spall armor factor bias
	local ArmorMul	= MatData.ArmorMul or 1
	
	-- Cal of 3 = 30mm.
	local Minimum_Caliber = 3

	if SpallMul > 0 and Caliber > Minimum_Caliber then 
	
		local WeightFactor = MatData.massMod or 1
		-- local Max_Spall_Mass = 10

		local Velocityfactor = 0.5
		local Max_Spall_Vel = 7000
		local MassFactor = 10
		
		local Max_Spalls = 128

		-- print("KE: " .. KE)

		local Cal_In_MM = (Caliber * 10)

		-- print("Cal: ".. Caliber)
		-- print("Cal: ".. Cal_In_MM)

		local Spall = math.min(math.floor(Caliber * ACF.KEtoSpall * SpallMul * 5) * ACF.SpallMult, Max_Spalls)
		local TotalWeight = (Spall / (Cal_In_MM * (PI / 180)))
		local SpallWeight = ((TotalWeight / (Spall / 10)) + (ArmorMul + WeightFactor))
		local SpallVel = ((KE * Velocityfactor) / SpallWeight)
		SpallWeight = SpallWeight * MassFactor
		local SpallArea = 4 * (TotalWeight / SpallWeight)
		local SpallEnergy = ACF_Kinetic(SpallVel, SpallWeight, Max_Spall_Vel)
		

		-- print("AR: " .. SpallArea)
		
		-- print("TW: " .. TotalWeight)

		-- print("SW: " .. SpallWeight)

		-- print("SPALL: " .. Spall)
		-- print("VEL: " .. SpallVel)


		for i = 1,Spall do

			ACE.CurSpallIndex = ACE.CurSpallIndex + 1
			if ACE.CurSpallIndex > ACE.SpallMax then
				ACE.CurSpallIndex = 1
			end

			-- Normal Trace creation
			local Index = ACE.CurSpallIndex

			ACE.Spall[Index] = {}
			ACE.Spall[Index].start  = HitPos
			ACE.Spall[Index].endpos = HitPos + ( HitVec:GetNormalized() + VectorRand() * ACF.SpallingDistribution ):GetNormalized() * math.max( SpallVel / 8, 600 ) --Spall endtrace. Used to determine spread and the spall trace length. Only adjust the value in the max to determine the minimum distance spall will travel. 600 should be fine.
			ACE.Spall[Index].filter = table.Copy(Filter)
			ACE.Spall[Index].mins	= Vector(0,0,0)
			ACE.Spall[Index].maxs	= Vector(0,0,0)

			ACF_SpallTrace(HitVec, Index , SpallEnergy , SpallArea , Inflictor, SpallVel)

			-- little sound optimization
			if i < math.max(math.Round(Spall / 2), 1) then
			 	sound.Play(ACE.Sounds["Penetrations"]["large"]["close"][math.random(1,#ACE.Sounds["Penetrations"]["large"]["close"])], HitPos, 75, 100, 0.5)
			 end

		end
	end
end

--Dedicated function for HESH spalling
function ACF_PropShockwave( HitPos, HitVec, Filter, Caliber )
	--Don't even bother at calculating something that doesn't exist
	if table.IsEmpty(Filter) then return end
	--General
	local FindEnd	= true			--marked for initial loop
	local iteration	= 0				--since while has not index
	local EntsToHit	= Filter	--Used for the second tracer, where it tells what ents must hit
	--HitPos
	local HitFronts	= {}				--Any tracefronts hitpos will be stored here
	local HitBacks	= {}				--Any traceback hitpos will be stored here
	--Distances. Store any distance
	local FrontDists	= {}
	local BackDists	= {}
	local Normals	= {}
	--Results
	local fNormal	= Vector(0,0,0)
	local finalpos
	local TotalArmor	= {}
	--Tracefront general data--
	local TrFront	= {}
	TrFront.start	= HitPos
	TrFront.endpos	= HitPos + HitVec:GetNormalized() * Caliber * 1.5
	TrFront.ignoreworld = true
	TrFront.filter	= {}
	--Traceback general data--
	local TrBack		= {}
	TrBack.start		= HitPos + HitVec:GetNormalized() * Caliber * 1.5
	TrBack.endpos	= HitPos
	TrBack.ignoreworld  = true
	TrBack.filter	= function( ent ) if ( ent:EntIndex() == EntsToHit[#EntsToHit]:EntIndex()) then return true end end
	while FindEnd do
		iteration = iteration + 1
		--print('iteration #' .. iteration)
		--In case of total failure, this loop is limited to 1000 iterations, don't make me increase it even more.
		if iteration >= 1000 then FindEnd = false end
		--================-TRACEFRONT-==================-
		local tracefront = util.TraceHull( TrFront )
		--insert the hitpos here
		local HitFront = tracefront.HitPos
		table.insert( HitFronts, HitFront )
		--distance between the initial hit and hitpos of front plate
		local distToFront = math.abs( (HitPos - HitFront):Length() )
		table.insert( FrontDists, distToFront)
		--TraceFront's armor entity
		local Armour = tracefront.Entity.ACF and tracefront.Entity.ACF.Armour or 0
		--Code executed once its scanning the 2nd prop
		if iteration > 1 then
			--check if they are totally overlapped
			if math.Round(FrontDists[iteration-1]) ~= math.Round(FrontDists[iteration] ) then
				--distance between the start of ent1 and end of ent2
				local space = math.abs( (HitFronts[iteration] - HitBacks[iteration - 1]):Length() )
				--prop's material
				local mat = tracefront.Entity.ACF and tracefront.Entity.ACF.Material or "RHA"
				local MatData = ACE_GetMaterialData( mat )
				local Hasvoid = false
				local NotOverlap = false
				--print("DATA TABLE - DONT FUCKING DELETE")
				--print('distToFront: ' .. distToFront)
				--print('BackDists[iteration - 1]: ' .. BackDists[iteration - 1])
				--print('DISTS DIFF: ' .. distToFront - BackDists[iteration - 1])
				--check if we have void
				if space > 1 then
					Hasvoid = true
				end
				--check if we dont have props semi-overlapped
				if distToFront > BackDists[iteration - 1] then
					NotOverlap = true
				end
				--check if we have spaced armor, spall liners ahead, if so, end here
				if (Hasvoid and NotOverlap) or (tracefront.Entity:IsValid() and ACE.CritEnts[ tracefront.Entity:GetClass() ]) or MatData.Stopshock then
					--print("stopping")
					FindEnd	= false
					finalpos	= HitBacks[iteration - 1] + HitVec:GetNormalized() * 0.1
					fNormal	= Normals[iteration - 1]
					--print("iteration #' .. iteration .. ' / FINISHED!")
					break
				end
			end
			--start inserting new ents to the table when iteration pass 1, so we don't insert the already inserted prop (first one)
			table.insert( EntsToHit, tracefront.Entity)
		end
		--Filter this ent from being processed again in the next checks
		table.insert( TrFront.filter, tracefront.Entity )
		--Add the armor value to table
		table.insert( TotalArmor, Armour )
		--================-TRACEBACK-==================
		local traceback = util.TraceHull( TrBack )
		--insert the hitpos here
		local HitBack = traceback.HitPos
		table.insert( HitBacks, HitBack )
		--store the dist between the backhit and the hitvec
		local distToBack = math.abs( (HitPos - HitBack):Length() )
		table.insert( BackDists, distToBack)
		table.insert( Normals, traceback.HitNormal )
		--flag this iteration as lost
		if not tracefront.Hit then
			--print("[ACE|WARN]- TRACE HAS BROKEN!")
			FindEnd	= false
			finalpos	= HitBack + HitVec:GetNormalized() * 0.1
			fNormal	= Normals[iteration]
			--print("iteration #' .. iteration .. ' / FINISHED")
			break
		end
		--for red traceback
		--debugoverlay.Line( traceback.StartPos + Vector(0,0,#EntsToHit * 0.1), traceback.HitPos + Vector(0,0,#EntsToHit * 0.1), 20 , Color(math.random(100,255),0,0) )
		--for green tracefront
		--debugoverlay.Line( tracefront.StartPos + Vector(0,0,#EntsToHit * 0.1), tracefront.HitPos + Vector(0,0,#EntsToHit * 0.1), 20 , Color(0,math.random(100,255),0) )
	end
	local ArmorSum = 0
	for i = 1, #TotalArmor do
		--print("Armor prop count: ' .. i..", Armor value: ' .. TotalArmor[i])
		ArmorSum = ArmorSum + TotalArmor[i]
	end
	--print(ArmorSum)
	return finalpos, ArmorSum, TrFront.filter, fNormal
end


--Handles HESH spalling
function ACF_Spall_HESH( HitPos, HitVec, Filter, HEFiller, Caliber, Armour, Inflictor, Material )

	local Temp_Filter = Filter
	local _, Armour, PEnts, fNormal = ACF_PropShockwave( HitPos, -HitVec, Filter, Caliber )
	table.Add( Temp_Filter , PEnts )

	--Don't use it if it's not allowed to
	if not ACF.Spalling then return end

	local Mat		= Material or "RHA"
	local MatData	= ACE_GetMaterialData( Mat )

	-- Spall damage
	local SpallMul	= MatData.spallmult or 1

	-- Spall armor factor bias
	local ArmorMul	= MatData.ArmorMul or 1
	
	local UsedArmor	= Armour * ArmorMul

	if SpallMul > 0 and ( HEFiller / 300 ) > UsedArmor then

		local WeightFactor = MatData.massMod or 1
		-- local Max_Spall_Mass = 20

		local Velocityfactor = 0.2
		local Max_Spall_Vel = 7000
		
		local Max_Spalls = 128

		-- print("HE: " .. HEFiller)

		local Cal_In_MM = (Caliber * 10)

		-- print("Cal: ".. Caliber)
		-- print("Cal: ".. Cal_In_MM)

		local Spall = math.min(math.floor(Caliber * HEFiller * SpallMul * 5) * ACF.SpallMult, Max_Spalls)
		local TotalWeight = (Spall / (Cal_In_MM * (PI / 180)))
		local SpallWeight = ((TotalWeight / (Spall / 10)) + (ArmorMul + WeightFactor))
		local SpallVel = ((HEFiller * Velocityfactor) / SpallWeight)
		local SpallArea = (TotalWeight / SpallWeight)
		local SpallEnergy = ACF_Kinetic(SpallVel, SpallWeight, Max_Spall_Vel)
		
		-- print("AR: " .. SpallArea)
		
		-- print("TW: " .. TotalWeight)

		-- print("SW: " .. SpallWeight)

		-- print("HESH: " .. Spall)
		-- print("VEL: " .. SpallVel)

		-- PrintTable(Filter)
		
		for i = 1,Spall do

			ACE.CurSpallIndex = ACE.CurSpallIndex + 1
			if ACE.CurSpallIndex > ACE.SpallMax then
				ACE.CurSpallIndex = 1
			end

			-- Normal Trace creation
			local Index = ACE.CurSpallIndex
			
			ACE.Spall[Index]			= {}
			ACE.Spall[Index].start	= HitPos
			ACE.Spall[Index].endpos	= HitPos + ((fNormal * 2500 + HitVec):GetNormalized() + VectorRand() / 3):GetNormalized() * math.max( SpallVel / 8, 600) --I got bored of spall not going across the tank
			ACE.Spall[Index].filter	= table.Copy(Temp_Filter)
			
			ACF_SpallTrace(HitVec, Index , SpallEnergy , SpallArea , Inflictor, SpallVel)

			--little sound optimization
			if i < math.max(math.Round(Spall / 2), 1) then
				sound.Play(ACE.Sounds["Penetrations"]["large"]["close"][math.random(1,#ACE.Sounds["Penetrations"]["large"]["close"])], HitPos, 75, 100, 0.5)
			end

		end
	end
end



--Spall trace core. For HESH and normal spalling
function ACF_SpallTrace(HitVec, Index, SpallEnergy, SpallArea, Inflictor, SpallVelocity )

	local Entity_Crit_Hit_Factor = 1.01

	local SpallRes = util.TraceLine(ACE.Spall[Index])

	-- Check if spalling hit something
	if SpallRes.Hit and ACF_Check( SpallRes.Entity ) then

		do

			local phys = SpallRes.Entity:GetPhysicsObject()

			if IsValid(phys) and ACF_CheckClips( SpallRes.Entity, SpallRes.HitPos ) then

				local Temp_Filter = table.Copy(ACE.Spall[Index].filter)
				table.insert( Temp_Filter , SpallRes.Entity )

				ACE.Spall[Index] = {}
				ACE.Spall[Index].start  = SpallRes.HitPos
				ACE.Spall[Index].endpos = SpallRes.HitPos + ( SpallRes.HitNormal + VectorRand() * ACF.SpallingDistribution ):GetNormalized() * math.max( SpallVelocity / 8, 600)
				ACE.Spall[Index].filter = Temp_Filter
				ACE.Spall[Index].mins	= Vector(0,0,0)
				ACE.Spall[Index].maxs	= Vector(0,0,0)
			
				ACF_SpallTrace( SpallRes.HitPos , Index , SpallEnergy , SpallArea , Inflictor, SpallVelocity )
				return
			end

		end

		-- Get the spalling hitAngle
		local Angle		= ACF_GetHitAngle( SpallRes.HitNormal , HitVec )
		-- print("ANGLE: " .. Angle)

		local Mat		= SpallRes.Entity.ACF.Material or "RHA"
		local MatData	= ACE_GetMaterialData( Mat )

		local spall_resistance = MatData.spallresist
		
		-- The clamp is due to that if the material spall resist/armor is below 1 then it multiplies the penetration. 
		-- ^ Clamp keeps the variable at 1 or higher.
		-- Such as why I have ceramic/textolite resistence set to 1 as that means spall doesnt lose energy when hitting it.
		-- Two/three reasons why this is good ^:
		-- 1. Ceramic/textolite are extremely brittle and once hit usually shatters, if you overthink it then the spall would be like blades of grass cutting through sand.
		-- 2. It is extremely easy to overtweak the resistence as setting it even to 2 means the penetration will be lost within seconds due to the interval this script runs at.
		-- 3. Regarding 2. This is for all materials. I have carefully selected the resistences for them.
		local Final_Spall_Resistence = math.Clamp(spall_resistance, 1, 999)
		Entity_Crit_Hit_Factor = math.Clamp(Entity_Crit_Hit_Factor, 1, 999)

		SpallEnergy.Penetration = (SpallEnergy.Penetration / Final_Spall_Resistence)

		--extra damage for ents like ammo, engines, etc
		if ACE.CritEnts[ SpallRes.Entity:GetClass() ] then
			SpallEnergy.Penetration = (SpallEnergy.Penetration / Entity_Crit_Hit_Factor)
		end
		
		SpallEnergy.Penetration = math.floor(SpallEnergy.Penetration)
		
		-- print(SpallEnergy.Penetration)

		-- Applies the damage to the impacted entity
		local HitRes = ACF_Damage( SpallRes.Entity , SpallEnergy , SpallArea , Angle , Inflictor, 0, nil, "Spall") --Angle replaced with 0 for inconsistent spall

		-- If it's able to destroy it, kill it and filter it
		if HitRes.Kill then
			local Debris = ACF_APKill( SpallRes.Entity , HitVec:GetNormalized() , SpallEnergy.Kinetic )
			if IsValid(Debris) then
				table.insert( ACE.Spall[Index].filter , Debris )
				ACF_SpallTrace( SpallRes.HitPos , Index , SpallEnergy , SpallArea , Inflictor, SpallVelocity )
			end
		end

		-- Applies a decal
		util.Decal("GunShot1",SpallRes.StartPos, SpallRes.HitPos, ACE.Spall[Index].filter )

		-- The entity was penetrated --Disabled since penetration values are not real
		if HitRes.Overkill > 0 then

			local Temp_Filter = table.Copy(ACE.Spall[Index].filter)
			table.insert( Temp_Filter , SpallRes.Entity )
				
			ACE.Spall[Index] = {}
			ACE.Spall[Index].start  = SpallRes.HitPos
			ACE.Spall[Index].endpos = SpallRes.HitPos + ( SpallRes.HitNormal + VectorRand() * ACF.SpallingDistribution ):GetNormalized() * math.max( SpallVelocity / 8, 600)
			ACE.Spall[Index].filter = Temp_Filter
			ACE.Spall[Index].mins	= Vector(0,0,0)
			ACE.Spall[Index].maxs	= Vector(0,0,0)
			
			SpallRes = util.TraceLine(ACE.Spall[Index])

			debugoverlay.Line( SpallRes.StartPos, SpallRes.HitPos, 30 , Color(0,0,255), true )
			-- Blue trace means spall trace that overpenned and killed something.
			
			-- Retry
			ACF_SpallTrace( SpallRes.HitPos , Index , SpallEnergy , SpallArea , Inflictor, SpallVelocity )
			return
		else 
			debugoverlay.Line( SpallRes.StartPos, SpallRes.HitPos, 30 , Color(255,0,0), true )	
			-- Red trace means spall trace that did hit something.
		end

	else
		debugoverlay.Line( SpallRes.StartPos, SpallRes.HitPos, 30 , Color(0,255,0), true )
		-- Green trace means spall trace that doesn't hit something.
	end
end

--Calculates the vector of the ricochet of a round upon impact at a set angle
function ACF_RicochetVector(Flight, HitNormal)
	local Vec = Flight:GetNormalized()

	return Vec - ( 2 * Vec:Dot(HitNormal) ) * HitNormal
end

-- Handles the impact of a round on a target
function ACF_RoundImpact( Bullet, Speed, Energy, Target, HitPos, HitNormal , Bone  )

	--[[
		print("======DATA=======")
		print(HitNormal)
		print(Bullet["Flight"])
		print("======DATA=======")

		debugoverlay.Line(HitPos, HitPos + (Bullet["Flight"]), 5, Color(255,100,0), true )
		debugoverlay.Line(HitPos, HitPos + (HitNormal * 100), 5, Color(255,255,0), true )
	]]
	Bullet.Ricochets = Bullet.Ricochets or 0

	local Angle	= ACF_GetHitAngle( HitNormal , Bullet["Flight"] )
	local HitRes	= ACF_Damage( Target, Energy, Bullet["PenArea"], Angle, Bullet["Owner"], Bone, Bullet["Gun"], Bullet["Type"] )

	HitRes.Ricochet = false

	local Ricochet  = 0
	local ricoProb  = 1

	--Missiles are special. This should be dealt with guns only
	if (IsValid(Bullet["Gun"]) and Bullet["Gun"]:GetClass() ~= "acf_missile" and Bullet["Gun"]:GetClass() ~= "ace_missile_swep_guided") or not IsValid(Bullet["Gun"]) then

		local sigmoidCenter = Bullet.DetonatorAngle or ( (Bullet.Ricochet or 55) - math.max(Speed / 39.37 - (Bullet.LimitVel or 800),0) / 100 ) --Changed the abs to a min. Now having a bullet slower than normal won't increase chance to richochet.

		--Guarenteed Richochet
		if Angle > (Bullet.Ricochet or 85) then
			ricoProb = 0

		--Guarenteed to not richochet
		elseif Bullet.Caliber * 3.33 > Target.ACF.Armour  then -- / math.max(math.sin(90-Angle),0.0001)
			ricoProb = 1

		else
			ricoProb = math.min(1-(math.max(Angle - sigmoidCenter,0) / sigmoidCenter * 4),1)
		end
	end

	-- Checking for ricochet. The angle value is clamped but can cause game crashes if this overflow check doesnt exist. Why?
	if ricoProb < math.Rand(0,1) and Angle < 90 then
		Ricochet	= math.Clamp( Angle / 90, 0.05, 0.2) -- atleast 5% of energy is kept, but no more than 20%
		HitRes.Loss	= 1 - Ricochet
		Energy.Kinetic = Energy.Kinetic * HitRes.Loss
	end

	if HitRes.Kill then
		local Debris = ACF_APKill( Target , (Bullet["Flight"]):GetNormalized() , Energy.Kinetic )
		table.insert( Bullet["Filter"] , Debris )
	end

	if Ricochet > 0 and Bullet.Ricochets < 5 and IsValid(Target) then

		Bullet.Ricochets	= Bullet.Ricochets + 1
		Bullet["Pos"]	= HitPos + HitNormal * 0.05
		Bullet.FlightTime	= 0
		Bullet.Flight = Bullet.Flight * 0.05 --0.05 = ~35 m/s for a 700 m/s projectile
		Bullet.Flight	= (ACF_RicochetVector(Bullet.Flight, HitNormal) + VectorRand() * 0.05):GetNormalized() * Ricochet

		if IsValid( ACF_GetPhysicalParent(Target):GetPhysicsObject() ) then
			Bullet.TraceBackComp = math.max(ACF_GetPhysicalParent(Target):GetPhysicsObject():GetVelocity():Dot(Bullet["Flight"]:GetNormalized()),0)
		end

		HitRes.Ricochet = true

	end

	ACF_KEShove(Target, HitPos, Bullet["Flight"]:GetNormalized(), Energy.Kinetic * HitRes.Loss * 500 * Bullet["ShovePower"] * (GetConVar("acf_kepush"):GetFloat() or 1), Bullet.Owner)

	return HitRes
end

--Handles Ground penetrations
function ACF_PenetrateGround( Bullet, Energy, HitPos, HitNormal )

	Bullet.GroundRicos = Bullet.GroundRicos or 0

	local MaxDig = (( Energy.Penetration * 1 / Bullet.PenArea ) * ACF.KEtoRHA / ACF.GroundtoRHA ) / 25.4

	--print("Max Dig: " .. MaxDig .. "\nEnergy Pen: " .. Energy.Penetration .. "\n")

	local HitRes = {Penetrated = false, Ricochet = false}
	local TROffset = 0.235 * Bullet.Caliber / 1.14142 --Square circumscribed by circle. 1.14142 is an aproximation of sqrt 2. Radius and divide by 2 for min/max cancel.

	local DigRes = util.TraceHull( {

		start = HitPos + Bullet.Flight:GetNormalized() * 0.1,
		endpos = HitPos + Bullet.Flight:GetNormalized() * (MaxDig + 0.1),
		filter = Bullet.Filter,
		mins = Vector( -TROffset, -TROffset, -TROffset ),
		maxs = Vector( TROffset, TROffset, TROffset ),
		mask = MASK_SOLID_BRUSHONLY

		} )

	--debugoverlay.Box( DigRes.StartPos, Vector( -TROffset, -TROffset, -TROffset ), Vector( TROffset, TROffset, TROffset ), 5, Color(0,math.random(100,255),0) )
	--debugoverlay.Box( DigRes.HitPos, Vector( -TROffset, -TROffset, -TROffset ), Vector( TROffset, TROffset, TROffset ), 5, Color(0,math.random(100,255),0) )
	--debugoverlay.Line( DigRes.StartPos, HitPos + Bullet.Flight:GetNormalized() * (MaxDig + 0.1), 5 , Color(0,math.random(100,255),0) )

	local loss = DigRes.FractionLeftSolid

	--couldn't penetrate
	if loss == 1 or loss == 0 then

		local Ricochet  = 0
		local Speed	= Bullet.Flight:Length() / ACF.VelScale
		local Angle	= ACF_GetHitAngle( HitNormal, Bullet.Flight )
		local MinAngle  = math.min(Bullet.Ricochet - Speed / 39.37 / 30 + 20,89.9)  --Making the chance of a ricochet get higher as the speeds increase

		if Angle > math.random(MinAngle,90) and Angle < 89.9 then	--Checking for ricochet
			Ricochet = Angle / 90 * 0.75
		end

		if Ricochet > 0 and Bullet.GroundRicos < 2 then
			Bullet.GroundRicos  = Bullet.GroundRicos + 1
			Bullet.Pos		= HitPos + HitNormal * 1
			Bullet.Flight	= (ACF_RicochetVector(Bullet.Flight, HitNormal) + VectorRand() * 0.05):GetNormalized() * Speed * Ricochet
			HitRes.Ricochet	= true
		end

	--penetrated
	else
		--print("Pen")
		Bullet.Flight	= Bullet.Flight * (1 - loss)
		Bullet.Pos		= DigRes.StartPos + Bullet.Flight:GetNormalized() * 0.25 --this is actually where trace left brush
		HitRes.Penetrated	= true
	end

	return HitRes
end

--helper function to replace ENT:ApplyForceOffset()
--Gmod applyforce creates weird torque when moving https://github.com/Facepunch/garrysmod-issues/issues/5159
local m_insq = 1 / 39.37 ^ 2
local function ACE_ApplyForceOffset(Phys, Force, Pos) --For some reason this function somestimes reverses the impulse. I don't know why. Deal with this another day.
	--Old
	Phys:ApplyForceCenter(Force)
	local off = Pos - Phys:LocalToWorld(Phys:GetMassCenter())
	local angf = off:Cross(Force) * m_insq * 360 / (2 * 3.1416)

	Phys:ApplyTorqueCenter(angf)
end

--Handles ACE forces (HE Push, Recoil, etc)
function ACF_KEShove(Target, Pos, Vec, KE, Inflictor)
	local CanDo = hook.Run("ACF_KEShove", Target, Pos, Vec, KE, Inflictor)
	if CanDo == false then return end

	--Gets the baseplate of target
	local parent	= ACF_GetPhysicalParent(Target)
	local phys	= parent:GetPhysicsObject()

	if not IsValid(phys) then return end

	if not Target.acflastupdatemass or ((Target.acflastupdatemass + 10) < CurTime()) then
		ACF_CalcMassRatio(Target)
	end

	--corner case error check
	if not Target.acfphystotal then return end

	local physratio = Target.acfphystotal / Target.acftotal
	--local physratio = 0.03
	--print(KE)

	--local Scaling = 1

	--Scale down the offset relative to chassis if the gun is parented
	--if Target:EntIndex() ~= parent:EntIndex() then
	--Scaling = 87.5
	--end

	--local Local	= parent:WorldToLocal(Pos) / Scaling
	--local Res	= Local + phys:GetMassCenter()
	--Pos			= parent:LocalToWorld(Res)

	if ACF.UseLegacyRecoil < 1 then
		ACE_ApplyForceOffset(phys, Vec:GetNormalized() * KE * physratio, Pos ) --Had a lot of odd quirks including reversing torque angles.
	else
		phys:ApplyForceCenter( Vec:GetNormalized() * KE * physratio )
	end
end

-- helper function to process children of an acf-destroyed prop
-- AP will HE-kill children props like a detonation; looks better than a directional spray of unrelated debris from the AP kill
local function ACF_KillChildProps( Entity, BlastPos, Energy )

	if ACF.DebrisChance <= 0 then return end
	local children = ACF_GetAllChildren(Entity)

	--why should we make use of this for ONE prop?
	if table.Count(children) > 1 then

		local count = 0
		local boom = {}

		-- do an initial processing pass on children, separating out explodey things to handle last
		for _, ent in pairs( children ) do --print('table children: ' .. table.Count( children ))

			--Removes the first impacted entity. This should avoid debris being duplicated there.
			if Entity:EntIndex() == ent:EntIndex() then children[ent] = nil continue end

			-- mark that it's already processed
			ent.ACF_Killed = true

			local class = ent:GetClass()

			-- exclude any entity that is not part of debris ents whitelist
			if not ACF.Debris[class] then --print("removing not valid class")
				children[ent] = nil continue
			else

				-- remove this ent from children table and move it to the explosive table
				if ACE.ExplosiveEnts[class] and not ent.Exploding then

					table.insert( boom , ent )
					children[ent] = nil

					continue
				else
					-- can't use #table or :count() because of ent indexing...
					count = count + 1
				end
			end
		end

		-- HE kill the children of this ent, instead of disappearing them by removing parent
		if count > 0 then

			local power = Energy / math.min(count,3)

			for _, child in pairs( children ) do --print('table children#2: ' .. table.Count( children ))

				--Skip any invalid entity
				if not IsValid(child) then continue end

				local rand = math.random(0,100) / 100 --print(rand) print(ACF.DebrisChance)

				-- ignore some of the debris props to save lag
				if rand > ACF.DebrisChance then continue end

				ACF_HEKill( child, (child:GetPos() - BlastPos):GetNormalized(), power )

				constraint.RemoveAll( child )
				child:Remove()
			end
		end

		-- explode stuff last, so we don't re-process all that junk again in a new explosion
		if next( boom ) then

			for _, child in pairs( boom ) do

				if not IsValid(child) or child.Exploding then continue end

				child.Exploding = true
				ACF_ScaledExplosion( child, true ) -- explode any crates that are getting removed

			end
		end
	end
end

-- Remove the entity
local function RemoveEntity( Entity )
	constraint.RemoveAll( Entity )
	Entity:Remove()
end

-- Creates a debris related to explosive destruction.
function ACF_HEKill( Entity , HitVector , Energy , BlastPos )

	-- if it hasn't been processed yet, check for children
	if not Entity.ACF_Killed then ACF_KillChildProps( Entity, BlastPos or Entity:GetPos(), Energy ) end

	do
		--ERA props should not create debris
		local Mat = (Entity.ACF and Entity.ACF.Material) or "RHA"
		local MatData = ACE_GetMaterialData( Mat )
		if MatData.IsExplosive then return end
	end

	local Debris

	-- Create a debris only if the dead entity is greater than the specified scale.
	if not IsUselessModel(Entity:GetModel()) and Entity:BoundingRadius() > ACF.DebrisScale then

		Debris = ents.Create( "ace_debris" )
		if IsValid(Debris) then

			Debris:SetModel( Entity:GetModel() )
			Debris:SetAngles( Entity:GetAngles() )
			Debris:SetPos( Entity:GetPos() )
			Debris:SetMaterial("models/props_wasteland/metal_tram001a")
			Debris:Spawn()
			Debris:Activate()

			if math.random() < ACF.DebrisIgniteChance then
				Debris:Ignite(math.Rand(5,45),0)
			end

			-- Applies force to this debris
			local phys = Debris:GetPhysicsObject()
			local physent = Entity:GetPhysicsObject()
			local Parent = ACF_GetPhysicalParent( Entity )

			if IsValid(phys) and IsValid(physent) then
				phys:SetDragCoefficient( 5 )
				phys:SetMass( math.max(physent:GetMass() * 3,300) )
				phys:SetVelocity( Parent:GetVelocity() )

				if IsValid(Parent) then
					phys:SetVelocity(Parent:GetVelocity() )
				end

				phys:ApplyForceCenter( (HitVector:GetNormalized() + VectorRand() * 0.5) * Energy * 50  )
			end
		end
	end

	-- Remove the entity
	RemoveEntity( Entity )

	return Debris
end

-- Creates a debris related to kinetic destruction.
function ACF_APKill( Entity , HitVector , Power )
	-- kill the children of this ent, instead of disappearing them from removing parent
	ACF_KillChildProps( Entity, Entity:GetPos(), Power )

	do
		--ERA props should not create debris
		local Mat = (Entity.ACF and Entity.ACF.Material) or "RHA"
		local MatData = ACE_GetMaterialData( Mat )
		if MatData.IsExplosive then return end
	end

	local Debris

	-- Create a debris only if the dead entity is greater than the specified scale.
	if Entity:BoundingRadius() > ACF.DebrisScale then

		local Debris = ents.Create( "ace_debris" )
		if IsValid(Debris) then

			Debris:SetModel( Entity:GetModel() )
			Debris:SetAngles( Entity:GetAngles() )
			Debris:SetPos( Entity:GetPos() )
			Debris:SetMaterial(Entity:GetMaterial())
			Debris:SetColor(Color(120,120,120,255))
			Debris:Spawn()
			Debris:Activate()

			--Applies force to this debris
			local phys = Debris:GetPhysicsObject()
			local physent = Entity:GetPhysicsObject()
			local Parent =  ACF_GetPhysicalParent( Entity )

			if IsValid(phys) and IsValid(physent) then
				phys:SetDragCoefficient( 5 )
				phys:SetMass( math.max(physent:GetMass() * 3,300) )
				phys:SetVelocity(Parent:GetVelocity() )
				if IsValid(Parent) then
					phys:SetVelocity( Parent:GetVelocity() )
				end
				phys:ApplyForceCenter( HitVector:GetNormalized() * Power * 500)
			end
		end
	end

	-- Remove the entity
	RemoveEntity( Entity )

	return Debris
end

do
	-- Config
	local AmmoExplosionScale = 0.5
	local FuelExplosionScale = 0.005

	--converts what would be multiple simultaneous cache detonations into one large explosion
	function ACF_ScaledExplosion( ent , remove )

		if ent.RoundType and ent.RoundType == "Refill" then return end

		local HEWeight
		local ExplodePos = {}

		local MaxGroup    = ACF.ScaledEntsMax	-- Max number of ents to be cached. Reducing this value will make explosions more realistic at the cost of more explosions = lag
		local MaxHE       = ACF.ScaledHEMax	-- Max amount of HE to be cached. This is useful when we dont want nukes being created by large amounts of clipped ammo.

		local HighestHEWeight = 0

		local Inflictor   = ent.Inflictor or nil
		local Owner       = ent:CPPIGetOwner() or NULL

		if ent:GetClass() == "acf_fueltank" then

			local Fuel       = ent.Fuel	or 0
			local Capacity   = ent.Capacity  or 0
			local Type       = ent.FuelType  or "Petrol"

			HEWeight = ( math.min( Fuel, Capacity ) / ACF.FuelDensity[Type] ) * FuelExplosionScale
		else

			local HE       = ent.BulletData.FillerMass	or 0
			local Propel   = ent.BulletData.PropMass	or 0
			local Ammo     = ent.Ammo					or 0

			HEWeight = ( ( HE + Propel * ( ACF.PBase / ACF.HEPower ) ) * Ammo ) * AmmoExplosionScale
		end

		local Radius    = ACE_CalculateHERadius( HEWeight )
		local Pos       = ent:LocalToWorld(ent:OBBCenter())

		table.insert(ExplodePos, Pos)

		local LastHE = 0
		local Search = true
		local Filter = { ent }

		if remove then
			ent:Remove()
		end

		local CExplosives = ACE.Explosives

		while Search do

			if #CExplosives == 1 then break end

			for i,Found in ipairs( CExplosives ) do

				if #Filter > MaxGroup or HEWeight > MaxHE then break end
				if not IsValid(Found) then continue end
				if Found:GetPos():DistToSqr(Pos) > Radius ^ 2 then continue end
				if not remove and ent == Found then continue end

				if not Found.Exploding then

					local EOwner = Found:CPPIGetOwner() or NULL

					--Don't detonate explosives which we are not allowed to.
					if Owner ~= EOwner then continue end

					local Hitat = Found:NearestPoint( Pos )

					local Occlusion = {}
						Occlusion.start   = Pos
						Occlusion.endpos  = Hitat + (Hitat-Pos):GetNormalized() * 100
						Occlusion.filter  = Filter
					local Occ = util.TraceLine( Occlusion )

					--Filters any ent which blocks the trace.
					if Occ.Fraction == 0 then

						table.insert(Filter,Occ.Entity)

						Occlusion.filter	= Filter

						Occ = util.TraceLine( Occlusion )

					end

					if Occ.Hit and Occ.Entity:EntIndex() == Found.Entity:EntIndex() then

						local FoundHEWeight

						if Found:GetClass() == "acf_fueltank" then

							local Fuel       = Found.Fuel	or 0
							local Capacity   = Found.Capacity or 0
							local Type       = Found.FuelType or "Petrol"

							FoundHEWeight = ( math.min( Fuel, Capacity ) / ACF.FuelDensity[Type] ) * FuelExplosionScale

							if FoundHEWeight > HighestHEWeight then
								HighestHEWeight = FoundHEWeight
							end
						else

							if Found.RoundType == "Refill" then Found:Remove() continue end

							local HE       = Found.BulletData.FillerMass	or 0
							local Propel   = Found.BulletData.PropMass	or 0
							local Ammo     = Found.Ammo					or 0

							local AmmoHEWeight = ( HE + Propel * ACF.APAmmoDetonateFactor * ( ACF.PBase / ACF.HEPower))
							if AmmoHEWeight > HighestHEWeight then
								HighestHEWeight = AmmoHEWeight
							end

							FoundHEWeight = ( AmmoHEWeight * Ammo ) * AmmoExplosionScale
						end


						table.insert( ExplodePos, Found:LocalToWorld(Found:OBBCenter()) )

						HEWeight = HEWeight + FoundHEWeight

						Found.IsExplosive   = false
						Found.DamageAction  = false
						Found.KillAction    = false
						Found.Exploding     = true

						table.insert( Filter,Found )
						table.remove( CExplosives,i )
						Found:Remove()
					else

						if IsValid(Occ.Entity) and Occ.Entity:GetClass() ~= "acf_ammo" and Occ.Entity:GetClass() == "acf_fueltank" then
							if vFireInstalled then
								Occ.Entity:Ignite( _, HEWeight )
							else
								Occ.Entity:Ignite( 120, HEWeight / 10 )
							end
						end
					end
				end


			end

			if HEWeight > LastHE then
				Search = true
				LastHE = HEWeight
				Radius = ACE_CalculateHERadius( HEWeight )
			else
				Search = false
			end

		end

		local totalpos = Vector()
		for _, cratepos in pairs(ExplodePos) do
			totalpos = totalpos + cratepos
		end
		local AvgPos = totalpos / #ExplodePos

		HEWeight	= HEWeight * ACF.BoomMult
		Radius	= ACE_CalculateHERadius( HEWeight )

		--Sets the ratio of HE blast pen so it no longer pens 300mm when 10 shells cookoff.
		--Blastpen will use the HEpower of 2 of the biggest HE detonations or 1/10th the HE power. Whichever is bigger.
		--Then convert that blastpower to a ratio of the HE weight.
		local BlastPenRatio = math.min(math.max(HEWeight * 0.1, HighestHEWeight * 2),1) / HEWeight

		ACF_HE( AvgPos , vector_origin , HEWeight , HEWeight , Inflictor , ent, ent, BlastPenRatio )

		--util.Effect not working during MP workaround. Waiting a while fixes the issue.
		timer.Simple(0.001, function()
			local Flash = EffectData()
				Flash:SetAttachment( 1 )
				Flash:SetOrigin( AvgPos )
				Flash:SetNormal( -vector_up )
				Flash:SetRadius( math.max( Radius , 1 ) )
			util.Effect( "ACE_Scaled_Detonation", Flash )
		end )

	end

end

function ACF_GetHitAngle( HitNormal , HitVector )

	HitVector = HitVector * -1
	local Angle = math.min(math.deg(math.acos(HitNormal:Dot( HitVector:GetNormalized() ) ) ),89.999 )
	--print("Angle : " ..Angle.. "\n")
	return Angle

end

function ACE_CalculateHERadius( HEWeight )
	local Radius = HEWeight ^ 0.33 * 8 * 39.37
	return Radius
end
--



--Calculates the effective armor between two points
--Effangle, Type(1 = KE, 2 = HEAT), Filter
--Might make for a nice e2 function if people probably wouldn't eat the server with it
function ACE_LOSMultiTrace(StartVec, EndVec, PenetrationMax)

	debugoverlay.Line( StartVec, EndVec, 30 , Color(255,0,0), true )

	local Temp_Filter = {}
	local TrTable = {}
	TrTable.mins	= Vector(0,0,0)
	TrTable.maxs	= Vector(0,0,0)
	TrTable.filter	= Temp_Filter
	TrTable.start  = StartVec
	TrTable.endpos = EndVec

	local Normal = (EndVec - StartVec):GetNormalized()

	local TotalArmor = 0

	local UnResolved = true
	local OverRun = 0
	while UnResolved do
		local TraceLine = util.TraceLine(TrTable)

		if TraceLine.Hit and ACF_Check( TraceLine.Entity ) then
			local TraceEnt = TraceLine.Entity
			local phys = TraceLine.Entity:GetPhysicsObject()

			if IsValid(phys) then
				if ACF_CheckClips( TraceEnt, TraceLine.HitPos ) then --Hit visclip. Skip straight to ignoring
					table.insert( TrTable.filter , TraceEnt )
				else
					local Angle		= ACF_GetHitAngle( TraceLine.HitNormal , Normal )
					local Mat			= TraceEnt.ACF.Material or "RHA"	--very important thing
					local MatData		= ACE_GetMaterialData( Mat )
					local armor = TraceEnt.ACF.Armour
					local losArmor		= armor / math.abs( math.cos(math.rad(Angle)) ^ ACF.SlopeEffectFactor ) * MatData["effectiveness"]
					TotalArmor = TotalArmor + losArmor
					table.insert( TrTable.filter , TraceEnt )
				end

			end
			OverRun = OverRun + 1
			if OverRun > 5000 then
				UnResolved = false
				TotalArmor = 999999 -- Only for actual failures
			elseif TotalArmor > (PenetrationMax or 0) and (PenetrationMax or 0) > 0 then
				UnResolved = false
				-- Keep actual TotalArmor value for meaningful debug output
			end

		else --We're done here. Traceline did not hit an entity.
			UnResolved = false
		end
	end

	return TotalArmor

end
