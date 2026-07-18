
--Featuring functions which manage the current built in ace sound extension system
--TODO: Refactor all this, making ONE function for every sound event. Using tables here fit better than this

--NOTE: i would like to have a way of having realtime volume/pitch depending if approaching/going away,
--as having a way to switch sounds between indoor & outdoor zones. They will sound fine, issue it would be when you pass from an area to another when the sound is being played

--NOTE: For proper doppler effect where pitch/volume is dynamically changed, we need something like soundcreate() instead of ply:emitsound.
--Downside of this, that due to gmod limits, one scripted sound per entity can be used at once. Which idk if it would be good for us.
--We'll have more than one dynamic sound at once :/ weird

ACE = ACE or {}

--Defines the delay time caused by the distance between the event and you. Increasing it will increment the required time to hear a distant event
ACE.DelayMultipler            = 1 --5x longer than speed of sound.

--Defines the distance range for close, mid and far sounds. Incrementing it will increase the distances between sounds
ACE.DistanceMultipler         = 1

--Defines the distance range which sonic cracks will be heard by the player
ACE.CrackDistanceMultipler    = 1

--Defines the distance where ring ears start to affect to player
ACE.TinnitusZoneMultipler     = 1.5

----------- Sound Spectrum Config -----------

--Required radius to be considered a small explosion. Less than this the explosion will be considered tiny
ACE.SoundSmallEx	= 5

--Required radius to be considered a medium explosion
ACE.SoundMediumEx  = 10

--Required radius to be considered a large explosion
ACE.SoundLargeEx	= 20

--Required radius to be considered a huge explosion. IDK what thing could pass this, but there is it :)
ACE.SoundHugeEx	= 150


ACE.Sounds          = ACE.Sounds or {}
ACE.Sounds.GunTb    = {}

--Entities which should be the only thing to block the sight
ACE.Sounds.LOSWhitelist = {
	prop_dynamic = true,
	prop_physics = true
}

