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

--[[----------------------------------------------------------------------------
	Function:
		ACF_HE
	Arguments:
		HitPos	- detonation center,
		FillerMass  - mass of TNT being detonated in KG
		FragMass	- mass of the round casing for fragmentation purposes
		Inflictor	- owner of said TNT
		NoOcc	- table with entities to ignore
		Gun		- gun entity from which round is fired
	Purpose:
		Handles ACF explosions
------------------------------------------------------------------------------]]

local PI = math.pi

function ACF_HE( Hitpos , _ , FillerMass, FragMass, Inflictor, NoOcc, Gun, BlastPenMul )

	local Radius       = ACE_CalculateHERadius(FillerMass) -- Scalling law found on the net, based on 1PSI overpressure from 1 kg of TNT at 15m.
	local MaxSphere    = 4 * PI * (Radius * 2.54) ^ 2 -- Surface Area of the sphere at maximum radius
	local Power        = FillerMass * ACF.HEPower -- Power in KiloJoules of the filler mass of  TNT
	local Amp          = math.min(Power / 2000, 50)

	local Fragments    = math.max(math.floor((FillerMass / FragMass) * ACF.HEFrag), 2)
	local FragWeight   = FragMass / Fragments
	local FragVel      = ( Power * 50000 / FragWeight / Fragments ) ^ 0.5
	local FragArea     = (FragWeight / 7.8) ^ 0.33

	local OccFilter	= istable(NoOcc) and NoOcc or { NoOcc }
	local LoopKill	= true

	local FRTargets	= ACF_HEFind( Hitpos, Radius * ACF.HEFragRadiusMul )		-- Will give tiny HE just a pinch of radius to help it hit the player

	--Generates a list of critical entities inside the blast radius
	local HEBP = Power * (BlastPenMul or 1)
	if HEBP > ACF.HEBlastPenMinPow then --About the HEpower of a 40mm autocannon.
		local RadSq = (Radius^2) / ACF.HEBlastPenRadiusMul --Used for square distance test

		local HEPen = HEBP / ACF.HEBlastPenetration
		--print("Blastpen: " .. HEPen)
		local Blast = {
			Penetration = HEPen
		}

		for _, ent in pairs( ACE.critEnts ) do
			local epos = ent:GetPos()
			local SqDist = Hitpos:DistToSqr( epos )
			if SqDist > RadSq then continue end --Perhaps a table storing positions would be faster?

			local LosArmor = ACE_LOSMultiTrace(Hitpos,epos, HEPen)
			--print("LosArmor: " .. LosArmor)

			local Dist = math.sqrt(SqDist)
			--print("DistPen: " .. Radius / 39.37)
			local penLoss = 1 - (Dist / Radius) ^ ACF.HEBlastPenLossExponent * ACF.HEBlastPenLossAtMaxDist
			--print("NewHEPen: " .. math.Round(HEPen * penLoss,2)) --ACF.HEBlastPenPenAtMaxDist

			if LosArmor < (HEPen * penLoss) then --Able to "penetrate". Directly damages the target entity.
				--print(ent:GetClass())
				--print("LosArmor: " .. LosArmor)
				--ACF_Damage( Entity , Energy , FrArea , Angle , Inflictor , Bone, Gun, Type )
				BlastRes = ACF_Damage ( ent  , Blast , 1 , 0 , Inflictor ,0 , Gun, "Frag" ) --Swapped from "HE" to "Frag" to prevent instantly cooking off fuel.

				if BlastRes and BlastRes.Kill then

					--Add the debris created to the ignore so we don't hit it in other rounds
					local Debris = ACF_HEKill( ent , VectorRand() , Power * 0.0001 , Hitpos )
					table.insert( OccFilter , Debris )

					LoopKill = true --look for fresh targets since we blew a hole somewhere
				end
			end

		end

	end

	while LoopKill and Power > 0 do

		LoopKill = false

		local PowerSpent    = 0
		local Damage        = {}
		local TotalArea     = 0

		for i,Tar in ipairs(FRTargets) do

			if not IsValid(Tar) then continue end
			if Power <= 0 or Tar.Exploding then continue end

			local Type = ACF_Check(Tar)
			if Type then

				local TargetPos = Tar:GetPos()
				local TargetCenter = Tar:WorldSpaceCenter()

				--Check if we have direct LOS with the victim prop. Laggiest part of HE
				TraceInit.start    = Hitpos
				TraceInit.endpos   = TargetCenter
				TraceInit.filter   = OccFilter

				util.TraceLine( TraceInit )

				--if above failed getting the target. Try again by nearest point instead.
				if not TraceRes.Hit then
					local Hitat = Tar:NearestPoint( Hitpos )

					--Done for dealing damage vs players and npcs
					if Type == "Squishy" then

						local hugenumber = 99999999999

						--Modified to attack the feet, center, or eyes, whichever is closest to the explosion
						--This is for scanning potential victims, damage goes later.
						local cldist = Hitpos:Distance( Hitat ) or hugenumber
						local Tpos
						local Tdis = hugenumber

						local Eyes = Tar:LookupAttachment("eyes")
						if Eyes then

							local Eyeat = Tar:GetAttachment( Eyes )
							if Eyeat then
								--Msg("Hitting Eyes\n")
								Tpos = Eyeat.Pos
								Tdis = Hitpos:Distance( Tpos ) or hugenumber
								if Tdis < cldist then
									Hitat = Tpos
									cldist = cldist
								end
							end
						end

						Tpos = TargetCenter
						Tdis = Hitpos:Distance( Tpos ) or hugenumber
						if Tdis < cldist then
							Hitat = Tpos
							cldist = cldist
						end
					end

					--if hitpos is inside of hitbox of the victim prop, nearest point will not work as intended
					if Hitat == Hitpos then Hitat = TargetPos end

					TraceInit.endpos	= Hitat + (Hitat-Hitpos):GetNormalized() * 100
					util.TraceHull( TraceInit )
				end

				--HE has direct view with the prop, so lets damage it
				if TraceRes.Hit and TraceRes.Entity == Tar then

					FRTargets[i]		= NULL  --Remove the thing we just hit from the table so we don't hit it again in the next round
					local Table		= {}

					Table.Ent		= Tar

					if ACE.CritEnts[Tar:GetClass()] then
						Table.LocalHitpos = WorldToLocal(Hitpos, Angle(0,0,0), TargetPos, Tar:GetAngles())
					end

					Table.Dist		= Hitpos:Distance(TargetPos)
					Table.Vec		= (TargetPos - Hitpos):GetNormalized()

					local Sphere		= math.max(4 * PI * (Table.Dist * 2.54 ) ^ 2,1) --Surface Area of the sphere at the range of that prop
					local AreaAdjusted  = Tar.ACF.Area

					--Project the Area of the prop to the Area of the shadow it projects at the explosion max radius
					Table.Area = math.min(AreaAdjusted / Sphere,0.5) * MaxSphere * ACF.HEFragRadiusMul --Don't forget to scale blast down by the frag adjustment factor.
					table.insert(Damage, Table) --Add it to the Damage table so we know to damage it once we tallied everything

					-- is it adding it too late?
					TotalArea = TotalArea + Table.Area

				end

			else
				FRTargets[i] = NULL	--Target was invalid, so let's ignore it
				table.insert( OccFilter , Tar ) -- updates the filter in TraceInit too
			end

		end

		--Now that we have the props to damage, apply it here
		for _, Table in ipairs(Damage) do

			local Tar              = Table.Ent
			local TargetPos        = Tar:GetPos()
			local Feathering       = (1-math.min(1,Table.Dist / Radius)) ^ ACF.HEFeatherExp
			local FRFeathering       = (1-math.min(1,Table.Dist / Radius / ACF.HEFragRadiusMul)) ^ ACF.HEFeatherExp
			local AreaFraction     = Table.Area / TotalArea
			local PowerFraction    = Power * AreaFraction  --How much of the total power goes to that prop
			local AreaAdjusted     = (Tar.ACF.Area / ACF.Threshold) * Feathering
			local FRAreaAdjusted     = (Tar.ACF.Area / ACF.Threshold) * FRFeathering

			--HE tends to pick some props where simply will not apply damage. So lets ignore it.
			if FRAreaAdjusted <= 0 then continue end

			local BlastRes
			local Blast = {
				Penetration = PowerFraction ^ ACF.HEBlastPen * AreaAdjusted
			}

			local FragRes
			local FragHit	= Fragments * AreaFraction
			FragVel	= math.max(FragVel - ( (Table.Dist / FragVel) * FragVel ^ 2 * FragWeight ^ 0.33 * ACF.HEFragDragFactor ) / ACF.DragDiv,0)
			local FragKE	= ACF_Kinetic( FragVel , FragWeight * FragHit, 1500 )

			--Why would this ever be below 0?
			if FragHit < 0 then
				if math.Rand(0,1) > FragHit then FragHit = 1 else FragHit = 0 end
			end

			-- erroneous HE penetration bug workaround; retries trace on crit ents after a short delay to ensure a hit.
			-- we only care about hits on critical ents, saves on processing power
			-- not going to re-use tables in the timer, shouldn't make too much difference

			-- Really required?

			if ACE.CritEnts[Tar:GetClass()] then

				timer.Simple(0.03, function()
					if not IsValid(Tar) then return end

					--recreate the hitpos and hitat, add slight jitter to hitpos and move it away some
					local NewHitpos = LocalToWorld(Table.LocalHitpos + Table.LocalHitpos:GetNormalized() * 3, Angle(math.random(),math.random(),math.random()), TargetPos, Tar:GetAngles())
					local NewHitat  = Tar:NearestPoint( NewHitpos )

					local Occlusion	= {
						start = NewHitpos,
						endpos = NewHitat + (NewHitat-NewHitpos):GetNormalized() * 100,
						filter = NoOcc,
					}
					local Occ	= util.TraceLine( Occlusion )

					if not Occ.Hit and NewHitpos ~= NewHitat then
						local NewHitat  = TargetPos
						Occlusion.endpos	= NewHitat + (NewHitat-NewHitpos):GetNormalized() * 100
						Occ = util.TraceLine( Occlusion )
					end

					if not (Occ.Hit and Occ.Entity:EntIndex() ~= Tar:EntIndex()) and not (not Occ.Hit and NewHitpos ~= NewHitat) then

						BlastRes = ACF_Damage ( Tar	, Blast  , AreaAdjusted , 0	, Inflictor , 0	, Gun , "HE" )
						FragRes = ACF_Damage ( Tar , FragKE , FragArea * FragHit , 0 , Inflictor , 0, Gun, "Frag" )

						if (BlastRes and BlastRes.Kill) or (FragRes and FragRes.Kill) then
							ACF_HEKill( Tar, (TargetPos - NewHitpos):GetNormalized(), PowerFraction , Hitpos)
						else
							ACF_KEShove(Tar, NewHitpos, (TargetPos - NewHitpos):GetNormalized(), PowerFraction * 1 * (GetConVar("acf_hepush"):GetFloat() or 1), Inflictor) --0.333
						end
					end
				end)

				--calculate damage that would be applied (without applying it), so HE deals correct damage to other props
				BlastRes = ACF_CalcDamage( Tar, Blast, AreaAdjusted, 0 )

			else

				BlastRes = ACF_Damage ( Tar  , Blast , AreaAdjusted , 0 , Inflictor ,0 , Gun, "HE" )
				FragRes = ACF_Damage ( Tar , FragKE , FragArea * FragHit , 0 , Inflictor , 0, Gun, "Frag" )

				if (BlastRes and BlastRes.Kill) or (FragRes and FragRes.Kill) then

					--Add the debris created to the ignore so we don't hit it in other rounds
					local Debris = ACF_HEKill( Tar , Table.Vec , PowerFraction , Hitpos )
					table.insert( OccFilter , Debris )

					LoopKill = true --look for fresh targets since we blew a hole somewhere

				else

					--Assuming about 1/30th of the explosive energy goes to propelling the target prop (Power in KJ * 1000 to get J then divided by 33)
					ACF_KEShove(Tar, Hitpos, Table.Vec, PowerFraction * 5 * (GetConVar("acf_hepush"):GetFloat() or 1), Inflictor)

				end
			end

			PowerSpent = PowerSpent + PowerFraction * BlastRes.Loss / 2--Removing the energy spent killing props


		end

		Power = math.max(Power - PowerSpent,0)
	end

		--There was an attempt
		--There has got to be a better way. Too bad viewpunches aren't clientside.
		local RadiusSQ = 15 * Radius^2
		for _,Tar in ipairs(player.GetAll()) do --ipairs(player.GetAll()), player.Iterator()
			if Tar:HasGodMode() then continue end
			local Difpos = (Tar:GetPos() - Hitpos)
			local PlayerDist = Difpos:LengthSqr() + 0.001 --Divide by 0 is death

			if PlayerDist > RadiusSQ then continue end
			local DifAngle = Difpos:Angle()
			local RelAngle = (Angle(-DifAngle.pitch,DifAngle.yaw,0)) - Tar:EyeAngles() + Angle(360,-180,0)
			RelAngle = Angle(math.NormalizeAngle(RelAngle.pitch), math.NormalizeAngle(RelAngle.yaw))
			RelAngle = Angle(RelAngle.pitch > 0 and 1 or (RelAngle.pitch == 0 and 0 or -1),RelAngle.yaw > 0 and 1 or (RelAngle.yaw == 0 and 0 or -1),0) --Converts to signs

			PlayerDist = math.max(PlayerDist,13949) --Will never go below 3 meters.

			Tar:ViewPunch( Angle( math.Clamp(RelAngle.pitch * Amp * -120000 / PlayerDist * math.Rand(0.5,1),-60,60), math.Clamp( RelAngle.yaw * Amp * -100000 / PlayerDist * math.Rand(0.5,1),-60,60), math.Clamp( RelAngle.yaw * Amp * 50000 / PlayerDist * math.Rand(0.5,1),-60,60) ) )
		end

	--debugoverlay.Sphere(Hitpos, Radius, 10, Color(255,0,0,32), 1) --developer 1	in console to see

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
			if OverRun > 5000 or (TotalArmor > (PenetrationMax or 0) and (PenetrationMax or 0) > 0) then
				UnResolved = false
				TotalArmor = 999999 --math.huge
			end

		else --We're done here. Traceline did not hit an entity.
			UnResolved = false
		end
	end

	return TotalArmor

end
