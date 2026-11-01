--visual concept: Here's where should be every acf function

do
	local SendDelay = 1 -- in miliseconds
	local RenderProps = {
		Entities = {},
		Clock = 0
	}
	function ACE.UpdateVisualHealth( Entity )
		if not Entity.ACE.OnRenderQueue then
			table.insert(RenderProps.Entities, Entity )
			Entity.ACE.OnRenderQueue = true
		end
	end
	function ACE.SendVisualDamage()

		local Time = CurTime()

		if next(RenderProps.Entities) and Time >= RenderProps.Clock then

			for k, Ent in ipairs(RenderProps.Entities) do
				if not Ent:IsValid() then
					table.remove( RenderProps.Entities, k )
				end
			end

			local Entity = RenderProps.Entities[1]
			if IsValid(Entity) then
				net.Start("ACE_RenderDamage", true) -- i dont care if the message is not received under extreme cases since its simply a visual effect only.
					net.WriteUInt(Entity:EntIndex(), 13)
					net.WriteFloat(Entity.ACE.MaxHealth)
					net.WriteFloat(Entity.ACE.Health)
				net.Broadcast()

				Entity.ACE.OnRenderQueue = nil
			end
			table.remove( RenderProps.Entities, 1 )

			RenderProps.Clock = Time + (SendDelay / 1000)
		end
	end
	hook.Add("Think","ACE_RenderPropDamage", ACE.SendVisualDamage )
end

--Creates or updates the ACF entity data in a passive way. Meaning this entity wont be updated unless it really requires it (like a shot, damage, looking it using armor tool, etc)
function ACE.Activate( Entity , Recalc )

	--Density of steel = 7.8g cm3 so 7.8kg for a 1mx1m plate 1m thick
	if Entity.SpecialHealth then
		Entity:ACF_Activate( Recalc )
		return
	end

	ACE.GetEntityState(Entity, true)

	local Count
	local PhysObj = Entity:GetPhysicsObject()
	Entity.ACE.PhysObj = PhysObj

	if PhysObj:GetMesh() then Count = #PhysObj:GetMesh() end
	if PhysObj:IsValid() and Count and Count > 100 then

		if not Entity.ACE.Area then
			Entity.ACE.Area = (PhysObj:GetSurfaceArea() * 6.45) * 0.52505066107
		end
	else
		local Size = Entity.OBBMaxs(Entity) - Entity.OBBMins(Entity)
		if not Entity.ACE.Area then
			Entity.ACE.Area = ((Size.x * Size.y) + (Size.x * Size.z) + (Size.y * Size.z)) * 6.45
		end
	end

	-- Setting Armor properties for the first time (or reuse old data if present)
	Entity.ACE.Ductility	= Entity.ACE.Ductility or 0
	Entity.ACE.Material	= not isstring(Entity.ACE.Material) and ACE.BackCompMat[Entity.ACE.Material] or Entity.ACE.Material or "RHA"

	local Area	= Entity.ACE.Area
	local Ductility = math.Clamp( Entity.ACE.Ductility, -0.8, 0.8 )

	local Mat	= Entity.ACE.Material or "RHA"
	local MatData	= ACE.GetMaterialData( Mat )

	local massMod	= MatData.massMod

	local Armour	= ACE.CalcArmor( Area, Ductility, Entity:GetPhysicsObject():GetMass() / massMod ) -- So we get the equivalent thickness of that prop in mm if all its weight was a steel plate
	local Health	= ACE.CalcHealth( Area, Ductility, Armour ) -- Health uses area and ductility; Armour remains an API-compatible argument

	local Percent	= 1

	if Recalc and Entity.ACE.Health and Entity.ACE.MaxHealth then
		Percent = Entity.ACE.Health / Entity.ACE.MaxHealth
	end

	Entity.ACE.Health	= Health * Percent
	Entity.ACE.MaxHealth	= Health
	Entity.ACE.Armour = Armour * (0.5 + Percent / 2)
	Entity.ACE.MaxArmour	= Armour * ACE.ArmorMod
	Entity.ACE.Type		= nil
	Entity.ACE.Mass		= PhysObj:GetMass()

	if Entity:IsPlayer() or Entity:IsNPC() then
		Entity.ACE.Type = "Squishy"
	elseif Entity:IsVehicle() then
		Entity.ACE.Type = "Vehicle"
	else
		Entity.ACE.Type = "Prop"
	end

	if Entity:GetClass() == "func_breakable" then
		Entity.DamageOwner = true
	end
