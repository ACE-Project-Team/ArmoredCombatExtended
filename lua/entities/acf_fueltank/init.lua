AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

--don't forget:
--armored tanks

local TankTable = ACF.Weapons.FuelTanksSize

do

	local FueltankWireDescs = {
		--Inputs
		["Refuel"]	= "Allows to this tank to supply other fuel tanks.\n Fuel type must be equal to the tank which you want to supply.",

		--Outputs
		["Fuel"]        = "Returns the current fuel level.",
		["Capacity"]    = "Returns the max capacity of this fuel tank.",
		["Leaking"]     = "Is the fuel tank leaking?"
	}

	function ENT:Initialize()

		self.CanUpdate        = true
		self.SpecialHealth    = true  --If true, use the ACF_Activate function defined by this ent
		self.SpecialDamage    = true  --If true, use the ACF_OnDamage function defined by this ent
		self.IsExplosive      = true
		self.Exploding        = false

		self.Size             = 0	--outer dimensions
		self.Volume           = 0	--total internal volume in cubic inches
		self.Capacity         = 0	--max fuel capacity in liters
		self.Fuel             = 0	--current fuel level in liters
		self.FuelType         = nil
		self.EmptyMass        = 0	--mass of tank only
		self.NextMassUpdate   = 0
		self.Id               = nil	--model id
		self.Active           = true
		self.SupplyFuel       = false
		self.Leaking          = 0
		self.NextLegalCheck   = ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
		self.Legal            = true
		self.LegalIssues      = ""

		self.Inputs = Wire_CreateInputs( self, { "Active", "Refuel Duty (" .. FueltankWireDescs["Refuel"] .. ")" } )
		self.Outputs = WireLib.CreateSpecialOutputs( self,
			{ "Fuel (" .. FueltankWireDescs["Fuel"] .. ")", "Capacity (" .. FueltankWireDescs["Capacity"] .. ")", "Leaking (" .. FueltankWireDescs["Leaking"] .. ")", "Entity" },
			{ "NORMAL", "NORMAL", "NORMAL", "ENTITY" }
		)
		ACF.GetDefaultActiveInputState(self)
		Wire_TriggerOutput( self, "Leaking", 0 )
		Wire_TriggerOutput( self, "Entity", self )

		self.Master = {} --engines linked to this tank
		ACF.FuelTanks = ACF.FuelTanks or {} --master list of acf fuel tanks

		self.LastThink = 0
		self.NextThink = CurTime() +  1

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
	local Health = (self.ACF.Volume / ACF.Threshold) * 0.5					--Setting the threshold of the prop Area gone

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
	self:UpdateFuelMass()

end

function ENT:ACF_OnDamage( Entity, Energy, FrArea, Angle, Inflictor, _, Type )	--This function needs to return HitRes

	local Mul = (((Type == "HEAT" or Type == "THEAT" or Type == "HEATFS" or Type == "THEATFS") and ACF.HEATMulFuel) or 1) --Heat penetrators deal bonus damage to fuel
	local HitRes = ACF_PropDamage( Entity, Energy, FrArea * Mul, Angle, Inflictor ) --Calling the standard damage prop function

	local NoExplode = self.FuelType == "Diesel" and not (Type == "HE" or Type == "HEAT" or Type == "THEAT" or Type == "HEATFS" or Type == "THEATFS")
	if self.Exploding or NoExplode or not self.IsExplosive then return HitRes end

	if HitRes.Kill then

		if hook.Run( "ACF_FuelExplode", self ) == false then return HitRes end

		self.Exploding = true

		if IsValid(Inflictor) and Inflictor:IsPlayer() then
			self.Inflictor = Inflictor
		end

		ACF_ScaledExplosion( self , true )

		return HitRes
	end

	local Ratio = (HitRes.Damage / self.ACF.Health) ^ 0.75 --chance to explode from sheer damage, small shots = small chance
	local ExplodeChance = (1-(self.Fuel / self.Capacity)) ^ 0.75 --chance to explode from fumes in tank, less fuel = more explodey

	--it's gonna blow
	if math.Rand(0, 1.2) < (ExplodeChance + Ratio) then

		if hook.Run( "ACF_FuelExplode", self ) == false then return HitRes end

		self.Inflictor = Inflictor
		self.Exploding = true

		timer.Simple(math.Rand(0.1, 1), function()
			if IsValid(self) then
				ACF_ScaledExplosion( self , true )
			end
		end )

	else												--spray some fuel around
		self:NextThink( CurTime() + 0.1 )
		if self.FuelType ~= "Electric" then
			self.Leaking = self.Leaking + self.Fuel * ((HitRes.Damage / self.ACF.Health) ^ 1.5) * 0.25
		end
	end

	return HitRes

