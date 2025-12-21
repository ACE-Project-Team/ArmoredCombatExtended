--visual concept: Here's where should be every acf function

do
	local SendDelay = 1 -- in miliseconds
	local RenderProps = {
		Entities = {},
		Clock = 0
	}
	function ACF_UpdateVisualHealth( Entity )
		if not Entity.ACF.OnRenderQueue then
			table.insert(RenderProps.Entities, Entity )
			Entity.ACF.OnRenderQueue = true
		end
	end
	function ACF_SendVisualDamage()

		local Time = CurTime()

		if next(RenderProps.Entities) and Time >= RenderProps.Clock then

			for k, Ent in ipairs(RenderProps.Entities) do
				if not Ent:IsValid() then
					table.remove( RenderProps.Entities, k )
				end
			end

			local Entity = RenderProps.Entities[1]
			if IsValid(Entity) then
				net.Start("ACF_RenderDamage", true) -- i dont care if the message is not received under extreme cases since its simply a visual effect only.
					net.WriteUInt(Entity:EntIndex(), 13)
					net.WriteFloat(Entity.ACF.MaxHealth)
					net.WriteFloat(Entity.ACF.Health)
				net.Broadcast()

				Entity.ACF.OnRenderQueue = nil
			end
			table.remove( RenderProps.Entities, 1 )

			RenderProps.Clock = Time + (SendDelay / 1000)
		end
	end
	hook.Add("Think","ACF_RenderPropDamage", ACF_SendVisualDamage )
end

--Creates or updates the ACF entity data in a passive way. Meaning this entity wont be updated unless it really requires it (like a shot, damage, looking it using armor tool, etc)
function ACF_Activate( Entity , Recalc )

	--Density of steel = 7.8g cm3 so 7.8kg for a 1mx1m plate 1m thick
	if Entity.SpecialHealth then
		Entity:ACF_Activate( Recalc )
		return
	end

	Entity.ACF = Entity.ACF or {}

	local Count
	local PhysObj = Entity:GetPhysicsObject()
	Entity.ACF.PhysObj = PhysObj

	if PhysObj:GetMesh() then Count = #PhysObj:GetMesh() end

	-- Area calculation
	if Entity:IsPlayer() or Entity:IsNPC() then
		-- Dynamic area based on stance (checked every activation)
		if Entity:IsPlayer() and Entity:Crouching() then
			Entity.ACF.Area = 3500  -- Crouching: ~0.35 m²
		else
			Entity.ACF.Area = 5000  -- Standing: ~0.5 m²
		end
	elseif not Entity.ACF.Area then
		if PhysObj:IsValid() and Count and Count > 100 then
			Entity.ACF.Area = (PhysObj:GetSurfaceArea() * 6.45) * 0.52505066107
		else
			local Size = Entity.OBBMaxs(Entity) - Entity.OBBMins(Entity)
			Entity.ACF.Area = ((Size.x * Size.y) + (Size.x * Size.z) + (Size.y * Size.z)) * 6.45
		end
	end

	-- Setting Armor properties for the first time (or reuse old data if present)
	Entity.ACF.Ductility	= Entity.ACF.Ductility or 0
	Entity.ACF.Material	= not isstring(Entity.ACF.Material) and ACE.BackCompMat[Entity.ACF.Material] or Entity.ACF.Material or "RHA"

	local Area	= Entity.ACF.Area
	local Ductility = math.Clamp( Entity.ACF.Ductility, -0.8, 0.8 )

	local Mat	= Entity.ACF.Material or "RHA"
	local MatData	= ACE_GetMaterialData( Mat )

	local massMod	= MatData.massMod

	local Armour	= ACF_CalcArmor( Area, Ductility, Entity:GetPhysicsObject():GetMass() / massMod ) -- So we get the equivalent thickness of that prop in mm if all its weight was a steel plate
	local Health	= ( Area / ACF.Threshold ) * ( 1 + Ductility ) -- Setting the threshold of the prop Area gone

	local Percent	= 1

	if Recalc and Entity.ACF.Health and Entity.ACF.MaxHealth then
		Percent = Entity.ACF.Health / Entity.ACF.MaxHealth
	end

	Entity.ACF.Health	= Health * Percent
	Entity.ACF.MaxHealth	= Health
	Entity.ACF.Armour = Armour * (0.5 + Percent / 2)
	Entity.ACF.MaxArmour	= Armour * ACF.ArmorMod
	Entity.ACF.Type		= nil
	Entity.ACF.Mass		= PhysObj:GetMass()

	if Entity:IsPlayer() or Entity:IsNPC() then
		Entity.ACF.Type = "Squishy"
	elseif Entity:IsVehicle() then
		Entity.ACF.Type = "Vehicle"
	else
		Entity.ACF.Type = "Prop"
	end

	if Entity:GetClass() == "func_breakable" then
		Entity.DamageOwner = true
	end