end

local IGNORED_CLASSES = {
	gmod_ghost = true,
	prop_ragdoll = true,
	ace_debris = true,
	sent_prop2mesh = true,
}

function ACE.Check( Entity )

	if not IsValid(Entity) then return false end

	local physobj = Entity:GetPhysicsObject()
	if not ( physobj:IsValid() and (physobj:GetMass() or 0) > 0 and not Entity:IsWorld() and not Entity:IsWeapon() ) then return false end

	local Class = Entity:GetClass()
	if IGNORED_CLASSES[Class] or (ACE.TraceFilter and ACE.TraceFilter[Class]) or ( Class ~= "func_breakable" and string.find( Class , "func_" )) then return false end
	if Entity.Exploding then return false end

	if not Entity.ACE or (Entity.ACE and isnumber(Entity.ACE.Material)) then
		ACE.Activate( Entity )
	elseif Entity.ACE.Mass ~= physobj:GetMass() or (not IsValid(Entity.ACE.PhysObj) or Entity.ACE.PhysObj ~= physobj) then
		ACE.Activate( Entity , true )
	end

	return Entity.ACE.Type
end

function ACE.Damage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun, Type, HitPos, Dir )

	local Activated = ACE.Check( Entity )
	local CanDo = hook.Run("ACE_BulletDamage", Activated, Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun )
	if CanDo == false or Activated == false then -- above (default) hook does nothing with activated. Excludes godded players.
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	local oldACFTbl = table.Copy( Entity.ACE or {} )
	local hitRes = nil

	if Entity.SpecialDamage then

		hitRes = Entity:ACF_OnDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Type )

	elseif Activated == "Prop" then

		hitRes = ACE.PropDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone , Type)

	elseif Activated == "Vehicle" then

		hitRes = ACE.VehicleDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun , Type)

	elseif Activated == "Squishy" then

		hitRes = ACE.SquishyDamage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun , Type, HitPos, Dir)

	end

	hook.Run("ACE_OnDamage", Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun, Type, hitRes, oldACFTbl)
	hook.Run("ACEOnDamage", Entity, Energy, FrArea, Angle, Inflictor, Bone, Gun, Type, hitRes, oldACFTbl)
	return hitRes

end

local function canDamagePlayer(Target, Attacker)
	if not (IsValid(Target) and Target:IsPlayer()) then return true end
	if IsValid(Attacker) and Attacker == Target then return true end
	if Target:HasGodMode() then return false end

	local canTakeDamage = hook.Run("PlayerShouldTakeDamage", Target, Attacker)

	return canTakeDamage ~= false
end