end

do

	-- Parses + clamps an "L:W:H" string into a Vector. Shared with ammo crates and
	-- scalable explosives (see ACE.Scalable.ParseScale); fuel tanks pass the crate
	-- size limits as their bounds.
	local function ConvertStringScale( ScaleId )
		return ACE.Scalable.ParseScale( ScaleId, { min = ACF.CrateMinimumSize, max = ACF.CrateMaximumSize } )
	end

	function MakeACF_FuelTank(Owner, Pos, Angle, Id, Data1, Data2, Data3)

		if IsValid(Owner) and not Owner:CheckLimit("_acf_misc") then return false end

		local Tank = ents.Create("acf_fueltank")
		if IsValid(Tank) then

			local Model
			local Dimensions

			Tank:CPPISetOwner(Owner)
			Tank:SetAngles(Angle)
			Tank:SetPos(Pos)
			Tank:Spawn()

			-- If the crate is not valid in the system, but it could be scalable.
			if not ACE.CheckFuelTank( Data1 ) then

				-- Reminder: When the legacy fueltanks get deleted. Do the same as ammo crates.
				local Scale = ConvertStringScale(Data1)

				if isvector(Scale) then

					local ModelData = ACE.ModelData[Data3]

					Data1 = Scale
					Model = ModelData.Model
					Weight = (Scale.x * Scale.y * Scale.z) / 200
					Dimensions = Scale

					local DefaultSize    = ModelData.DefaultSize
					local Mesh           = ModelData.CustomMesh
					local PhysMaterial   = ModelData.physMaterial
					local EntityScale    = Vector(Scale.x / DefaultSize, Scale.y / DefaultSize, Scale.z / DefaultSize)

					Tank.ScaleData = {
						Mesh = Mesh,
						Scale = EntityScale,
						Size = DefaultSize,
						Material = PhysMaterial,
					}

					Tank:SetMaterial("phoenix_storms/gear")
					Tank:SetModel( Model ) --Sending the model to client
					Tank:PhysicsInit( SOLID_VPHYSICS )
					Tank:SetMoveType( MOVETYPE_VPHYSICS )
					Tank:SetSolid( SOLID_VPHYSICS )

					Tank.IsScalable = true
					Tank:ACE_SetScale( Tank.ScaleData )

				else
					Data1 = "Tank_4x4x2"
				end
			end

			if ACE.CheckFuelTank( Data1 ) then

				local TankData = TankTable[Data1]

				Model = TankData.model
				Weight = TankData.weight

				Tank:SetModel( Model )
				Tank:PhysicsInit( SOLID_VPHYSICS )
				Tank:SetMoveType( MOVETYPE_VPHYSICS )
				Tank:SetSolid( SOLID_VPHYSICS )

			end

			Tank.Id           = Id
			Tank.SizeId       = Data1
			Tank.Shape 		  = Data3
			Tank.Model        = Model
			Tank.Dimensions   = Dimensions

			Tank.LastMass = 1
			Tank:UpdateFuelTank(Id, Data1, Data2)

			Owner:AddCount( "_acf_misc", Tank )
			Owner:AddCleanup( "acfmenu", Tank )

			table.insert(ACF.FuelTanks, Tank)

			return Tank
		end

		return Tank
	end
end

list.Set( "ACFCvars", "acf_fueltank", {"id", "data1", "data2", "data3"} )
duplicator.RegisterEntityClass("acf_fueltank", MakeACF_FuelTank, "Pos", "Angle", "Id", "SizeId", "FuelType", "Shape" )


local Wall = 0.03937 --wall thickness in inches (1mm)