end

function ACF_Check( Entity )

	if not IsValid(Entity) then return false end

	local physobj = Entity:GetPhysicsObject()
	if not ( physobj:IsValid() and (physobj:GetMass() or 0) > 0 and not Entity:IsWorld() and not Entity:IsWeapon() ) then return false end

	local Class = Entity:GetClass()
	if ( Class == "gmod_ghost" or Class == "ace_debris" or Class == "prop_ragdoll" or ( Class ~= "func_breakable" and string.find( Class , "func_" ))  ) then return false end
	if Entity.Exploding then return false end

	if not Entity.ACF or (Entity.ACF and isnumber(Entity.ACF.Material)) then
		ACF_Activate( Entity )
	elseif Entity.ACF.Mass ~= physobj:GetMass() or (not IsValid(Entity.ACF.PhysObj) or Entity.ACF.PhysObj ~= physobj) then
		ACF_Activate( Entity , true )
	end

	return Entity.ACF.Type
end

function ACF_Damage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun, Type )

	local Activated = ACF_Check( Entity )
	local CanDo = hook.Run("ACF_BulletDamage", Activated, Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun )
	if CanDo == false or Activated == false then -- above (default) hook does nothing with activated. Excludes godded players.
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	local oldACFTbl = table.Copy( Entity.ACF or {} )
	local hitRes = nil

	if Entity.SpecialDamage then

		hitRes = Entity:ACF_OnDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Type )

	elseif Activated == "Prop" then

		hitRes = ACF_PropDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone , Type)

	elseif Activated == "Vehicle" then

		hitRes = ACF_VehicleDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun , Type)

	elseif Activated == "Squishy" then

		hitRes = ACF_SquishyDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun , Type)

	end

	hook.Run("ACFOnDamage", Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun, Type, hitRes, oldACFTbl)
	return hitRes

end



function ACF_CalcDamage( Entity , Energy , FrArea , Angle , Type) --y=-5/16x + b

	local HitRes			= {}

	local armor			= Entity.ACF.Armour																						-- Armor
	local losArmor		= armor / math.abs( math.cos(math.rad(Angle)) ^ ACF.SlopeEffectFactor )									-- LOS Armor
	local losArmorHealth = armor ^ 1.1 * (3 + math.min(1 / math.abs(math.cos(math.rad(Angle)) ^ ACF.SlopeEffectFactor), 2.8) * 0.5)	-- Bc people had to abuse armor angling, FML

	local Mat			= Entity.ACF.Material or "RHA"	--very important thing
	local MatData		= ACE_GetMaterialData( Mat )

	local damageMult		= 1

	if Type == "AP" then
		damageMult = ACF.APDamageMult
	elseif Type == "Spall" then
		damageMult = ACF.SpallDamageMult
	elseif Type == "APHE" then
		damageMult = ACF.APHEDamageMult
	elseif Type == "APDS" then
		damageMult = ACF.APDSDamageMult
	elseif Type == "APFSDS" then
		damageMult = ACF.APDSDamageMult
	elseif Type == "HVAP" then
		damageMult = ACF.HVAPDamageMult
	elseif Type == "FL" then
		damageMult = ACF.FLDamageMult
	elseif Type == "HEAT" then
		damageMult = ACF.HEATDamageMult
	elseif Type == "HE" then
		damageMult = ACF.HEDamageMult
	elseif Type == "HESH" then
		damageMult = ACF.HESHDamageMult
	elseif Type == "HP" then
		damageMult = ACF.HPDamageMult
	end

	-- RHA Penetration
	local maxPenetration = (Energy.Penetration / FrArea) * ACF.KEtoRHA

	-- Projectile caliber. Messy, function signature
	local caliber = 20 * (FrArea ^ (1 / ACF.PenAreaMod) / 3.1416) ^ 0.5

	--Nifty shell information debugging.
	--print("Type: "..(Type or "Nil"))
	--print("Penetration: " .. math.Round(maxPenetration,3) .. "mm")
	--print("Caliber: "..math.Round(caliber,3).."mm")

	local ACE_ArmorResolution = MatData["ArmorResolution"]
	HitRes = ACE_ArmorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)

	return HitRes