function ACE.CalcDamage( Entity , Energy , FrArea , Angle , Type) --y=-5/16x + b

	local HitRes			= {}

	local armor			= Entity.ACE.Armour																						-- Armor
	local losArmor		= armor / math.abs( math.cos(math.rad(Angle)) ^ ACE.SlopeEffectFactor )									-- LOS Armor
	local losArmorHealth = armor ^ 1.1 * (3 + math.min(1 / math.abs(math.cos(math.rad(Angle)) ^ ACE.SlopeEffectFactor), 2.8) * 0.5)	-- Bc people had to abuse armor angling, FML

	local Mat			= Entity.ACE.Material or "RHA"	--very important thing
	local MatData		= ACE.GetMaterialData( Mat )

	local damageMult		= 1

	if Type == "AP" then
		damageMult = ACE.APDamageMult
	elseif Type == "Spall" then
		damageMult = ACE.SpallDamageMult
	elseif Type == "APHE" then
		damageMult = ACE.APHEDamageMult
	elseif Type == "APDS" then
		damageMult = ACE.APDSDamageMult
	elseif Type == "APFSDS" then
		damageMult = ACE.APDSDamageMult
	elseif Type == "HVAP" then
		damageMult = ACE.HVAPDamageMult
	elseif Type == "FL" then
		damageMult = ACE.FLDamageMult
	elseif Type == "HEAT" then
		damageMult = ACE.HEATDamageMult
	elseif Type == "HE" then
		damageMult = ACE.HEDamageMult
	elseif Type == "HESH" then
		damageMult = ACE.HESHDamageMult
	elseif Type == "HP" then
		damageMult = ACE.HPDamageMult
	end

	-- RHA Penetration
	local maxPenetration = ACE.CalcPenetration(Energy, FrArea)

	-- Projectile caliber. Messy, function signature
	local caliber = 20 * (FrArea ^ (1 / ACE.PenAreaMod) / 3.1416) ^ 0.5

	--Nifty shell information debugging.
	--print("Type: "..(Type or "Nil"))
	--print("Penetration: " .. math.Round(maxPenetration,3) .. "mm")
	--print("Caliber: "..math.Round(caliber,3).."mm")

	-- ERA has its own kinetic detonation and depleted-tile rules; let its resolver see every hit.
	if MatData.id ~= "ERA" and ACE.IsKineticDamageType(Type) then
		local curve = tonumber(MatData.curve) or 1
		local effectiveness = tonumber(MatData.effectiveness) or 1
		local requiredPenetration = (losArmor ^ curve) * effectiveness
		local energyRatio = maxPenetration / requiredPenetration
		local threshold = tonumber(ACE.KineticDamageThreshold) or 0.65
		if threshold ~= threshold or threshold < 0 or threshold > 1 then threshold = 0.65 end

		local validRequirement = isnumber(requiredPenetration) and requiredPenetration == requiredPenetration
			and requiredPenetration ~= math.huge and requiredPenetration ~= -math.huge and requiredPenetration > 0
		local validRatio = isnumber(energyRatio) and energyRatio == energyRatio
			and energyRatio ~= math.huge and energyRatio ~= -math.huge

		if validRequirement and validRatio and energyRatio < threshold then
			return { Damage = 0, Overkill = 0, Loss = 1, KineticThresholdFailed = true }
		end
	end

	local armorResolution = MatData["ArmorResolution"]
	HitRes = armorResolution( Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)

	return HitRes
end

-- replaced with _ due to lack of use: Inflictor, Bone
function ACE.PropDamage( Entity , Energy , FrArea , Angle , _, _, Type)

	local HitRes = ACE.CalcDamage( Entity , Energy , FrArea , Angle  , Type)
	if HitRes.KineticThresholdFailed then
		HitRes.Kill = false
		return HitRes
	end

	HitRes.Kill = false

	local caliber = 20 * (FrArea ^ (1 / ACE.PenAreaMod) / 3.1416) ^ 0.5
	local BaseDamage = caliber * (4 + 0.1 * caliber)

	Entity:TakeDamage(BaseDamage * 15) --Felt about right. Allows destroying physically destructible props.
	if HitRes.Damage >= Entity.ACE.Health then
		HitRes.Kill = true
	else

		--In case of HitRes becomes NAN. That means theres no damage, so leave it as 0
		if HitRes.Damage ~= HitRes.Damage then HitRes.Damage = 0 end

		Entity.ACE.Health = Entity.ACE.Health - HitRes.Damage
		Entity.ACE.Armour = Entity.ACE.MaxArmour * (0.5 + Entity.ACE.Health / Entity.ACE.MaxHealth / 2) --Simulating the plate weakening after a hit

		if Entity.ACE.PrHealth then
			ACE.UpdateVisualHealth(Entity)
		end
		Entity.ACE.PrHealth = Entity.ACE.Health
	end

	return HitRes