do

	-- Cache results so we don't need to do expensive filesystem checks every time
	local IsValidCache = {}

	-- Returns whether or not a sound actually exists, fixes client timeout issues
	function ACE.IsValidSound( path )
		if IsValidCache[path] == nil then
			IsValidCache[path] = file.Exists( string.format( "sound/%s", tostring( path ) ), "GAME" ) and true or false
		end
		return IsValidCache[path]
	end

	--Global sound function. In order to be modified by a convar config
	--If the Origin is an entity, uses entity:EmitSound( SoundTxt , SoundLevel, Pitch, Volume )
	--If the Origin is a vector Position, uses sound.Play(SoundTxt, Position, SoundLevel, Pitch, Volume)
	function ACE.EmitSound( SoundTxt, Origin, SoundLevel, Pitch, Volume )

		Volume = math.min( Volume, 1 )
		local VolumeConfig = GetConVar("ace_sound_volume"):GetInt() / 100

		if IsEntity(Origin) and IsValid(Origin) then
			Origin:EmitSound( SoundTxt, SoundLevel, Pitch, Volume * VolumeConfig )
		elseif isvector( Origin ) then
			sound.Play(SoundTxt, Origin, SoundLevel, Pitch, Volume * VolumeConfig )
		end
	end

	--Gets the player's point of view if he's using a camera. Returns the entity input if no external entity is involved.
	function ACE.SGetHearingEntity( ply )
		if not IsValid(ply) then return ply end

		------------------------------- Method 1: Via Camera tool -------------------------------
		if ply:GetViewEntity() ~= ply then
			return ply:GetViewEntity()
		end

		-------------------------- Method 2: Via Wire Cam Controller -----------------------------
		ACE.Sounds.HookTable = ACE.Sounds.HookTable or hook.GetTable()
		if ACE.Sounds.HookTable["CalcView"] then

			ply.aceposoverride	= nil
			-- wire cam controller support. I would wish not to have a really hardcoded way to make everything consistent but well...
			local CameraPos        = ACE.Sounds.HookTable["CalcView"]["wire_camera_controller_calcview"]
			local ThirdPersonPos   = CameraPos and CameraPos()

			if ThirdPersonPos and ThirdPersonPos.origin then
				ply.aceposoverride = ThirdPersonPos.origin
				return ply
			end
		end

		return ply
	end



	function ACE.GetDistanceTime( Dist )
		return (Dist / 13503) * ACE.DelayMultipler
	end

	function ACE.GetHeadPos( ply )
		local plyPos	= ply.aceposoverride or ply:GetPos()
		local headPos	= plyPos + ( not ply:InVehicle() and ( ( ply:Crouching() and Vector(0,0,28) ) or Vector(0,0,64) ) or Vector(0,0,0) )
		return headPos
	end

	--Used for those extremely quiet sounds, which should be heard close to the player
	function ACE.SInDistance( Pos, Distance )

		local ply    = LocalPlayer()

		local entply = ACE.SGetHearingEntity( ply )
		local plyPos = entply:IsPlayer() and ACE.GetHeadPos( ply ) or entply:GetPos()

		--return true if the distance is lower than the maximum distance
		if ACE.InDist( plyPos, Pos, Distance ) then return true end

		return false
	end

	--Gives the approaching speed of an object at a position moving a speed.
	function ACE.Approaching( Pos, Flight )

		local ply    = LocalPlayer()

		local entply = ACE.SGetHearingEntity( ply )
		local plyPos = entply:IsPlayer() and ACE.GetHeadPos( ply ) or entply:GetPos()

		local CurDist = (plyPos - Pos):Length()
		local NextDist = (plyPos - (Pos + Flight * 0.025)):Length()

		return NextDist-CurDist
	end

	--Used to see if the player has line of sight with the event
	function ACE.SHasLOS( EventPos )

		local ply = LocalPlayer()
		local headPos = ACE.GetHeadPos( ply )

		local LOSTr	= {}
		LOSTr.start    = EventPos + Vector(0,0,10)
		LOSTr.endpos   = headPos
		LOSTr.filter   = function( ent ) if ACE.Sounds.LOSWhitelist[ent:GetClass()] then return true end end --Only hits the whitelisted ents
		local LOS	= util.TraceLine(LOSTr)

		if not LOS.Hit then return true end
		return false
	end

	function ACE.SIsInDoor()

		local ply    = LocalPlayer()
		local entply = ACE.SGetHearingEntity( ply )
		local plyPos = entply.aceposoverride or entply:GetPos()

		local CeilTr	= {}
		CeilTr.start	= plyPos
		CeilTr.endpos	= plyPos + Vector(0,0,2000)
		CeilTr.filter	= {}
		CeilTr.mask	= MASK_SOLID_BRUSHONLY
		local Ceil	= util.TraceLine(CeilTr)

		if Ceil.Hit and Ceil.HitWorld then return true end
		return false
	end

end