end

-- replaced with _ due to lack of use: Inflictor, Bone
function ACF_PropDamage( Entity , Energy , FrArea , Angle , _, _, Type)

	local HitRes = ACF_CalcDamage( Entity , Energy , FrArea , Angle  , Type)

	HitRes.Kill = false

	local caliber = 20 * (FrArea ^ (1 / ACF.PenAreaMod) / 3.1416) ^ 0.5
	local BaseDamage = caliber * (4 + 0.1 * caliber)



	Entity:TakeDamage(BaseDamage * 15) --Felt about right. Allows destroying physically destructible props.
	if HitRes.Damage >= Entity.ACF.Health then
		HitRes.Kill = true
	else

		--In case of HitRes becomes NAN. That means theres no damage, so leave it as 0
		if HitRes.Damage ~= HitRes.Damage then HitRes.Damage = 0 end

		Entity.ACF.Health = Entity.ACF.Health - HitRes.Damage
		Entity.ACF.Armour = Entity.ACF.MaxArmour * (0.5 + Entity.ACF.Health / Entity.ACF.MaxHealth / 2) --Simulating the plate weakening after a hit

		if Entity.ACF.PrHealth then
			ACF_UpdateVisualHealth(Entity)
		end
		Entity.ACF.PrHealth = Entity.ACF.Health
	end

	return HitRes

end

-- replaced with _ due to lack of use: Bone
function ACF_VehicleDamage(Entity, Energy, FrArea, Angle, Inflictor, _, Gun, Type)

	--We create a dummy table to pass armour values to the calc function
	local Target = {
		ACF = {
			Armour = 2 --8
		}
	}

	local HitRes = ACF_CalcDamage( Target , Energy , FrArea , Angle  , Type)
	local Driver = Entity:GetDriver()
	local validd = Driver:IsValid()

	--In case of HitRes becomes NAN. That means theres no damage, so leave it as 0
	if HitRes.Damage ~= HitRes.Damage then HitRes.Damage = 0 end

	if validd then
		local dmg = 40
		Driver:TakeDamage( HitRes.Damage * dmg , Inflictor, Gun )
	end

	HitRes.Kill = false
	if HitRes.Damage >= Entity.ACF.Health then --Drivers will no longer survive seat destruction
		if validd then
			Driver:Kill()
		end
		HitRes.Kill = true
	else
		Entity.ACF.Health = Entity.ACF.Health - HitRes.Damage
		Entity.ACF.Armour = Entity.ACF.Armour * (0.5 + Entity.ACF.Health / Entity.ACF.MaxHealth / 2) --Simulating the plate weakening after a hit
	end

	return HitRes
end

