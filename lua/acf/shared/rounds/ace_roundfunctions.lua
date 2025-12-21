AddCSLuaFile( "acf/shared/rounds/ace_roundfunctions.lua" )


do

	local Floor = math.floor
	local MaxValue = math.max
	local PI = math.pi

	function ACF_RoundBaseGunpowder( PlayerData, Data, ServerData, GUIData )

		local BulletMax = ACF.Weapons["Guns"][PlayerData["Id"]]["round"]
		--local Type = PlayerData.Type or ""

		GUIData.MaxTotalLength    = BulletMax.maxlength * (Data.LengthAdj or 1)

		Data.Caliber              = ACF.Weapons["Guns"][PlayerData["Id"]]["caliber"]
		Data.FrArea               = PI * (Data.Caliber / 2) ^ 2

		Data.Tracer               = PlayerData.Tracer > 0 and math.min(Data.Caliber / 5, 3) or 0 --Tracer space calcs
		Data.TwoPiece             = PlayerData.TwoPiece > 0 and 1 or 0


		local PropMax = (BulletMax.propweight * 1000 / ACF.PDensity) / Data.FrArea	--Current casing absolute max propellant capacity
		local CurLength = (PlayerData.ProjLength + math.min(PlayerData.PropLength,PropMax) + Data.Tracer )

		GUIData.MinPropLength = 0.01
		GUIData.MaxPropLength = math.max(math.min(GUIData.MaxTotalLength - CurLength + PlayerData.PropLength, PropMax), GUIData.MinPropLength) --Check if the desired prop lenght fits in the case and doesn't exceed the gun max

		GUIData.MinProjLength = Data.Caliber * 1.5
		GUIData.MaxProjLength = math.max(GUIData.MaxTotalLength - CurLength + PlayerData.ProjLength, GUIData.MinProjLength ) --Check if the desired proj lenght fits in the case

		--This is to check the current ratio between elements if i need to clamp it
		local Ratio 		= math.min(1, (GUIData.MaxTotalLength - Data.Tracer) / (PlayerData.ProjLength + math.min(PlayerData.PropLength, PropMax)))

		Data.ProjLength		= math.Clamp( PlayerData.ProjLength * Ratio, GUIData.MinProjLength, GUIData.MaxProjLength )
		Data.PropLength		= math.Clamp( PlayerData.PropLength * Ratio, GUIData.MinPropLength, GUIData.MaxPropLength )

		Data.PropMass		= Data.FrArea * (Data.PropLength * ACF.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg
		GUIData.ProjVolume	= Data.FrArea * Data.ProjLength
		Data.RoundVolume	= Data.FrArea * (Data.ProjLength + Data.PropLength )

		return PlayerData, Data, ServerData, GUIData
	end

	--match sv_acfdamage.lua
	function ACF_CalcFragmentCount(fillerMass, casingMass)
		local totalMass = fillerMass + casingMass
		
		local avgFragMassGrams = 0.1 + totalMass * 0.3
		avgFragMassGrams = math.Clamp(avgFragMassGrams, 0.1, 5.0)
		
		local baseFrags = (casingMass * 1000) / avgFragMassGrams
		
		local maxFrags = ACF.MaxFragmentCount or 2000
		local cappedFrags = math.Clamp(math.floor(baseFrags), 2, maxFrags)
		
		return cappedFrags, math.floor(baseFrags)
	end

	function ACF_CalcGurneyFragVel(fillerMass, casingMass)
		local cmRatio = fillerMass / math.max(casingMass, 0.001)
		local velocity = ACF.GurneyConstant * math.sqrt(cmRatio) / math.sqrt(1 + cmRatio / 2)
		return velocity
	end

	function ACF_CalcFragmentArea(fragMass)
		local massGrams = fragMass * 1000
		local areaCm2 = 0.5 * (massGrams ^ (2/3))
		return areaCm2
	end

	function ACF_GetHEDisplayData(fillerMass, casingMass)
		local GUIData = {}

		fillerMass = tonumber(fillerMass) or 0
		casingMass = tonumber(casingMass) or 0

		-- Matches ACE_CalculateHERadius in sv_acfdamage.lua (meters)
		GUIData.BlastRadius = fillerMass ^ 0.33 * 8

		-- Fragment count
		local fragsCapped, fragsUncapped = ACF_CalcFragmentCount(fillerMass, casingMass)
		fragsCapped = math.max(tonumber(fragsCapped) or 0, 1)
		fragsUncapped = math.max(tonumber(fragsUncapped) or 0, 0)

		GUIData.Fragments = fragsCapped
		GUIData.FragmentsUncapped = fragsUncapped

		-- Frag mass / vel
		GUIData.FragMass = casingMass / fragsCapped
		GUIData.FragVel  = ACF_CalcGurneyFragVel(fillerMass, casingMass)
		GUIData.FragArea = ACF_CalcFragmentArea(GUIData.FragMass)

		-- Power
		GUIData.Power = fillerMass * (ACF.HEPower or 0)

		-- Blast penetration
		GUIData.CanBlastPen = GUIData.Power > (ACF.HEBlastPenMinPow or math.huge)
		if GUIData.CanBlastPen then
			GUIData.BlastPen = GUIData.Power / (ACF.HEBlastPenetration or 1)
			GUIData.BlastPenRadius = GUIData.BlastRadius / (ACF.HEBlastPenRadiusMul or 1)
		else
			GUIData.BlastPen = 0
			GUIData.BlastPenRadius = 0
			GUIData.FillerNeeded = ((ACF.HEBlastPenMinPow or 0) - GUIData.Power) / (ACF.HEPower or 1)
		end

		-- If no casing, treat as blast-only for display
		if casingMass <= 0 or GUIData.FragMass <= 0 then
			GUIData.FragEffectiveRange = GUIData.BlastRadius * 1.5
			GUIData.FragRadius = GUIData.BlastRadius * 2.5
			return GUIData
		end

		-- Fragment range scaling (matches your sv_acfdamage.lua approach approximately)
		local fragDensity = tonumber(ACF.FragDensity) or 0
		local dragCoef    = tonumber(ACF.FragDragCoef) or 0
		local airDensity  = tonumber(ACF.FragAirDensity) or 0

		if fragDensity <= 0 or dragCoef <= 0 or airDensity <= 0 then
			GUIData.FragEffectiveRange = GUIData.BlastRadius * 1.5
			GUIData.FragRadius = GUIData.BlastRadius * 2.5
			return GUIData
		end

		local fragVolume = GUIData.FragMass / fragDensity
		local fragDiameter = (fragVolume * 6 / math.pi) ^ (1/3)
		local fragArea = math.pi * (fragDiameter / 2) ^ 2
		if fragArea <= 0 then
			GUIData.FragEffectiveRange = GUIData.BlastRadius * 1.5
			GUIData.FragRadius = GUIData.BlastRadius * 2.5
			return GUIData
		end

		local ballisticCoef = GUIData.FragMass / (dragCoef * fragArea)
		if ballisticCoef <= 0 then
			GUIData.FragEffectiveRange = GUIData.BlastRadius * 1.5
			GUIData.FragRadius = GUIData.BlastRadius * 2.5
			return GUIData
		end

		local dragConstant = airDensity / (2 * ballisticCoef)

		local effectiveVelRatio = ACF.HEFragEffectiveVelRatio or 0.25
		local targetVel = math.max(GUIData.FragVel * effectiveVelRatio, ACF.MinLethalFragVel or 0)

		if GUIData.FragVel > targetVel and dragConstant > 0 then
			local rawRange = ((GUIData.FragVel / targetVel) - 1) * 1000 / (dragConstant * GUIData.FragVel)
			local sourceUnits = rawRange * 39.37

			local chargeScale = math.Clamp(1.1 - fillerMass * 0.15, 0.50, 1.0)
			local velBonus = math.Clamp(0.4 + GUIData.FragVel / 2500, 0.5, 1.2)
			local combinedScale = 0.40 * chargeScale * velBonus

			local scaledRange = sourceUnits * combinedScale
			scaledRange = math.max(scaledRange, GUIData.BlastRadius * 39.37 * 1.5)

			local extendedZoneMul = math.Clamp(1.4 + fillerMass * 0.2, 1.4, 1.8)
			local maxRange = math.min(scaledRange * extendedZoneMul, (ACF.HEFragMaxRange or 7874))

			GUIData.FragEffectiveRange = scaledRange / 39.37
			GUIData.FragRadius = maxRange / 39.37
		else
			GUIData.FragEffectiveRange = GUIData.BlastRadius * 1.5
			GUIData.FragRadius = GUIData.BlastRadius * 2.5
		end

		return GUIData
	end

	function ACF_RoundShellCapacity( Momentum, FrArea, Caliber, ProjLength )

		local MinWall = 0.2 + ((Momentum / FrArea) ^ 0.7) / 50 --The minimal shell wall thickness required to survive firing at the current energy level
		local Length = math.max(ProjLength - MinWall, 0)
		local Radius = math.max((Caliber / 2) - MinWall, 0)
		local Volume = PI * Radius ^ 2 * Length

		return  Volume, Length, Radius --Returning the cavity volume and the minimum wall thickness
	end

	function ACF_RicoProbability( Rico, Speed )

		local RicoAngle = math.Round(math.min(Rico -  (( (Speed-800) / 39.37 ) / 5),89))

		local None = math.max(RicoAngle-10,1) --0% chance to ricochet
		local Mean = math.max(RicoAngle,1)	--50% chance to ricochet
		local Max = math.max(RicoAngle + 10,1)  --100% chance to ricochet

		return None, Mean, Max

	end

	--Formula from https://mathscinotes.wordpress.com/2013/10/03/parameter-determination-for-pejsa-velocity-model/
	--not terribly accurate for acf, particularly small caliber (7.62mm off by 120 m/s at 800m), but is good enough for quick indicator
	--range in m, vel is m/s
	function ACF_PenRanging(MuzzleVel, DragCoef, ProjMass, PenArea, LimitVel, Range)
		local V0 = MuzzleVel * 39.37 * ACF.VelScale -- initial velocity
		local D0 = DragCoef * V0 ^ 2 / ACF.DragDiv -- initial drag
		local K1 = (D0 / (V0 ^ (3 / 2))) ^ -1 -- estimated drag coefficient
		local Vel = math.max(math.sqrt(V0) - ((Range * 39.37) / (2 * K1)), 0) ^ 2
		local Pen = (ACF_Kinetic(Vel, ProjMass, LimitVel).Penetration / PenArea) * ACF.KEtoRHA

		return Vel * 0.0254, Pen
	end

	do

		local function VerifyScale( Scale )
			if not isvector( Scale ) then return end

			local MinSize = ACF.CrateMinimumSize
			local MaxSize = ACF.CrateMaximumSize

			Scale.x = math.Clamp(Scale.x,MinSize,MaxSize)
			Scale.y = math.Clamp(Scale.y,MinSize,MaxSize)
			Scale.z = math.Clamp(Scale.z,MinSize,MaxSize)

			return Scale
		end

		local function VerifyVector( vecstring )

			if isvector( vecstring ) then return vecstring end
			if not isstring(vecstring) then return end



			local VecTbl = string.Explode( ":", vecstring )
			local Scale = Vector(VecTbl[1],VecTbl[2],VecTbl[3])

			return Scale
		end

		local function CreateRealScale( Scale )

			Scale = VerifyVector( Scale )
			Scale = VerifyScale( Scale )

			return Scale
		end

		--This function is a direct copy from acf_ammo code. So its expected that the result matches with the ammo count
		--TODO: Use this same function for Existent crates? Weird to have this same code in both places.

		local toInche = 2.54		--Number used for cm -> inche conversion

		function ACE_AmmoCapacity( Data )

			local GunId	= acfmenupanel.AmmoData.Data.id
			local AmmoGunData = ACF.Weapons.Guns[GunId]
			local GunClass	= AmmoGunData.gunclass
			local ClassData	= ACF.Classes.GunClass[GunClass]

			local ProjLenght = Data.ProjLength
			local PropLenght = Data.PropLength
			local Caliber	= Data.Caliber

			local width, shellLength

			if ClassData.type == "missile" then
				width = AmmoGunData.modeldiameter or (AmmoGunData.caliber / ACF.AmmoLengthMul / toInche)
				shellLength = AmmoGunData.length / ACF.AmmoLengthMul / toInche
			else
				width = Caliber / ACF.AmmoWidthMul / toInche
				shellLength = ((PropLenght or 0) + (ProjLenght or 0)) / ACF.AmmoLengthMul / toInche
			end

			local Id		= acfmenupanel.AmmoData.Id
			local Dimensions = vector_origin

			if not ACE_CheckAmmo( Id ) then
				Dimensions = CreateRealScale(Id)
			else
				local AmmoData	= ACF.Weapons.Ammo[Id]
				Dimensions = Vector(AmmoData.Lenght,AmmoData.Width,AmmoData.Height)
			end

			local cap1 = Floor(Dimensions.x / shellLength) * Floor(Dimensions.y / width) * Floor(Dimensions.z / width)
			local cap2 = Floor(Dimensions.y / shellLength) * Floor(Dimensions.x / width) * Floor(Dimensions.z / width)
			local cap3 = Floor(Dimensions.z / shellLength) * Floor(Dimensions.x / width) * Floor(Dimensions.y / width)

			--Split the shell in 2, leave the other piece next to it.
			local piececap1 = Floor(Dimensions.x / (shellLength / 2)) * Floor(Dimensions.y / (width * 2)) * Floor(Dimensions.z / width)
			local piececap2 = Floor(Dimensions.y / (shellLength / 2)) * Floor(Dimensions.x / (width * 2)) * Floor(Dimensions.z / width)
			local piececap3 = Floor(Dimensions.z / (shellLength / 2)) * Floor(Dimensions.x / (width * 2)) * Floor(Dimensions.y / width)

			local Cap	= MaxValue(cap1,cap2,cap3)
			local FpieceCap = MaxValue(piececap1,piececap2,piececap3)

			local TwoPiece = false

			--Why would you need the 2 piece for rounds below 50mm? Unless you want legos there....
			if Data.Caliber >= 5 and ClassData.type ~= "missile" and FpieceCap > Cap and Data.TwoPiece > 0 then  --only if the 2 piece system is allowed to be used
				Cap	= FpieceCap
				TwoPiece = true
			end

			local RoFNerf = TwoPiece and 30 or nil

			return Cap, RoFNerf, TwoPiece
		end

		--General Ammo Capacity diplay shown on ammo config
		function ACE_AmmoCapacityDisplay(Data)

			local Cap, RoFNerf, TwoPiece = ACE_AmmoCapacity( Data )

			local plur = "" .. Cap .. " " .. (Cap > 1 and "rounds" or "round")

			local bonustxt = "Storage: " .. plur

			if TwoPiece then
				bonustxt = bonustxt .. ". Uses 2 piece ammo. -" .. RoFNerf .. "% RoF"
			end
			acfmenupanel:CPanelText("BonusDisplay", bonustxt )
		end

	end

	function ACE_AmmoRangeStats( MuzzleVel, DragCoef, ProjMass, PenArea, LimitVel )

		local Range	= {}
		Range.Vel		= {}
		Range.Pen		= {}
		Range.Distance	= {}
		final_text		= {}

		for i = 1, 4 do
			Range.Distance[i] = (2 ^ (i - 1)) * 100
			Range.Vel[i], Range.Pen[i] = ACF_PenRanging(MuzzleVel, DragCoef, ProjMass, PenArea, LimitVel, Range.Distance[i])

			final_text[i] = "At " .. Range.Distance[i] .. "m pen: " .. Floor(Range.Pen[i]) .. "mm @ " .. Floor(Range.Vel[i]) .. "m\\s\n"
		end

		local ftext = table.concat(final_text)

		acfmenupanel:CPanelText("PenetrationDisplay", ftext .. "\nThe range data is an approximation and may not be entirely accurate.\n")

	end

	function ACE_AmmoStats(RoundLenght, MaxTotalLenght, MuzzleVel, MaxPen)
	acfmenupanel:CPanelText("BoldAmmoStats", "Round information: ", "DermaDefaultBold")
	acfmenupanel:CPanelText("AmmoStats", "Round Length: " .. RoundLenght .. "/" .. MaxTotalLenght .. " cms (" .. math.Round(RoundLenght / 2.54, 2) .. " inches)\nMuzzle Velocity: " .. MuzzleVel .. " m\\s\nMax penetration: " .. MaxPen .. " mm RHA") --Total round length (Name, Desc)

	end

	do

		function ACE_UpperCommonDataDisplay( Data, PlayerData )

			if not acfmenupanel then return end

			if not Data or not PlayerData then
				acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

				acfmenupanel:CPanelText("BonusDisplay", "\n")
				acfmenupanel:CPanelText("Desc", "")
				ACE_AmmoStats( 0, 0, 0, 0 )

			else
				acfmenupanel:CPanelText("CrateInfoBold", "Crate information:", "DermaDefaultBold")

				ACE_AmmoCapacityDisplay( Data )
				acfmenupanel:CPanelText("Desc", ACF.RoundTypes[PlayerData.Type].desc)
				ACE_AmmoStats(Floor((Data.PropLength + Data.ProjLength + (Floor(Data.Tracer * 5) / 10)) * 100) / 100, Data.MaxTotalLength, Floor(Data.MuzzleVel * ACF.VelScale), Floor(Data.MaxPen))
			end

		end


		local TPtip = "Attempts to increase the ammo capacity by dividing the round in 2 pieces, at the cost of more reload time.\n\nWorks with rounds above 50mm and does nothing for missiles/bombs or when the cap cannot be increased."
		local Trtip = "Adds a trail to the shell, which will be seen during the flight. \nUseful for cases when you want to correct trayectories.\n\nProTip: Apply a color to the crate to change the tracer color."

		function ACE_CommonDataDisplay( Data )

			if not acfmenupanel then return end

			if not Data then

				acfmenupanel:AmmoCheckbox("Tracer", "Enable Tracer: ", "", Trtip)							--Tracer checkbox (Name, Title, Desc)
				acfmenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", TPtip )
				acfmenupanel:CPanelText("RicoDisplay", "")										--estimated rico chance
				acfmenupanel:CPanelText("PenetrationDisplay", "")								--Proj muzzle penetration (Name, Desc)
			else

				acfmenupanel:AmmoCheckbox("Tracer", "Enable Tracer: " .. (Floor(Data.Tracer * 5) / 10) .. "cm\n", "", Trtip) --Tracer checkbox (Name, Title, Desc)
				acfmenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", TPtip )

				local None, Mean, Max = ACF_RicoProbability(Data.Ricochet, Data.MuzzleVel * ACF.VelScale)
				acfmenupanel:CPanelText("RicoDisplay", "0% chance of ricochet at: " .. None .. "°\n50% chance of ricochet at: " .. Mean .. "°\n100% chance of ricochet at: " .. Max .. "°")

				ACE_AmmoRangeStats( Data.MuzzleVel, Data.DragCoef, Data.ProjMass, Data.PenArea, Data.LimitVel )
			end
		end

		--Because HE/Shaped rounds are different. Intented not to be merged into main function above, as its temporal.
		function ACE_Checkboxes( Data )

			if not acfmenupanel then return end

			if not Data then
				acfmenupanel:AmmoCheckbox("Tracer", "Enable Tracer: ", "", Trtip)							--Tracer checkbox (Name, Title, Desc)
				acfmenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", TPtip )
			else
				acfmenupanel:AmmoCheckbox("Tracer", "Enable Tracer: " .. (Floor(Data.Tracer * 5) / 10) .. "cm\n", "", Trtip)		--Tracer checkbox (Name, Title, Desc)
				acfmenupanel:AmmoCheckbox("TwoPiece", "Enable Two Piece Storage", "", TPtip )
			end
		end
	end

	--=====================[ DEPRECATED FUNCTION ]=====================--

	--This function is not used by ACE anymore, but i´ll keep it just for those acf2 custom ammos dont break
	function ACF_CalcCrateStats()
		return 0, 0, 0
	end

end