do
	local SpeedOfSoundEvents = {}

	local eventBase = {
		Duration = 0,
		Sound = "vo/k_lab/kl_ahhhh.wav", -- Just for fun lol
		SoundLevel = 75,
		Pitch = 100,
		Volume = 1
	}

	function eventBase:OnArrived()
		self.Entity = ACE.SGetHearingEntity(LocalPlayer())
	end

	function eventBase:Play()
		ACE.EmitSound(self.Sound, self.Origin or self.Entity, self.SoundLevel, self.Pitch, self.Volume)
	end

	local function newSoundEvent(event)
		event = table.Inherit(event ,eventBase)
		event.Time = event.Duration + RealTime()

		table.insert(SpeedOfSoundEvents, event)

		return event
	end

	local function getHearingPos(hearingEntity)
		return hearingEntity.aceposoverride or hearingEntity:GetPos()
	end


	local function getBlastScale(radius)
		if radius > ACE.SoundHugeEx then return "huge" end
		if radius > ACE.SoundLargeEx then return "large" end
		if radius > ACE.SoundMediumEx then return "medium" end
		if radius > ACE.SoundSmallEx then return "small" end

		return "tiny"
	end

	local closeFixTable = {
		huge = {2000000, 1},
		large = {55, 1.8},
		medium = {7, 1.15},
		small = {6, 0.85},
		tiny = {4.25, 0.75}
	}

	local mediumFixTable = {
		large = {4, 1.6},
		medium = {6, 1.05},
		small = {8, 1.1},
		tiny = {8, 1.3},
	}

	local farFixTable = {
		large = {5, 1.3},
		medium = {5, 0.95},
		small = {14, 1.2},
		tiny = {13, 1.4}
	}

	local function getBlastSoundAboveWater(distance, radius)
		local closeDistance = radius * 300 * ACE.DistanceMultipler
		local mediumDistance = closeDistance * 4.25

		if distance < closeDistance then
			local scale = getBlastScale(radius)
			local soundTable = ACE.Sounds["Blasts"][scale]["close"]

			local Sound = soundTable[math.random(#soundTable)]
			local volFix, pitchFix = unpack(closeFixTable[scale])

			return Sound, volFix, pitchFix
		end

		if distance < mediumDistance then
			local scale = getBlastScale(radius)
			local soundTable = ACE.Sounds["Blasts"][scale]["mid"]

			local Sound = soundTable[math.random(#soundTable)]
			local volFix, pitchFix = unpack(mediumFixTable[scale])

			return Sound, volFix, pitchFix
		end

		local scale = getBlastScale(radius)
		local soundTable = ACE.Sounds["Blasts"][scale]["far"]

		local Sound = soundTable[math.random(#soundTable)]
		local volFix, pitchFix = unpack(farFixTable[scale])

		return Sound, volFix, pitchFix
	end

	--Handles Explosion sounds
	function ACE.SBlast( HitPos, Radius, HitWater, HitWorld )
		local event = newSoundEvent({
			Duration = ACE.GetDistanceTime((getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - HitPos):Length())
		})

		-- doing it in a hacky way, since it needs more then one sound, but should be no isuess
		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())
			local hearingPos = getHearingPos(hearingEntity)
			local distance = (hearingPos - HitPos):Length()

			local volume = 1 / ((hearingEntity:GetPos() - HitPos):Length() / 500) * Radius * 0.2
			local pitch = math.Clamp(1000 / Radius, 25, 130)

			if not HitWater then
				local Sound, volFix, pitchFix = getBlastSoundAboveWater(distance, Radius)

				if not ACE.SHasLOS( HitPos ) and ACE.SIsInDoor() then
					volFix = volFix * 0.5
				end

				volume = volume * volFix
				pitch = pitch * pitchFix

				-- Tinnitus function
				local ply = LocalPlayer()
				if not ply:HasGodMode() then
					local tinZone = math.max(Radius * 80, 50) * ACE.TinnitusZoneMultipler

					if distance <= tinZone and ACE.SHasLOS(HitPos) and hearingEntity == ply and not ply.aceposoverride then

						hearingEntity:SetDSP(33, true)

					if GetConVar("ace_tinnitus"):GetInt() == 1 then

							-- See if it supress the current tinnitus and creates a new one, from 0. Should stop the HE spam tinnitus
							hearingEntity:StopSound("acf_other/explosions/ring/tinnitus.mp3")
							ACE.EmitSound("acf_other/explosions/ring/tinnitus.mp3", hearingEntity, 75, 100, 1 )

						end
					end

					--debugoverlay.Sphere(HitPos, TinZone, 15, Color(0,0,255,32), 1)
				end

				ACE.EmitSound( Sound or "", hearingEntity, 75, pitch, volume)

				--play dirt sounds
				if Radius >= ACE.SoundSmallEx and HitWorld then
					ACE.EmitSound( ACE.Sounds["Debris"]["low"]["close"][math.random(1,#ACE.Sounds["Debris"]["low"]["close"])] or "", hearingPos + (HitPos - hearingPos):GetNormalized() * 64, 80, pitch * pitchFix, volume * volFix / 20 )
					ACE.EmitSound( ACE.Sounds["Debris"]["high"]["close"][math.random(1,#ACE.Sounds["Debris"]["high"]["close"])] or "", hearingPos + (HitPos - hearingPos):GetNormalized() * 64, 80, (pitch * pitchFix) / 0.5, volume * volFix / 20 )
				end

				return
			end

			-- underwater
			ACE.EmitSound( "ambient/water/water_splash" .. math.random(1,3) .. ".wav", hearingEntity, 75, math.max(pitch * 0.75,65), volume * 0.075 )
			ACE.EmitSound( "^weapons/underwater_explode3.wav", hearingEntity, 75, math.max(pitch * 0.75,65), volume * 0.075 )
		end

		function event:Play() end
	end

	-- impact sounds index by surface material

	local impactSounds = {
		Metal = "acf_other/impact/Metal/impact%s.mp3",

		Glass = "acf_other/impact/Glass/impact%s.mp3",

		Wood = "acf_other/impact/Woold/impact%s.mp3",

		Dirt = "acf_other/impact/Soil/impact%s.mp3",
		Sand = "acf_other/impact/Soil/impact%s.mp3",
		Snow = "acf_other/impact/Soil/impact%s.mp3",

		Concrete = "acf_other/impact/Concrete/impact%s.mp3",
		Flesh = "acf_other/impact/Flesh/impact%s.mp3",
		invalid = "acf_other/impact/Concrete/impact%s.mp3",
	}

	local function getImpactSound(material)
		return string.format(impactSounds[material], math.random(3))
	end


	local function bulletImpactCaliberFix(caliber)
		if caliber <= 2 then return 4, 1.15 end --lower than 20mm
		if caliber <= 5 then return 9, 1.10 end --50mm guns and below

		return 13, 0.95 --any gun above 50mm
	end

	--Handles ricochet sounds
	function ACE.SBulletImpact( HitPos, Caliber, Velocity, _, Material )
		local event = newSoundEvent({
			Origin = HitPos,

			Duration = ACE.GetDistanceTime((getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - HitPos):Length())
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())

			local volFix, pitchFix = bulletImpactCaliberFix(Caliber)
			if not ACE.SHasLOS( HitPos ) and ACE.SIsInDoor() then
				volFix = volFix * 0.5
			end

			self.Volume = 1 / ((hearingEntity:GetPos() - self.Origin):Length() / 500) * Velocity / 130000 * volFix
			self.Pitch = math.Clamp(Velocity * 0.001, 90, 150) * pitchFix


			--Disabled as the material overrides should be in the impact fx.
			--if not HitWorld then
			--	self.Sound = getImpactSound("Metal")

			--	return
			--end

			self.Sound = getImpactSound(Material or "invalid")
		end
	end


	-- when ricochet on world, return volFix, pitchFix
	local function bulletRicochetWorldSoundData(caliber)
		if caliber <= 2 then return 3, 1.15 end --lower than 20mm
		if caliber <= 5 then return 6, 1.3 end --50mm guns and below

		return 12, 0.95 --any gun above 50mm
	end

	-- when ricochet on entity, return sound path, volFix, pitchFix
	local function bulletRicochetEntitySoundData(caliber)
		-- 20mm guns and below
		if caliber <= 2 then
			return ACE.Sounds["Ricochets"]["small"]["close"][math.random(#ACE.Sounds["Ricochets"]["small"]["close"])], 5, 1
		end

		-- 50mm guns and below
		if caliber <= 5 then
			return ACE.Sounds["Ricochets"]["medium"]["close"][math.random(#ACE.Sounds["Ricochets"]["medium"]["close"])], 6, 1
		end

		-- above 50mm guns
		return ACE.Sounds["Ricochets"]["large"]["close"][math.random(#ACE.Sounds["Ricochets"]["large"]["close"])], 7, 1
	end

	--Handles ricochet sounds 
	function ACE.SRicochet( HitPos, Caliber, Velocity, HitWorld, Material )
		local event = newSoundEvent({
			SoundLevel = 100,
			Pitch = math.Clamp(Velocity * 0.001, 90, 150),

			Duration = ACE.GetDistanceTime((getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - HitPos):Length())
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())

			local volFix, pitchFix = 1, 1
			if not HitWorld then
				local Sound, vf, pf = bulletRicochetEntitySoundData(Caliber)
				volFix = vf
				pitchFix = pf

				self.Sound = Sound
			else
				volFix, pitchFix = bulletRicochetWorldSoundData(Caliber)

				-- same as impact sound right now
				self.Sound = getImpactSound(Material or "invalid")
			end

			if not ACE.SHasLOS( HitPos ) and ACE.SIsInDoor() then
				volFix = volFix * 0.5
			end

			local distance = (getHearingPos(hearingEntity) - HitPos):Length()
			local volume = 1 / (distance / 500) * Velocity / 130000
			self.Volume = volume * volFix
			self.Pitch = self.Pitch * pitchFix
			self.Entity = hearingEntity
		end
	end


	-- when penetrated world, return volFix, pitchFix
	local function bulletPenetrateWorldSoundData(caliber)
		if caliber <= 2 then return 4, 1.15 end --lower than 20mm
		if caliber <= 5 then return 7, 1.05 end --50mm guns and below

		return 10, 0.95 --any gun above 50mm
	end

	-- when penetrated entity, return volFix, pitchFix
	local function bulletPenetrateEntitySoundData(caliber)
		if caliber <= 2 then return 0.5, 0.9 end --lower than 20mm
		if caliber <= 5 then return 0.5, 0.7 end --50mm guns and below

		return 0.5, 0.4 --any gun above 50mm
	end

	--Handles penetration sounds
	function ACE.SPenetration( HitPos, Caliber, Velocity, HitWorld, Material, Mass )
		local event = newSoundEvent({
			Sound = "acf_other/penetratingshots/penetrations/large/close/pen" .. math.random(3) .. ".mp3",

			Pitch = math.Clamp(Velocity * 1, 90, 150),

			Duration = ACE.GetDistanceTime((getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - HitPos):Length())
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())

			self.Entity = hearingEntity

			local volFix, pitchFix = 1, 1
			if not HitWorld then
				volFix, pitchFix = bulletPenetrateEntitySoundData(Caliber)
			else
				volFix, pitchFix = bulletPenetrateWorldSoundData(Caliber)

				-- same as impact sound right now
				self.Sound = getImpactSound(Material or "invalid")
			end

			if not ACE.SHasLOS( HitPos ) and ACE.SIsInDoor() then
				volFix = volFix * 0.5
			end

			self.Volume = 1 / ((getHearingPos(hearingEntity) - HitPos):Length() / 500) * Mass / 17.5 * volFix
			self.Pitch = self.Pitch * pitchFix
		end
	end


	local function getFireSoundDistance(distance, closeDist)
		if distance > closeDist * 4.25 then return "far" end
		if distance > closeDist then return "mid" end

		return "main"
	end

	-- Use a local table to replace the global one
	-- Nothing is accessing it so avoid globals everywhere
	local fireSoundPackageIndex = {}

	function ACE.SGunFire( Gun, Sound, PitchOverride, Propellant )
		if not IsValid(Gun) then return end
		if not Sound or Sound == "" then return end

		Propellant = math.max(Propellant,50)

		local hearingPos = getHearingPos(ACE.SGetHearingEntity( LocalPlayer() ))

		local event = newSoundEvent({
			Sound = Sound or "",

			SoundLevel = 100,
			Pitch = PitchOverride,

			Duration = ACE.GetDistanceTime((hearingPos - Gun:GetPos()):Length()),

			Origin = Gun:GetPos()
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())
			local hearingPos = getHearingPos(hearingEntity)
			local origin = self.Origin

			local dist = (hearingPos - origin):Length()

			-- get the "State" which is what distance the sound should use
			local soundDistance = getFireSoundDistance(dist, Propellant * 40 * ACE.DistanceMultipler)
			local soundData = ACE.GSounds["GunFire"][Sound]
			local volFix = 1
			local gunID	= Gun:EntIndex()

			-- using the old gunid, but wont that cause memory leak?
			if soundData then
				local distancedSoundData = soundData[soundDistance] or soundData["main"]
				local soundPackage = distancedSoundData["Package"]
				local index = (fireSoundPackageIndex[gunID] or 0) + 1

				if index > #soundPackage then
					index = 1
				end

				self.Sound = soundPackage[index]
				self.Pitch = distancedSoundData.Pitch
				volFix = distancedSoundData.Volume

				fireSoundPackageIndex[gunID] = index
			end

			if not ACE.SHasLOS( origin ) and ACE.SIsInDoor() then
				volFix = volFix * 0.025
			end

			self.Origin = hearingPos + (origin - hearingPos):GetNormalized() * 64
			self.Volume = (1 / (dist / 500) * Propellant / 18) * volFix
		end
	end


	-- return sound path and volFix based on caliber
	local function getBulletCrackSound(caliber)
		-- Some fly sounds don´t fit really well. Special case here.
		if caliber >= 20 then
			return ACE.Sounds["Cracks"]["large"]["close"][math.random(#ACE.Sounds["Cracks"]["large"]["close"])], 0.5
		end

		-- above 100mm cannons
		if caliber >= 10 then
			return ACE.Sounds["Cracks"]["large"]["close"][math.random(#ACE.Sounds["Cracks"]["large"]["close"])], 1
		end

		-- 30mm gun and above
		if caliber >= 3 then
			return ACE.Sounds["Cracks"]["medium"]["close"][math.random(#ACE.Sounds["Cracks"]["medium"]["close"])], 0.1
		end

		-- small arms
		return ACE.Sounds["Cracks"]["small"]["close"][math.random(#ACE.Sounds["Cracks"]["small"]["close"])], 0.1
	end

	--TODO: Leave 5 sounds per caliber type. 22 7.26mm sounds go brrrr
	function ACE.SBulletCrack( BulletData, Caliber )

		-- flag this, so we are not playing this sound for this bullet next time
		BulletData.CrackCreated = true

		local CrackPos = BulletData.SimPos - BulletData.SimFlight:GetNormalized() * 5000
		local distance = (getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - CrackPos):Length()

		local event = newSoundEvent({
			Volume = 10000 / distance,

			Duration = ACE.GetDistanceTime(distance)
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())

			local Sound, volFix = getBulletCrackSound(Caliber)
			self.Sound = Sound

			if not ACE.SHasLOS( BulletData.SimPos ) and ACE.SIsInDoor() then
				volFix = volFix * 0.025
			end
			self.Volume = self.Volume * volFix

			self.Entity = hearingEntity
		end
	end


	--TODO: Leave 5 sounds per caliber type. 22 7.26mm sounds go brrrr
	function ACE.SBulletWhistle( BulletData )
		-- flag this, so we are not playing this sound for this bullet next time
		BulletData.HasWhistled = true

		local event = newSoundEvent({
			Sound = "acf_extra/ACE/SoundsMaccnificient/IncomingShell/whistle_arty_0" .. math.random(3) .. ".wav",

			Duration = ACE.GetDistanceTime((getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - BulletData.SimPos):Length())
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())

			local volFix = 1
			if not ACE.SHasLOS( BulletData.SimPos ) and ACE.SIsInDoor() then
				volFix = volFix * 0.5
			end
			self.Volume = 10000 * volFix

			local ShellVel = BulletData.SimFlight:Length()
			self.Pitch = math.Clamp( ShellVel / 3 / 39.37, 30, 165 )

			self.Entity = hearingEntity
		end

		debugoverlay.Cross(BulletData.SimPos, 10, 5, Color(0,0,255))
	end


	--For any miscellaneous sound. BaseDistVolume is the Max dist where Volume will be 1. The volume will start losing dbs beyond this distance. In Units.
	function ACE.SimpleSound( Sound, Origin, Pitch, BaseDistVolume  )
		local event = newSoundEvent({
			Sound = Sound or "",

			SoundLevel = 100,
			Pitch = Pitch,

			Duration = ACE.GetDistanceTime((getHearingPos(ACE.SGetHearingEntity(LocalPlayer())) - Origin):Length())
		})

		function event:OnArrived()
			local hearingEntity = ACE.SGetHearingEntity(LocalPlayer())
			local hearingPos = getHearingPos(hearingEntity)

			local volFix = 1
			if not ACE.SHasLOS( Origin ) and ACE.SIsInDoor() then
				volFix = volFix * 0.025
			end

			self.Origin = hearingPos + (Origin - hearingPos):GetNormalized() * 64
			self.Volume = BaseDistVolume / (EyePos() - Origin):Length() * volFix
			--self.Pitch = Pitch * math.Clamp(Velocity * 0.001, 90, 150) -Unfinished doppler code.
			self.Pitch = Pitch
		end
	end

	-- running all the sound events
	hook.Add("Think", "ACE_Think_SpeedOfSound", function()
		for i = #SpeedOfSoundEvents, 1, -1 do -- iterate backwards to ensure we can remove elements properly
			local event = SpeedOfSoundEvents[i]

			if event.Time < RealTime() then
				event:OnArrived()
				if event.Sound then
					event:Play()
				end

				table.remove(SpeedOfSoundEvents, i)
			end
		end
	end)
end
