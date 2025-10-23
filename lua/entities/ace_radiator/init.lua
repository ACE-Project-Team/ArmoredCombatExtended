AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

--don't forget:
--armored tanks

do

	local RadiatorWireDescs = {
		--Inputs
		["ActiveCooling"]	= "Active uses engine power to cool the radiator. Pushes an additional 20mph of airflow through the radiator.",

		--Outputs
		["Coolant"]        = "Returns the current coolant level.",
		["Capacity"]    = "Returns the max capacity of the radiator.",
		["Leaking"]     = "Is the radiator leaking?",
		["Temperature"]     = "How hot is the radiator"
	}

	function ENT:Initialize()

		self.CanUpdate        = true

		self.Size             = 0	--outer dimensions
		self.Volume           = 0	--total internal volume in cubic inches
		self.Capacity         = 0	--max coolant capacity in liters
		self.EmptyMass        = 0	--mass of tank only

		self.ThermalSurfaceArea = 1 	--total surface area of the radiator fins
		self.AirflowRestrictiveness = 1 --Ratio for airflow passing through the radiator.

		self.NextMassUpdate   = 0
		self.NextGUIUpdate    = 0
		self.Id               = nil	--model id
		self.Active           = false
		self.FanRunning		  = 0
		self.NextLegalCheck   = ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
		self.Legal            = true
		self.LegalIssues      = ""

		self.RadiatorEfficacy = 1
		self.ActiveTorqueDemand = 1

		self.FanSpeed = 0

		self.Sound = nil
		self.SoundPath = "acf_extra/ACE/miscellaneous/fans/BuzzingCoolingFan.wav"
		self.SoundPitch = 100

		self.RadiatorStats    = "" --Used to cache radiator stats. No reason to recalculate these constantly.
		self.Heat = ACE.AmbientTemp

		self.Inputs = Wire_CreateInputs( self, { "ActiveCooling (" .. RadiatorWireDescs["ActiveCooling"] .. ")" } )
		self.Outputs = WireLib.CreateSpecialOutputs( self,
			{  "Temperature (" .. RadiatorWireDescs["Temperature"] .. ")", "Coolant (" .. RadiatorWireDescs["Coolant"] .. ")", "Capacity (" .. RadiatorWireDescs["Capacity"] .. ")", "Leaking (" .. RadiatorWireDescs["Leaking"] .. ")", "FanRunning", "Entity" },
			{ "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "ENTITY" }
		)
		Wire_TriggerOutput( self, "Leaking", 0 )
		Wire_TriggerOutput( self, "Entity", self )

		self.Master = {} --engines linked to this tank

		self.LastThink = 0

		self.NextFanLogic = 0
		self.NextHeatLogic = 0
		self.LastThink2 = 0 --Used for the core heat logic running less frequently
		self.NextThink = ACF.CurTime +  1

	end

end

function ENT:ACF_Activate( Recalc )

	self.ACF = self.ACF or {}

	local PhysObj = self:GetPhysicsObject()
	if not self.ACF.Area then
		self.ACF.Area = PhysObj:GetSurfaceArea() * 6.45
	end
	if not self.ACF.Volume then
		self.ACF.Volume = PhysObj:GetVolume() * 1
	end

	local Armour = self.EmptyMass * 1000 / self.ACF.Area / 0.78 --So we get the equivalent thickness of that prop in mm if all it's weight was a steel plate
	local Health = self.ACF.Volume / ACF.Threshold							--Setting the threshold of the prop Area gone

	local Percent = 1
	if Recalc and self.ACF.Health and self.ACF.MaxHealth then
		Percent = self.ACF.Health / self.ACF.MaxHealth
	end

	self.ACF.Health    = Health * Percent
	self.ACF.MaxHealth = Health
	self.ACF.Armour    = Armour * (0.5 + Percent / 2)
	self.ACF.MaxArmour = Armour
	self.ACF.Type      = nil
	self.ACF.Mass      = self.Mass
	self.ACF.Density   = (PhysObj:GetMass() * 1000) / self.ACF.Volume
	self.ACF.Type      = "Prop"

	self.ACF.Material	= not isstring(self.ACF.Material) and ACE.BackCompMat[self.ACF.Material] or self.ACF.Material or "RHA"

	--Forces an update of mass
	self.LastMass = 1
	self:UpdateRadiatorMass()

end

do

	-- Checks if the provided string vector matches the desired format.
	-- Define a pattern to match the format
	local pattern = "^%d+%.?%d*:%d+%.?%d*:%d+%.?%d*$"
	local function IsValidStringScale( Id )
		if not isstring( Id ) then return false end
		if not string.match(Id, pattern) then return false end
		return true
	end

	-- Converts an already verified string vector into a valid vector scale.
	local function ParseToVector( ScaleId )
		if not isstring(ScaleId) then return end

		local Result = string.Explode( ":", ScaleId )

		local X = tonumber(Result[1])
		local Y = tonumber(Result[2])
		local Z = tonumber(Result[3])

		return Vector(X, Y, Z)
	end

	-- Clamps the already converted scale so its within the size limits, defined on globals.
	local function ClampScale( Scale )
		if not isvector( Scale ) then return end

		local MinSize = ACF.CrateMinimumSize
		local MaxSize = ACF.CrateMaximumSize

		Scale.x = math.Clamp( math.Round(Scale.x, 1), MinSize, MaxSize)
		Scale.y = math.Clamp( math.Round(Scale.y, 1), MinSize, MaxSize)
		Scale.z = math.Clamp( math.Round(Scale.z, 1), MinSize, MaxSize)

		return Scale
	end

	-- Tries to convert a scale id, having a string format, to a vector scale. If its already a vector, skip the process.
	local function ConvertStringScale( ScaleId )
		if isvector( ScaleId ) then return ScaleId end
		if not IsValidStringScale( ScaleId ) then return end

		local Scale = ParseToVector( ScaleId )
		Scale = ClampScale( Vector(Scale.y, Scale.x, Scale.z) )

		return Scale
	end

	function MakeACE_Radiator(Owner, Pos, Angle, Id, Data1)

		if IsValid(Owner) and not Owner:CheckLimit("_acf_misc") then return false end

		local Tank = ents.Create("ace_radiator")
		if IsValid(Tank) then

			local Model
			local Dimensions

			Tank:CPPISetOwner(Owner)
			Tank:SetAngles(Angle)
			Tank:SetPos(Pos)
			Tank:Spawn()

			local Scale = ConvertStringScale(Data1)

			if isvector(Scale) then

				local ModelData = ACE.ModelData["Radiator"]

				Data1 = Scale
				Model = ModelData.Model
				Weight = (Scale.x * Scale.y * Scale.z) / 200
				Dimensions = Scale

				local DefaultSize    = ModelData.DefaultSize
				local Mesh           = ModelData.CustomMesh
				local PhysMaterial   = ModelData.physMaterial
				--Width is X
				--Thickness is y
				--Height is Z
				local RadScale = Vector(1/35.775, 1/4.5, 1/22.5)
				--local EntityScale    = Vector(Scale.x / DefaultSize, Scale.y / DefaultSize, Scale.z / DefaultSize) --Defaultsize does not support 3d vectors. 
				local EntityScale    = Vector(Scale.x, Scale.y, Scale.z) * RadScale

					
				Tank.ScaleData = {
					Mesh = Mesh,
					Scale = EntityScale,
					Size = DefaultSize,
					Material = PhysMaterial,
				}

				--Tank:SetMaterial("phoenix_storms/gear")
				Tank:SetModel( Model ) --Sending the model to client
				Tank:PhysicsInit( SOLID_VPHYSICS )
				Tank:SetMoveType( MOVETYPE_VPHYSICS )
				Tank:SetSolid( SOLID_VPHYSICS )

				Tank.IsScalable = true
				Tank:ACE_SetScale( Tank.ScaleData )

			end

			Tank.Id           = Id
			Tank.SizeId       = Data1
			Tank.Shape 		  = "Radiator"
			Tank.Model        = Model
			Tank.Dimensions   = Dimensions

			Tank.LastMass = 1
			Tank:UpdateRadiator(Id, Data1) 

			Owner:AddCount( "_acf_misc", Tank )
			Owner:AddCleanup( "acfmenu", Tank )

			--table.insert(ACF.FuelTanks, Tank)

			return Tank
		end

		return Tank
	end
end

list.Set( "ACFCvars", "ace_radiator", {"id", "data1"} )
duplicator.RegisterEntityClass("ace_radiator", MakeACE_Radiator, "Pos", "Angle", "Id", "SizeId")


local Wall = 0.75 -- wall thickness in inches

function ENT:UpdateRadiator(_, _)

	local electric = "ups"
	local gas = "ups"
	local pct = 1 --how full is the tank?
	self.Leaking = 0


	local ModelData = ACE.ModelData[self.Shape]
	local Volumefunc = ModelData.volumefunction

	local Dimensions = self.Dimensions

	--We love rotated models.
	--Width is X
	--Thickness is y
	--Height is Z

	local Length = Dimensions.y
	local Width = Dimensions.x
	local Height = Dimensions.z

	local Volume = Volumefunc( Length, Width, Height)
	local IVolume = math.max(Volumefunc( Length, Width - (Wall * 2), Height - (Wall * 2)) * 0.7,0) --Assume 2/3rds volume radiator fins, 1/3rd water (roughly 0.7x)

	self.Volume        = IVolume-- total volume of tank (cu in), reduced by wall thickness
	self.Capacity      = IVolume * ACF.CuIToLiter * ACF.TankVolumeMul * 0.4774 --internal volume available for coolant in liters, with magic realism number
	self.EmptyMass     = (Volume - IVolume) * 16.387 * ( 2.6 / 1000 )    -- total wall volume * cu in to cc * density of aluminum (kg/cc)
	self.Coolant	= pct * self.Capacity
	self.Mass = self.EmptyMass + self.Coolant --* 1   Conversion Ommited    -- weight of tank + weight of contained water. Water is 1kg/Liter

	self:UpdateRadiatorMass()

	--Calculates the average specific heat of the object
	self.ACESpecificHeat = (self.EmptyMass * 0.9211 + self.Coolant * 4.184) / self.Mass * ACF.RadiatorHeatCap --0.9211 is the specific heat of aluminum in kj/kg * k, and 4.184 is the specific heat of water in kj/kg * k


	local x = math.Round(Length, 1) / 10
	local y = math.Round(Width, 1) / 10
	local z = math.Round(Height, 1) / 10

	self.ActiveTorqueDemand = self.Volume / 61.02 * 60 --Convert to liters. Then multiply by the amount of Joules per second it'll take to actively cool the engine per liter of radiator volume.

	--print("Horsepower required to use active cooling: " .. self.ActiveTorqueDemand / 1.3410220896 / 1000)


	local FinsPerInch = 15
	local FinPackRatio = 0.5 --Ratio of volume fins to volume air in radiator

	local FinHeight = (1/FinsPerInch) * FinPackRatio --Air/Fin ratio.

	local finSize = Length * Width * 2 + Width * FinHeight * 2 --Surface area of one fin(Top and bottom)

	local FinCount = Height / FinsPerInch

	self.ThermalSurfaceArea = finSize * FinCount / 1550 --Converts from square inches to square meters

	self.AirflowRestrictiveness = 1-(1-(1/Length))^2 --Airflow ratio of the radiator. Difficulty air flowing through it will have cooling anything.

	--Infotext moved from the overlay update. No need to recalculate this.

	local text = "\nTotal Surface Area: " .. math.Round(self.ThermalSurfaceArea,2) .. "m^2"
	text = text .. "\nAirflow Restriction: " .. math.Round((1-self.AirflowRestrictiveness)*100,1) .. "%\n"
	local HeatCapacity = self.ACESpecificHeat * self.Mass
	text = text .. "\nThermal Storage: " .. math.Round(HeatCapacity,1) .. " kJ/Deg C\n"

	local OldHeat = self.Heat
	--Bit of a hacked together way to measure the thermal dissipation rate at a given temp.
	self.Heat = 100
	ACE_AtmosphericHeatDissipation(self, self.AirflowRestrictiveness * ACF.RadiatorEff, 1)
	local Dissipation = (100 - self.Heat) * HeatCapacity  / ACF.ThermalTimeScale --Gets the heat difference in Deg/C and multiplies it by the Heat capacity of the radiator to determine the KJ dissipated
	text = text .. "\nStationary Cooling:\n" .. math.Round(Dissipation,2) .. " kJ / second @ 100 Deg C.\n"

	text = text .. "\nw/ Active:\n" .. math.Round(Dissipation*3,2) .. " kJ / second @ 100 Deg C."
	text = text .. "\nusing " .. math.Round(self.ActiveTorqueDemand / 1.3410220896 / 1000,2) .. "hp when needed\n"

	self.ActiveTorqueDemand = self.Volume / 61.02 * 30

	self.Heat = OldHeat

	self.RadiatorStats = text




	local dims = x .. "x" .. y .. "x" .. z

	local rad	= " " .. dims .. " Radiator"

	self:SetNWString( "WireName", rad )

	Wire_TriggerOutput( self, "Capacity", math.Round(self.Capacity,2) )
	self:UpdateOverlayText()

end

function ENT:UpdateOverlayText()


	local Stats

	if self.FanRunning > 0 then
		Stats = "Cooling Actively - Fan using engine power"
	else
		Stats = "Cooling Passively"
	end

	local text = "- " .. Stats .. " -\n"

	--Slot in infotext

	text = text .. self.RadiatorStats

	text = text .. "\nTemp: " .. math.Round(self.Heat) .. " °C / " .. math.Round((self.Heat * (9 / 5)) + 32) .. " °F\n"

	text = text .. "\nCurrent Coolant Remaining:"
	text = text .. "\n-  " .. math.Round( self.Coolant, 1 ) .. " / " .. math.Round( self.Capacity, 1 ) .. " liters"
	text = text .. "\n-  " .. math.Round( self.Coolant * 0.264172, 1 ) .. " / " .. math.Round( self.Capacity * 0.264172, 1 ) .. " gallons"

	if self.Leaking > 0 then
		text = text .. "\n- Leaking: " .. math.Round(self.Leaking, 1) .. " liters per second"
	end


	if not self.Legal then
		text = text .. "\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )

end

function ENT:UpdateRadiatorMass()

	self.Mass = self.EmptyMass + self.Coolant -- * 1 --Water weighs 1kg/L

	--reduce superflous engine calls, update fuel tank mass every 5 kgs change or every 10s-15s
	if math.abs(self.LastMass - self.Mass) > 5 or ACF.CurTime > self.NextMassUpdate then
		self.LastMass = self.Mass
		self.NextMassUpdate = ACF.CurTime + math.Rand(10, 15)
		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:SetMass( self.Mass )
		end
	end

	self:UpdateOverlayText()

end

function ENT:Update( ArgsTable )

	local Feedback = ""

	self:UpdateRadiator(ArgsTable[4], ArgsTable[5]) --Id, SizeId, FuelType

	return true, "Radiator successfully updated." .. Feedback
end

function ENT:TriggerInput( iname, value )

	if (iname == "ActiveCooling") then
		if value >	 0 then
			self.Active = true
		else
			self.Active = false
		end
	end

end

function ENT:Think()

	--Rapid Logic. Runs on tick. Used to not stall out the engines by pulling large chunks of power from the flywheel.
	local CT = ACF.CurTime
	local DeltaTime = CT - self.LastThink

	local ECount = #self.Master
	local PerEngineTorqueDemand = self.ActiveTorqueDemand / ECount * DeltaTime
	local DriveFactor = 0 --Active fan drive factor. Ability for engines to meet fan's torque demands.
	local RPMPulled = 1--Actual RPM Pulled from the crankshaft.
	local RPMDemand = 1--Requested RPM pulled from the crankshaft. Used to see if we meet energy demands.

	for Key in pairs(self.Master) do
		local Ent = self.Master[Key]
		if IsValid( Ent ) then
			--Active cooling. Saps a certain amount of power from the engine to drive the cooling fans
			--Activates only if needed to keep the radiator below the coolant overheating temperature.
			if self.Active then -- and self.Heat > 21
				RPMDemand = PerEngineTorqueDemand / Ent.Inertia
				local NewRPM = math.max(Ent.FlyRPM - RPMDemand, Ent.IdleRPM)
				RPMPulled = Ent.FlyRPM - NewRPM
				Ent.FlyRPM = NewRPM

				--DriveFactor = math.min(DriveFactor,math.min(RPMPulled/RPMDemand,1)) --Penalized severely if one of the engines is unable to satisfy the torque demand.
				self.FanRunning = 1
			else
				self.FanRunning = 0
			end
		end
	end



	if CT > self.NextFanLogic then

		if self.FanRunning == 1 then --The Fan is running


			if self.FanSpeed > 0 then --Fan is ramping up
				self.FanSpeed = math.min(self.FanSpeed + 0.03,1)
				if self.Sound then
					self.Sound:ChangePitch( self.SoundPitch * self.FanSpeed )
				end
			elseif self.FanSpeed == 0 then --Fan just started
				--stupid workaround for the engine sound. THANK YOU garry
				filter = RecipientFilter(true)
				filter:AddAllPlayers()

				if self.SoundPath ~= "" then
					self.Sound = CreateSound(self, self.SoundPath , filter)
					local Horsepower = 	self.ActiveTorqueDemand / 1.3410220896 / 1000

					local DB = 40 + Horsepower * 10
					self.Sound:SetSoundLevel( DB ) --Has to be adjusted before being played sadly. No dynamic DB levels.
					self.Sound:PlayEx(1.0,0)
				end

				self.FanSpeed = self.FanSpeed + 0.01
			end

		else --The cooling fan is no longer running

			if self.FanSpeed > 0 then --Fan is slowing down
				self.FanSpeed = math.max(self.FanSpeed - 0.03,0)
				if self.Sound then
					self.Sound:ChangePitch( self.SoundPitch * self.FanSpeed )
				end
			elseif self.FanSpeed == 0 then --Fan has stopped
				if self.Sound then
					self.Sound:Stop()
				end
				self.Sound = nil
			end

		end




		--Maybe later once a workaround is found
		--local sequence = self:LookupSequence("idle")
		--self:ResetSequence(sequence)
		--self:SetPlaybackRate(0)

		self.NextFanLogic = CT + 0.05
	end

	if CT > self.NextHeatLogic then
		local DeltaTime2 = CT - self.LastThink2

		--Obligatory legality Check
		if CT > self.NextLegalCheck then
			--local minmass = math.floor(self.Mass-6)  -- water is light, may as well save complexity and just check it's above empty mass
			self.Legal, self.LegalIssues = ACF_CheckLegal(self, self.Model, math.Round(self.EmptyMass,2), nil, true, true) -- mass-6, as mass update is granular to 5 kg
			self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)
			--make sure it's not made spherical
			if self.EntityMods and self.EntityMods.MakeSphericalCollisions then self.Coolant = 0 end
			self:UpdateOverlayText()
		end

		--Update the UI
			self:UpdateOverlayText()

		--Exchange heat with all linked linked engines.
		for Key in pairs(self.Master) do
			local Ent = self.Master[Key]
			if IsValid( Ent ) then
					ACE_EqualizeThermalEnergy(self, Ent)
			end
		end

		--Do the actual radiator dissipation logic
		local Speed = math.min(ACF_GetPhysicalParent(self):GetVelocity():Length() / 17.6,141) --Speed in MPH. Capped to 141mph or ~12x cooling.

		if self.Heat > 90 then --Tries to keep the loop at the ideal combustion temperature (~90C-104C). Otherwise uses slower dissipation rate.
			--Calculate the drive factor if applicable. I/E if we meet power demand. This running slowly doesn't really matter. Mostly it's to make sure underpowered engines don't run huge radiators.
			if not self.FanRunning then 
				DriveFactor = 0
			else
				DriveFactor = math.min(1,math.min(RPMPulled/RPMDemand,1)) --Penalized severely if one of the engines is unable to satisfy the torque demand.
				Speed = Speed + 64 * DriveFactor * self.FanSpeed --Add the radiator cooling fan speed. Enough for 3x base cooling when active.
				--print(Speed)
			end
		
			local CoolingMult = 1 * 2^(Speed/40) --The cooling of radiators doubles every 40mph of speed
			ACE_AtmosphericHeatDissipation(self, CoolingMult  * self.AirflowRestrictiveness * ACF.RadiatorEff, DeltaTime2)
		else
			local CoolingMult = 0.1 * 2^(Speed/40) --The cooling of radiators doubles every 40mph of speed
			ACE_AtmosphericHeatDissipation(self, CoolingMult  * self.AirflowRestrictiveness * ACF.RadiatorEff, DeltaTime2)
		end

		Wire_TriggerOutput( self, "Temperature", self.Heat )
		Wire_TriggerOutput( self, "FanRunning", self.FanRunning )

		self.LastThink2 = CT --Used for heat deltatime
		self.NextHeatLogic = CT + 0.25 --Executes heat logic every 0.5 seconds.
	end



	self.LastThink = CT

	self:NextThink( CT )
	return true

end

function ENT:OnRemove()

	for Key in pairs(self.Master) do
		if IsValid( self.Master[Key] ) then
			self.Master[Key]:Unlink( self )
		end
	end

end

function ENT:OnRemove()
	if self.Sound then
		self.Sound:Stop()
	end
end