function ENT:UpdateFuelTank(_, _, Data2)

	local electric = "ups"
	local gas = "ups"
	local TankData = TankTable[self.SizeId]
	local pct = 1 --how full is the tank?

	if self.Capacity and self.Capacity ~= 0 then --if updating existing tank, keep fuel level
		pct = self.Fuel / self.Capacity
	end

	if self.IsScalable then

		local ModelData = ACE.ModelData[self.Shape]
		local Volumefunc = ModelData.volumefunction

		local Dimensions = self.Dimensions

		local Length = Dimensions.x
		local Width = Dimensions.y
		local Height = Dimensions.z

		local Volume = Volumefunc( Length, Width, Height)
		local IVolume = Volumefunc( Length - (Wall * 2), Width - (Wall * 2), Height - (Wall * 2))

		self.Volume        = IVolume-- total volume of tank (cu in), reduced by wall thickness
		self.Capacity      = IVolume * ACF.CuIToLiter * ACF.TankVolumeMul * 0.4774 --internal volume available for fuel in liters, with magic realism number
		self.EmptyMass     = (Volume - IVolume) * 16.387 * ( 7.9 / 1000 )    -- total wall volume * cu in to cc * density of steel (kg/cc)

		local x = math.Round(Length, 1) / 10
		local y = math.Round(Width, 1) / 10
		local z = math.Round(Height, 1) / 10

		local dims = x .. "x" .. y .. "x" .. z

		electric = (Data2 == "Electric") and dims .. " Li-Ion Battery"
		gas	= Data2 .. " " .. dims .. " Fuel Tank"

	else
		local PhysObj    = self:GetPhysicsObject()
		local Area       = PhysObj:GetSurfaceArea()
		local Volume     = PhysObj:GetVolume()

		self.Volume        = Volume - (Area * Wall) -- total volume of tank (cu in), reduced by wall thickness
		self.Capacity      = self.Volume * ACF.CuIToLiter * ACF.TankVolumeMul * 0.4774 --internal volume available for fuel in liters, with magic realism number
		self.EmptyMass     = (Area * Wall) * 16.387 * (7.9 / 1000)  -- total wall volume * cu in to cc * density of steel (kg/cc)

		electric = (Data2 == "Electric") and TankData.name .. " Li-Ion Battery"
		gas	= Data2 .. " " .. TankData.name .. ( not TankData.notitle and " Fuel Tank" or "")
	end

	self.FuelType      = Data2
	self.IsExplosive   = self.FuelType ~= "Electric" and false or true
	self.NoLinks       = TankData and (TankData.nolinks == true) or false

	if self.FuelType == "Electric" then
		self.Liters   = self.Capacity --batteries capacity is different from internal volume
		self.Capacity = self.Capacity * ACF.LiIonED
		self.Fuel     = pct * self.Capacity
	else
		self.Fuel	= pct * self.Capacity
	end

	self:UpdateFuelMass()

	local name = "ACE " .. (electric or gas)

	self:SetNWString( "WireName", name )

	Wire_TriggerOutput( self, "Capacity", math.Round(self.Capacity,2) )
	self:UpdateOverlayText()

end

function ENT:UpdateOverlayText()


	local Stats

	if self.Active then
		Stats = "In use"
	else
		Stats = "Not In use"
	end

	local text = "- " .. Stats .. " -\n"

	if self.FuelType == "Electric" then

		text = text .. "\nCurrent Charge Level:"
		text = text .. "\n-  " .. math.Round( self.Fuel, 1 ) .. " / " .. math.Round( self.Capacity, 1 ) .. " kWh"
		text = text .. "\n-  " .. math.Round( self.Fuel * 3.6, 1 ) .. " / " .. math.Round( self.Capacity * 3.6, 1) .. " MJ"

	else

		text = text .. "\nCurrent Fuel Remaining:"
		text = text .. "\n-  " .. math.Round( self.Fuel, 1 ) .. " / " .. math.Round( self.Capacity, 1 ) .. " liters"
		text = text .. "\n-  " .. math.Round( self.Fuel * 0.264172, 1 ) .. " / " .. math.Round( self.Capacity * 0.264172, 1 ) .. " gallons"

		--text = text .. "\nFuel Remaining: " .. math.Round( self.Fuel, 1 ) .. " liters / " .. math.Round( self.Fuel * 0.264172, 1 ) .. " gallons"

		if self.Leaking > 0 then
			text = text .. "\n- Leaking: " .. math.Round(self.Leaking, 1) .. " liters per second"
		end
	end

	if not self.Legal then
		text = text .. "\nNot legal, disabled for " .. math.ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText( text )

end

function ENT:UpdateFuelMass()

	if self.FuelType == "Electric" then
		self.Mass = self.EmptyMass + self.Liters * ACF.FuelDensity[self.FuelType]
	else
		local FuelMass = self.Fuel * ACF.FuelDensity[self.FuelType]
		self.Mass = self.EmptyMass + FuelMass
	end

	--reduce superflous engine calls, update fuel tank mass every 5 kgs change or every 10s-15s
	if math.abs(self.LastMass - self.Mass) > 5 or CurTime() > self.NextMassUpdate then
		self.LastMass = self.Mass
		self.NextMassUpdate = CurTime() + math.Rand(10, 15)
		local phys = self:GetPhysicsObject()
		if (phys:IsValid()) then
			phys:SetMass( self.Mass )
		end
	end

	self:UpdateOverlayText()