end

-- replaced with _ due to lack of use: Bone
function ACE.VehicleDamage(Entity, Energy, FrArea, Angle, Inflictor, _, Gun, Type)

	--We create a dummy table to pass armour values to the calc function
	local Target = {
		ACE = {
			Armour = 2 --8
		}
	}

	local HitRes = ACE.CalcDamage( Target , Energy , FrArea , Angle  , Type)

	local Driver = Entity:GetDriver()
	local canDamageDriver = IsValid(Driver) and canDamagePlayer(Driver, Inflictor)

	if canDamageDriver then
		-- The seat's own armor shields the driver, resolved as a plate of its material and thickness. A bullet it
		-- stops still passes on blunt trauma; one it lets through goes on into the driver and their body armor.
		local Material = Entity.ACE.Material or "RHA"
		local _, Post = ACE.ResolveArmorLayer(Driver, Material, Entity.ACE.Armour or 0, Energy, FrArea, Angle, Type)

		if Post.Continue then
			local Left = { Kinetic = Post.RemainingKinetic, Penetration = Post.RemainingPenetration, Momentum = (Energy.Momentum or 0) * Post.Remaining }
			ACE.FleshDamage(Driver, Left, FrArea, Inflictor, HITGROUP_CHEST, Gun, nil, nil, Type)
		else
			ACE.FleshBlunt(Driver, (Energy.Kinetic or 0) * 1000 * (ACE.GetMaterialData(Material).BluntTransfer or 0.15), HITGROUP_CHEST, Inflictor, Gun)
		end
	end

	if HitRes.KineticThresholdFailed then
		HitRes.Kill = false
		return HitRes
	end

	--In case of HitRes becomes NAN. That means theres no damage, so leave it as 0
	if HitRes.Damage ~= HitRes.Damage then HitRes.Damage = 0 end

	HitRes.Kill = false
	if HitRes.Damage >= Entity.ACE.Health then --Drivers will no longer survive seat destruction
		if canDamageDriver and IsValid(Driver) then
			Driver:Kill()
		end
		HitRes.Kill = true
	else
		Entity.ACE.Health = Entity.ACE.Health - HitRes.Damage
		Entity.ACE.Armour = Entity.ACE.Armour * (0.5 + Entity.ACE.Health / Entity.ACE.MaxHealth / 2) --Simulating the plate weakening after a hit
	end

	return HitRes
end

-- The damage itself lives in sv_ace_squishy_damage.lua. This keeps the bullet's exit working.
function ACE.SquishyDamage(Entity, Energy, FrArea, _, Inflictor, Bone, Gun, Type, HitPos, Dir)
	if Entity:IsPlayer() and not canDamagePlayer(Entity, Inflictor) then
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	local BodyThickness, Layer = ACE.FleshDamage(Entity, Energy, FrArea, Inflictor, Bone or HITGROUP_GENERIC, Gun, HitPos, Dir, Type)

	-- Body armor stopped the bullet. It ricochets off the armor's own surface, not the hitbox; armor whose surface
	-- isn't known doesn't ricochet it.
	if not BodyThickness then
		if Layer and Layer.Normal then
			return { Damage = 0, Overkill = 0, Loss = 1, Kill = false, HitNormal = Layer.Normal, RicochetArmour = Layer.Armour }
		end

		return { Damage = 0, Overkill = 0, Loss = 1, Kill = false, NoRicochet = true }
	end

	--We create a dummy table to pass armour values to the calc function
	local Target = {
		ACE = {
			Armour = BodyThickness
		}
	}

	local HitRes = ACE.CalcDamage(Target, Energy, FrArea, 0, Type)
	HitRes.Kill = false
	HitRes.NoRicochet = true -- Bullets don't glance off flesh

	return HitRes
end