function ACF_SquishyDamage(Entity, Energy, FrArea, _, Inflictor, Bone, Gun, Type)

    -- ═══════════════════════════════════════════════════════════════════════
    -- FRAGMENT-SPECIFIC DAMAGE MODEL
    -- Fragments wound via energy transfer, not RHA penetration
    -- ═══════════════════════════════════════════════════════════════════════
    if Type == "Frag" then
        -- Get fragment hit count from Energy table
        local hits = 1
        if istable(Energy) and Energy.FragHit then
            hits = math.max(Energy.FragHit, 0.1)
        end

        -- Energy.Kinetic is in kJ, convert to Joules
        local keJ = math.max((Energy.Kinetic or 0) * 1000, 0)

        -- Joules to HP conversion
        -- 10 J/HP makes 4 hits × 230J ≈ 92 damage (nearly always fatal at 5m)
        local JPerHP = 10

        -- Hitgroup multipliers (Bone values for players)
        local hgMul = 1.0
        local hgName = "body"
        if Bone == 1 then
            hgMul = 3.0  -- headshot
            hgName = "head"
        elseif Bone == 0 or Bone == 2 or Bone == 3 then
            hgMul = 1.0  -- torso (default)
            hgName = "torso"
        elseif Bone == 4 or Bone == 5 then
            hgMul = 0.4  -- arms (non-vital)
            hgName = "arm"
        elseif Bone == 6 or Bone == 7 then
            hgMul = 0.5  -- legs (can bleed out but less immediately fatal)
            hgName = "leg"
        end

        -- Player armor reduces fragment damage
        local armorMul = 1.0
        if Entity:IsPlayer() then
            local armor = Entity:Armor() or 0
            -- Armor 100 = ~60% reduction to protected areas
            local protection = math.Clamp(armor / 100, 0, 1) * 0.6

            -- Torso/head get full armor benefit, limbs less
            local coverage = 0.9
            if Bone == 4 or Bone == 5 or Bone == 6 or Bone == 7 then
                coverage = 0.3
            end

            armorMul = 1 - (protection * coverage)
        end

        -- Calculate damage
        local dmgPerFrag = keJ / JPerHP
        local totalDamage = dmgPerFrag * hits * hgMul * armorMul

        -- Debug output
        print(string.format("[FRAG DMG] %.1f hits × %.0fJ = %.0fJ total → %.1f HP (%s, armor %.0f%%)",
            hits,
            keJ,
            keJ * hits,
            totalDamage,
            hgName,
            (1 - armorMul) * 100))

        -- Apply damage
        Entity:TakeDamage(totalDamage, Inflictor, Gun)

        -- Return HitRes (Kill=false so ACF_HE doesn't try to ACF_HEKill players)
        return { Damage = totalDamage, Overkill = 0, Loss = 0, Kill = false }
    end

    -- ═══════════════════════════════════════════════════════════════════════
    -- ORIGINAL SQUISHY DAMAGE (for bullets, spall, etc.)
    -- ═══════════════════════════════════════════════════════════════════════

    local Mass = Entity:GetPhysicsObject():GetMass()
    local area = math.max(FrArea or 0, 0.01)
    local MaxPen = ((Energy.Penetration or 0) / area) * ACF.KEtoRHA
    local Penetration = MaxPen
    local MaxHealth = Entity:GetMaxHealth()
    local MassRatio = Mass / 90
    local HitRes = {}
    local Damage = 0
    local BoneArmor = 0

    local BodyArmor = 0
    local IsPly = Entity:IsPlayer()

    if IsPly then
        BodyArmor = 0.5 * (1 + Entity:Armor() / 100)
    end

    local FleshThickness = 5 * MassRatio

    local caliber = 20 * (FrArea ^ (1 / ACF.PenAreaMod) / 3.1416) ^ 0.5
    local BaseDamage = caliber * (4 + 0.1 * caliber)

    if Bone then
        if Bone == 1 then
            BoneArmor = MassRatio * 3.6

            if IsPly and Entity:Armor() > 75 then
                BoneArmor = BoneArmor + BodyArmor
            end

            if Penetration > BoneArmor then
                Penetration = Penetration - BoneArmor
                Penetration = math.min(Penetration / FleshThickness, 1)
                Damage = Penetration * BaseDamage * 2.5
            else
                Penetration = 0
            end

        elseif Bone == 0 or Bone == 2 or Bone == 3 then
            BoneArmor = MassRatio * 2
            BoneArmor = BoneArmor + BodyArmor

            if Penetration > BoneArmor then
                Penetration = Penetration - BoneArmor
                Penetration = math.min(Penetration / FleshThickness, 1)
                Damage = Penetration * BaseDamage
            else
                Penetration = 0
            end

        elseif Bone == 4 or Bone == 5 then
            BoneArmor = 0

            if IsPly and Entity:Armor() > 50 then
                BoneArmor = BoneArmor + BodyArmor / 4
            end

            if Penetration > BoneArmor then
                Penetration = Penetration - BoneArmor
                Penetration = math.min(Penetration / FleshThickness, 1)
                Damage = math.min(Penetration * BaseDamage * 0.5, MaxHealth * 0.2)
            else
                Penetration = 0
            end

        elseif Bone == 6 or Bone == 7 then
            BoneArmor = MassRatio * 0

            if IsPly and Entity:Armor() > 50 then
                BoneArmor = BoneArmor + BodyArmor / 4
            end

            if Penetration > BoneArmor then
                Penetration = Penetration - BoneArmor
                Penetration = math.min(Penetration / FleshThickness, 1)
                Damage = math.min(Penetration * BaseDamage * 0.7, MaxHealth * 0.3)
            else
                Penetration = 0
            end

        elseif Bone == 10 then
            BoneArmor = 0

            if Penetration > BoneArmor then
                Penetration = Penetration - BoneArmor
                Penetration = math.min(Penetration / FleshThickness, 1)
                Damage = math.min(Penetration * BaseDamage * 0.7, MaxHealth * 0.1)
            else
                Penetration = 0
            end

        else
            BoneArmor = MassRatio * 2
            BoneArmor = BoneArmor + BodyArmor

            if Penetration > BoneArmor then
                Penetration = Penetration - BoneArmor
                Penetration = math.min(Penetration / FleshThickness, 1)
                Damage = Penetration * BaseDamage
            else
                Penetration = 0
            end
        end
    else
        BoneArmor = MassRatio * 2
        BoneArmor = BoneArmor + BodyArmor

        if Penetration > BoneArmor then
            Penetration = Penetration - BoneArmor
            Penetration = math.min(Penetration / FleshThickness, 1)
            Damage = Penetration * BaseDamage
        else
            Penetration = 0
        end
    end

    local EnergyAbsorbed = Penetration * (Energy.Kinetic or 0)
    Damage = Damage + EnergyAbsorbed

    Entity:TakeDamage(Damage, Inflictor, Gun)
    HitRes.Kill = false

    local Target = {
        ACF = {
            Armour = BoneArmor + FleshThickness
        }
    }

    HitRes = ACF_CalcDamage(Target, Energy, FrArea, 0, Type)

    return HitRes
end

----------------------------------------------------------
-- Returns a table of all physically connected entities
-- ignoring ents attached by only nocollides
----------------------------------------------------------
function ACF_GetAllPhysicalConstraints( ent, ResultTable )

	ResultTable = ResultTable or {}

	if not IsValid( ent ) then return end
	if ResultTable[ ent ] then return end

	ResultTable[ ent ] = ent

	local ConTable = constraint.GetTable( ent )

	for _, con in ipairs( ConTable ) do

		-- skip shit that is attached by a nocollide
		if con.Type ~= "NoCollide" then
			for _, Ent in pairs( con.Entity ) do
				ACF_GetAllPhysicalConstraints( Ent.Entity, ResultTable )
			end
		end

	end

	return ResultTable

end

-- for those extra sneaky bastards
function ACF_GetAllChildren( ent, ResultTable )

	--if not ent.GetChildren then return end  --shouldn't need to check anymore, built into glua now

	ResultTable = ResultTable or {}

	if not IsValid( ent ) then return end
	if ResultTable[ ent ] then return end

	ResultTable[ ent ] = ent

	local ChildTable = ent:GetChildren()

	for _, v in pairs( ChildTable ) do

		ACF_GetAllChildren( v, ResultTable )

	end

	return ResultTable

end

-- returns any wheels linked to this or child gearboxes
function ACF_GetLinkedWheels( MobilityEnt )
	if not IsValid( MobilityEnt ) then return {} end

	local ToCheck = {}
	local Checked = {}
	local Wheels  = {}

	local links = MobilityEnt.GearLink or MobilityEnt.WheelLink -- handling for usage on engine or gearbox

	--print('total links: ' .. #links)
	--print(MobilityEnt:GetClass())

	for _, link in pairs( links ) do
		--print(link.Ent:GetClass())
		table.insert(ToCheck, link.Ent)
	end

	--print("max checks: " .. #ToCheck)

	--print('total ents to check: ' .. #ToCheck)

	-- use a stack to traverse the link tree looking for wheels at the end
	while #ToCheck > 0 do

		local Ent = table.remove(ToCheck,#ToCheck)

		if IsValid(Ent) then

			if Ent:GetClass() == "acf_gearbox" then

				Checked[Ent:EntIndex()] = true

				for _, v in pairs( Ent.WheelLink ) do

					if IsValid(v.Ent) and not Checked[v.Ent:EntIndex()] then
						table.insert(ToCheck, v.Ent)
					else
						v.Notvalid = true
					end


				end
			else
				Wheels[Ent] = Ent -- indexing it same as ACF_GetAllPhysicalConstraints, for easy merge.  whoever indexed by entity in that function, uuuuuuggghhhhh
			end
		end
	end

	--print('Wheels found: ' .. table.Count(Wheels))

	return Wheels
end

--[[----------------------------------------------------------------------
	A variation of the CreateKeyframeRope( ... ) for usage on ACE
	This one is more simple than the original function.
	Creates a rope without any constraint
------------------------------------------------------------------------]]
function ACE_CreateLinkRope( Pos, Ent1, LPos1, Ent2, LPos2 )

	local rope = ents.Create( "keyframe_rope" )
	rope:SetPos( Pos )
	rope:SetKeyValue( "Width", 1 )
	rope:SetKeyValue( "Type", 2 )

	rope:SetKeyValue( "RopeMaterial", "cable/cable2" )

	-- Attachment point 1
	rope:SetEntity( "StartEntity", Ent1 )
	rope:SetKeyValue( "StartOffset", tostring( LPos1 ) )
	rope:SetKeyValue( "StartBone", 0 )

	-- Attachment point 2
	rope:SetEntity( "EndEntity", Ent2 )
	rope:SetKeyValue( "EndOffset", tostring( LPos2 ) )
	rope:SetKeyValue( "EndBone", 0 )

	rope:Spawn()
	rope:Activate()

	-- Delete the rope if the attachments get killed
	Ent1:DeleteOnRemove( rope )
	Ent2:DeleteOnRemove( rope )

	return rope

end

--[[----------------------------------------------------------------------
	A variation of the CreateKeyframeRope( ... ) for visualizing safezones
	This one is more simple than the original function.
	Creates a rope without any constraint
------------------------------------------------------------------------]]
function ACE_CreateSZRope( Pos, Ent, LPos1, LPos2 )

	local rope = ents.Create( "keyframe_rope" )
	rope:SetPos( Pos )
	rope:SetKeyValue( "Width", 15 )
	rope:SetKeyValue( "Type", 2 )

	rope:SetKeyValue( "RopeMaterial", "cable/physbeam" )

	-- Attachment point 1
	rope:SetEntity( "StartEntity", Ent )
	rope:SetKeyValue( "StartOffset", tostring( LPos1 ) )
	rope:SetKeyValue( "StartBone", 0 )

	-- Attachment point 2
	rope:SetEntity( "EndEntity", Ent )
	rope:SetKeyValue( "EndOffset", tostring( LPos2 ) )
	rope:SetKeyValue( "EndBone", 0 )

	rope:Spawn()
	rope:Activate()

	-- Delete the rope if the attachments get killed
	Ent:DeleteOnRemove( rope )

	return rope

end

function ACE_VisualizeSZ(Point1, Point2)

	local SZEnt = ents.Create("prop_physics")
	if SZEnt:IsValid() then
		SZEnt:SetModel( "models/jaanus/wiretool/wiretool_pixel_med.mdl" )
		SZEnt:Spawn()
		SZEnt:SetColor( Color(255,0,0) )

		local phys = SZEnt:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion( false )
		end
		SZEnt:SetNotSolid( true )
	end

	--Upper Rectangle
	local PT1 = Vector(Point1.x,Point1.y,Point2.z) + Vector(0,0,2)
	local PT2 = Vector(Point2.x,Point1.y,Point2.z) + Vector(0,0,2)
	local LPT1 = SZEnt:WorldToLocal(PT1)
	local LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point1.y,Point2.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point2.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point2.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	--Lower Rectangle
	PT1 = Vector(Point1.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )
	--4 corners
	PT1 = Vector(Point2.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point1.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

--[[
	PT1 = Vector(Point1.x,Point1.y,Point1.z)
	PT2 = Vector(Point2.x,Point1.y,Point1.z)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE_CreateSZRope( PT1, SZEnt, LPT1, LPT2 )
]]--

	return SZEnt
end

--[[----------------------------------------------------------------------
	This function will look for the driver/operator of a gun/rack based
	from the used gun inputs when firing.
	Meant for determining if the driver seat is legal.
------------------------------------------------------------------------]]
local WireTable = {
	gmod_wire_adv_pod = true,
	gmod_wire_pod = true,
	gmod_wire_keyboard = true,
	gmod_wire_joystick = true,
	gmod_wire_joystick_multi = true
}

function ACE_GetWeaponUser( Weapon, inp )
	if not IsValid(inp) then return end

	if inp:GetClass() == "gmod_wire_adv_pod" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_pod" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_keyboard" then
		if IsValid(inp.ply) then
			return inp.ply
		end
	elseif inp:GetClass() == "gmod_wire_joystick" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_joystick_multi" then
		if IsValid(inp.Pod) then
			return inp.Pod:GetDriver()
		end
	elseif inp:GetClass() == "gmod_wire_expression2" then
		if inp.Inputs.Fire then
			return ACE_GetWeaponUser( Weapon, inp.Inputs.Fire.Src )
		elseif inp.Inputs.Shoot then
			return ACE_GetWeaponUser( Weapon, inp.Inputs.Shoot.Src )
		elseif inp.Inputs then
			for _,v in pairs(inp.Inputs) do
				if IsValid(v.Src) and WireTable[v.Src:GetClass()] then
					return ACE_GetWeaponUser( Weapon, v.Src )
				end
			end
		end
	end

	return inp:CPPIGetOwner()
end

util.AddNetworkString( "colorchatmessage" )

	--Sends a colored message to a specified player.
function chatMessagePly( ply , message, color) --

	net.Start( "colorchatmessage" )
		net.WriteColor( color or Color( 255, 255, 255 ) ) --Must go first
		net.WriteString( message )
	net.Send( ply )

end


function chatMessageGlobal( message, color) --Like chatMessagePly but it just goes to everyone.

	print(message)
	net.Start( "colorchatmessage" )
		net.WriteColor( color or Color( 255, 255, 255 ) ) --Must go first
		net.WriteString( message )
	net.Broadcast()

end


--[[
function chatMessageGlobal( message, color) --Like chatMessagePly but it just goes to everyone.

	print(message)
	for _, ply in ipairs( player.GetAll() ) do --Terrible. But you'd think the above would work.
		chatMessagePly( ply , message, color)
	end
end
]]--