end

function ENT:Update( ArgsTable )

	local Feedback = ""

	if ( ArgsTable[6] ~= self.FuelType ) then
		for _, Engine in pairs( self.Master ) do
			if Engine:IsValid() then
				Engine:Unlink( self )
			end
		end
		Feedback = " New fuel type loaded, fuel tank unlinked."
	end

	self:UpdateFuelTank(ArgsTable[4], ArgsTable[5], ArgsTable[6]) --Id, SizeId, FuelType

	return true, "Fuel tank successfully updated." .. Feedback
end

function ENT:TriggerInput( iname, value )

	if (iname == "Active") then
		self.Active = ACF.GetDefaultActiveInputState(self, value)

		self:UpdateOverlayText()
	elseif iname == "Refuel Duty" then
		if value ~= 0 then
			self.SupplyFuel = true
		else
			self.SupplyFuel = false
		end
	end

end

function ENT:Think()

	if not ACF.IsDefaultActiveInputWired(self) then
		self.Active = true
	end

	if ACF.CurTime > self.NextLegalCheck then
		--local minmass = math.floor(self.Mass-6)  -- fuel is light, may as well save complexity and just check it's above empty mass
		self.Legal, self.LegalIssues = ACF_CheckLegal(self, self.Model, math.Round(self.EmptyMass,2), nil, true, true) -- mass-6, as mass update is granular to 5 kg
		self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)
		self:UpdateOverlayText()
	end

	--make sure it's not made spherical
	if self.EntityMods and self.EntityMods.MakeSphericalCollisions then self.Fuel = 0 end

	if self.Leaking > 0 then
		self:NextThink( CurTime() + 0.25 )
		self.Fuel = math.max(self.Fuel - self.Leaking,0)
		self.Leaking = math.Clamp(self.Leaking - (1 / math.max(self.Fuel,1)) ^ 0.5, 0, self.Fuel) --fuel tanks are self healing
		Wire_TriggerOutput(self, "Leaking", (self.Leaking > 0) and 1 or 0)
	else
		self:NextThink( CurTime() + 1 )
	end

	--refuelling
	if self.Active and self.SupplyFuel and self.Fuel > 0 and self.Legal then
		self:NextThink(CurTime())
		for _,Tank in pairs(ACF.FuelTanks) do

			if self.FuelType == Tank.FuelType and not Tank.SupplyFuel and Tank.Legal then --don't refuel the refuellers, otherwise it'll be one big circlejerk
				local dist = self:GetPos():Distance(Tank:GetPos())

				if dist < ACF.RefillDistance and (Tank.Capacity - Tank.Fuel > 0.1) then
					local exchange = ((self.FuelType == "Electric") and 1 or 15) / 200
					exchange = math.min(exchange, self.Fuel, Tank.Capacity - Tank.Fuel)
					self.Fuel = self.Fuel - exchange
					Tank.Fuel = Tank.Fuel + exchange

					if Tank.FuelType == "Electric" then
						if not Tank.PlayedSound and CurTime() > (Tank.NextSoundTime or 0) then
							sound.Play("ambient/energy/newspark04.wav", Tank:GetPos(), 75, 100, 0.5)
							Tank.PlayedSound = true
							Tank.NextSoundTime = CurTime() + 1 -- Adjust the delay time (in seconds) as needed
						end
					else
						if CurTime() > (Tank.NextSoundTime or 0) then
							sound.Play("vehicles/jetski/jetski_no_gas_start.wav", Tank:GetPos(), 75, 120, 0.5)
							Tank.NextSoundTime = CurTime() + 1 -- Adjust the delay time (in seconds) as needed
						end
					end
				end
			end
		end
	end

	self:UpdateFuelMass()

	Wire_TriggerOutput(self, "Fuel", self.Fuel)

	self.LastThink = CurTime()

	return true

end

function ENT:OnRemove()

	for Key in pairs(self.Master) do
		if IsValid( self.Master[Key] ) then
			self.Master[Key]:Unlink( self )
		end
	end

	if #ACF.FuelTanks > 0 then
		for k,v in pairs(ACF.FuelTanks) do
			if v == self then
				table.remove(ACF.FuelTanks,k)
			end
		end
	end

end