----------------------------------------------------------
-- Returns a table of all physically connected entities
-- ignoring ents attached by only nocollides
----------------------------------------------------------
function ACE.GetAllPhysicalConstraints( ent, ResultTable )

	ResultTable = ResultTable or {}

	if not IsValid( ent ) then return end
	if ResultTable[ ent ] then return end

	ResultTable[ ent ] = ent

	local ConTable = constraint.GetTable( ent )

	for _, con in ipairs( ConTable ) do

		-- skip shit that is attached by a nocollide
		if con.Type ~= "NoCollide" then
			for _, Ent in pairs( con.Entity ) do
				ACE.GetAllPhysicalConstraints( Ent.Entity, ResultTable )
			end
		end

	end

	return ResultTable

end

-- for those extra sneaky bastards
function ACE.GetAllChildren( ent, ResultTable )

	--if not ent.GetChildren then return end  --shouldn't need to check anymore, built into glua now

	ResultTable = ResultTable or {}

	if not IsValid( ent ) then return end
	if ResultTable[ ent ] then return end

	ResultTable[ ent ] = ent

	local ChildTable = ent:GetChildren()

	for _, v in pairs( ChildTable ) do

		ACE.GetAllChildren( v, ResultTable )

	end

	return ResultTable

end

-- returns any wheels linked to this or child gearboxes
function ACE.GetLinkedWheels( MobilityEnt )
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
				Wheels[Ent] = Ent -- indexing it same as ACE_GetAllPhysicalConstraints, for easy merge.  whoever indexed by entity in that function, uuuuuuggghhhhh
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
function ACE.CreateLinkRope( Pos, Ent1, LPos1, Ent2, LPos2 )

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
function ACE.CreateSZRope( Pos, Ent, LPos1, LPos2 )

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

function ACE.VisualizeSZ(Point1, Point2)

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
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point1.y,Point2.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point2.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point2.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	--Lower Rectangle
	PT1 = Vector(Point1.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point1.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )
	--4 corners
	PT1 = Vector(Point2.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point1.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point1.x,Point2.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point1.x,Point2.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

	PT1 = Vector(Point2.x,Point1.y,Point1.z) + Vector(0,0,2)
	PT2 = Vector(Point2.x,Point1.y,Point2.z) + Vector(0,0,2)
	LPT1 = SZEnt:WorldToLocal(PT1)
	LPT2 = SZEnt:WorldToLocal(PT2)
	ACE.CreateSZRope( PT1, SZEnt, LPT1, LPT2 )

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

function ACE.GetWeaponUser( Weapon, inp )
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
			return ACE.GetWeaponUser( Weapon, inp.Inputs.Fire.Src )
		elseif inp.Inputs.Shoot then
			return ACE.GetWeaponUser( Weapon, inp.Inputs.Shoot.Src )
		elseif inp.Inputs then
			for _,v in pairs(inp.Inputs) do
				if IsValid(v.Src) and WireTable[v.Src:GetClass()] then
					return ACE.GetWeaponUser( Weapon, v.Src )
				end
			end
		end
	end

	return inp:CPPIGetOwner()
end

util.AddNetworkString( "ACE_ColorChatMessage" )

	--Sends a colored message to a specified player.
function ACE.ChatMessagePly( ply , message, color) --

	net.Start( "ACE_ColorChatMessage" )
		net.WriteColor( color or Color( 255, 255, 255 ) ) --Must go first
		net.WriteString( message )
	net.Send( ply )

end


function ACE.ChatMessageGlobal( message, color) --Like ACE_ChatMessagePly but it just goes to everyone.

	print(message)
	net.Start( "ACE_ColorChatMessage" )
		net.WriteColor( color or Color( 255, 255, 255 ) ) --Must go first
		net.WriteString( message )
	net.Broadcast()

end


--[[
function ACE_ChatMessageGlobal( message, color) --Like ACE_ChatMessagePly but it just goes to everyone.

	print(message)
	for _, ply in ipairs( player.GetAll() ) do --Terrible. But you'd think the above would work.
		ACE_ChatMessagePly( ply , message, color)
	end
end
]]--
