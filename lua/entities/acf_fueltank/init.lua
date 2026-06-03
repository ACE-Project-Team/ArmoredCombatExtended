AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

--don't forget:
--armored tanks

local TankTable = ACF.Weapons.FuelTanksSize

do

	local FueltankWireDescs = {
		--Inputs
		["Refuel"]	= "Supply mode: wirelessly tops up other ACTIVE, same-type tanks in range (idle if none qualify).",

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
		self.Active           = false
		self.SupplyFuel       = false
		self.Leaking          = 0
		self.NextLegalCheck   = ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max) -- give any spawning issues time to iron themselves out
		self.Legal            = true
		self.LegalIssues      = ""

		-- Keep wire NAMES short (the wiring tool shows the name; a long one runs off
		-- screen) and pass the long text as the separate DESCRIPTIONS argument.
		self.Inputs = Wire_CreateInputs( self,
			{ "Active", "Refuel Duty" },
			{ "Switches this tank into the system (1 = on). Inactive tanks neither supply nor accept.",
			  FueltankWireDescs["Refuel"] }
		)
		self.Outputs = WireLib.CreateSpecialOutputs( self,
			{ "Fuel", "Capacity", "Leaking", "State", "Battery Health", "Temperature", "Power", "Entity" },
			{ "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "NORMAL", "ENTITY" },
			{ FueltankWireDescs["Fuel"], FueltankWireDescs["Capacity"], FueltankWireDescs["Leaking"],
			  "Battery: 0 idle, 1 charging, 2 discharging, 3 both",
			  "Battery: % of design capacity",
			  "Battery temperature, C",
			  "Battery net kW: + charging, - discharging",
			  "This entity" }
		)
		Wire_TriggerOutput( self, "Leaking", 0 )
		Wire_TriggerOutput( self, "Entity", self )

		-- Battery wear state, only used by Electric tanks (see InitBattery).
		-- Deliberately NOT persisted through duplication: a freshly built copy
		-- gets a brand-new battery, which is what players expect.
		self.BattHealth     = 1
		self.BattCycles     = 0
		self.BattThroughput = 0
		self.PendingHeatJ   = 0
		self.BattState      = 0      -- 0 idle, 1 charging, 2 discharging, 3 both
		self.BattInTick     = 0      -- energy charged in (kWh) accumulated this think
		self.BattOutTick    = 0      -- energy delivered out (kWh) accumulated this think
		self.BattNetKW      = 0      -- net power (+ charging, - discharging)

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

		-- Fuel tanks / batteries may scale smaller than ammo crates (down to 1x1x1)
		-- so you can build a tiny battery; its overlay auto-switches kWh -> Wh.
		local MinSize = ACF.SustainMinimumSize or ACF.CrateMinimumSize
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
		Scale = ClampScale( Scale )

		return Scale
	end

	function MakeACF_FuelTank(Owner, Pos, Angle, Id, Data1, Data2, Data3, Data4)

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
			if not ACE_CheckFuelTank( Data1 ) then

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

			if ACE_CheckFuelTank( Data1 ) then

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

			local forceEmpty = GetConVar("acf_fueltank_forceempty")
			if Data4 == "1" or (forceEmpty and forceEmpty:GetBool()) then
				Tank.Fuel = 0
				Tank:UpdateFuelMass()
			end

			Owner:AddCount( "_acf_misc", Tank )
			Owner:AddCleanup( "acfmenu", Tank )

			table.insert(ACF.FuelTanks, Tank)

			return Tank
		end

		return Tank
	end
end

list.Set( "ACFCvars", "acf_fueltank", {"id", "data1", "data2", "data3", "data4"} )
duplicator.RegisterEntityClass("acf_fueltank", MakeACF_FuelTank, "Pos", "Angle", "Id", "SizeId", "FuelType", "Shape", "SpawnEmpty" )


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
	-- A "Universal" tank is typeless until something fills it, then it takes on
	-- that fuel's type; once drained it reverts to Universal (see AddFuel/Think).
	self.IsUniversal   = (Data2 == "Universal")
	self.IsExplosive   = self.FuelType ~= "Electric" and false or true
	self.NoLinks       = TankData and (TankData.nolinks == true) or false

	if self.FuelType == "Electric" then
		self.Liters   = self.Capacity --batteries capacity is different from internal volume
		self.Capacity = self.Capacity * ACF.LiIonED  --full design capacity (kWh)
		self:InitBattery()                            --applies wear -> usable Capacity
		self.Fuel     = pct * self.Capacity
	elseif self.IsUniversal then
		self.Fuel	= 0   -- typeless tanks always start empty; they assign on first fill
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
		text = text .. "\n-  " .. ACE.FormatEnergy( self.Fuel ) .. " / " .. ACE.FormatEnergy( self.Capacity )
		text = text .. "\n-  " .. math.Round( self.Fuel * 3.6, 1 ) .. " / " .. math.Round( self.Capacity * 3.6, 1) .. " MJ"
		text = text .. "\nBattery Health: " .. math.Round( (self.BattHealth or 1) * 100, 1 ) .. "%  (" .. math.Round( self.BattCycles or 0, 0 ) .. " cycles)"
		text = text .. "\nTemp: " .. math.Round( self.Heat or (ACE.AmbientTemp or 20), 0 ) .. " C"
		local stName = ({ [0] = "Idle", [1] = "Charging", [2] = "Discharging", [3] = "Charging & discharging" })[self.BattState or 0] or "Idle"
		text = text .. "\n" .. stName
		if math.abs(self.BattNetKW or 0) > 0.01 then
			text = text .. "  (" .. (self.BattNetKW > 0 and "+" or "") .. math.Round(self.BattNetKW, 1) .. " kW)"
		end
		-- Show the heat-derated rate cap so players see why a hot battery slows down.
		local rateCap = (self.BattMaxRate or 0) * ACE.Sustain.Battery.RateDerate(self.Heat or 20)
		text = text .. "\nMax rate: " .. math.Round(rateCap, 1) .. " kW"
		if rateCap < (self.BattMaxRate or 0) - 0.05 then
			text = text .. " (hot - derated from " .. math.Round(self.BattMaxRate or 0, 1) .. ")"
		end

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

--[[----------------------------------------------------------------
	Battery behaviour (Electric tanks only)

	Electric fuel tanks are Li-Ion batteries: they have a charge-rate cap,
	round-trip losses, and wear (capacity fades with cycles). The pure logic
	lives in ACE.Sustain.Battery; these methods bind it to the tank's own
	self.Fuel (charge) / self.Capacity (usable) fields so the rest of the
	fuel-tank code keeps working unchanged.
]]------------------------------------------------------------------
function ENT:InitBattery()
	self.BattBaseCapacity = self.Capacity                         -- design capacity (kWh)
	self.BattHealth       = self.BattHealth or 1
	self.BattCycles       = self.BattCycles or 0
	self.BattThroughput   = self.BattThroughput or 0
	self.BattMaxRate      = self.BattBaseCapacity * (ACF.BatteryChargeRateC or 2)  -- kW cap
	self.Capacity         = self.BattBaseCapacity * self.BattHealth  -- usable after wear
	self.Heat             = self.Heat or (ACE.AmbientTemp or 20)
	self.PendingHeatJ     = self.PendingHeatJ or 0
	self.GridSourceEff    = ACF.BatteryChargeEff or 0.95   -- one-way discharge eff (grid grosses up by it)
end

-- Run one battery step (requestKWh: + charge / - discharge) and write the
-- mutated state back onto the tank. Heat is buffered and applied in Think.
function ENT:BattStep(requestKWh, dt)
	local s = {
		baseCapacity  = self.BattBaseCapacity,
		capacity      = self.Capacity,
		charge        = self.Fuel,
		health        = self.BattHealth,
		cycleCount    = self.BattCycles,
		throughput    = self.BattThroughput,
		-- Charge/discharge power cap = this battery's own C-rate, reduced as it
		-- heats up (a hot battery cannot move power as fast). No wire override:
		-- when one battery charges another, THIS (the moving) battery's derated
		-- rate is what limits the transfer.
		maxChargeRate = self.BattMaxRate * ACE.Sustain.Battery.RateDerate(self.Heat or 20),
	}

	local r = ACE.Sustain.Battery.Step(s, requestKWh, dt, {
		chargeEff       = ACF.BatteryChargeEff,
		degradePerCycle = ACF.BatteryDegradePerCycle,
	})

	self.Capacity       = s.capacity
	self.Fuel           = s.charge
	self.BattHealth     = s.health
	self.BattCycles     = s.cycleCount
	self.BattThroughput = s.throughput
	self.PendingHeatJ   = (self.PendingHeatJ or 0) + (r.heatAddJ or 0)

	return r
end

-- Charge from an external source. Returns energy consumed at the terminals
-- (kWh) so the caller can debit exactly that from its supply.
function ENT:ChargeBattery(energyKWh, dt)
	-- Active means the battery is switched into the electrical system. An inactive
	-- battery is electrically disconnected: it can neither be charged nor drawn from.
	if self.FuelType ~= "Electric" or not self.Legal or not self.Active then return 0 end
	if energyKWh <= 0 then return 0 end
	local r = self:BattStep(energyKWh, dt)
	self.BattInTick = (self.BattInTick or 0) + (r.terminal or 0)   -- for the State/Power outputs
	return r.terminal or 0
end

-- Max TERMINAL energy (kWh) this battery would actually accept as charge this
-- tick: 0 when it's disconnected (inactive), full, or non-electric; otherwise the
-- lesser of its (heat-derated, CV-tapered) charge-rate cap and the headroom left.
-- A charger (e.g. a sink Transfer Station) sizes its grid pull to this so it never
-- drains the grid for energy the battery can't store (which would just vanish).
function ENT:ChargeHeadroom(dt)
	if self.FuelType ~= "Electric" or not self.Legal or not self.Active then return 0 end
	dt = dt or 0
	local cap = self.Capacity or 0
	if dt <= 0 or cap <= 0 then return 0 end

	local Battery = ACE.Sustain.Battery
	local maxStep = (self.BattMaxRate or 0) * Battery.RateDerate(self.Heat or 20) * dt / 3600

	-- Charge tapers above the CV threshold (the "slows after ~80%" effect).
	local soc = (self.Fuel or 0) / cap
	if soc > Battery.CVThreshold then
		local f = (1 - soc) / math.max(1 - Battery.CVThreshold, 1e-6)
		f = math.Clamp(f, Battery.CVMinRate, 1)
		maxStep = maxStep * f
	end

	-- Terminal energy needed to fill the remaining room (grossed up by charge eff).
	local eff  = ACF.BatteryChargeEff or 0.95
	local room = (eff > 0) and ((cap - (self.Fuel or 0)) / eff) or (cap - (self.Fuel or 0))
	return math.max(math.min(maxStep, room), 0)
end

-- Discharge to an external load. Returns energy delivered (kWh).
function ENT:DrawEnergy(wantKWh, dt)
	if self.FuelType ~= "Electric" or not self.Legal or not self.Active then return 0 end
	if wantKWh <= 0 or self.Fuel <= 0 then return 0 end
	local r = self:BattStep(-wantKWh, dt)
	self.BattOutTick = (self.BattOutTick or 0) + (r.delivered or 0)   -- for the State/Power outputs
	return r.delivered or 0
end

-- True if this tank can receive `srcType` liquid: same type, or a still-empty
-- Universal tank (which will take on that type), and never Electric/Oil mismatch.
function ENT:CanReceiveFuel(srcType)
	if not srcType or srcType == "Electric" or not self.Legal then return false end
	if self.FuelType == srcType then return true end
	if self.IsUniversal and self.FuelType == "Universal" then return true end
	return false
end

-- Add liquid fuel (litres). Returns litres accepted. Electric tanks use
-- ChargeBattery instead. If a Universal tank is still typeless, the supplier's
-- fuel type (srcType) assigns it.
function ENT:AddFuel(liters, srcType)
	if self.FuelType == "Electric" or not self.Legal then return 0 end
	if liters <= 0 then return 0 end

	-- Auto-assign a typeless Universal tank to whatever is filling it.
	if self.IsUniversal and self.FuelType == "Universal" and srcType
		and srcType ~= "Universal" and srcType ~= "Electric" then
		self.FuelType = srcType
		self:SetNWString("WireName", "ACE " .. srcType .. " (Universal) Fuel Tank")
	end

	local room = self.Capacity - self.Fuel
	if room <= 0 then return 0 end
	local add = math.min(liters, room)
	self.Fuel = self.Fuel + add
	self:UpdateFuelMass()
	return add
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
		if value ~= 0 then
			self.Active = true
		else
			self.Active = false
		end
	elseif iname == "Refuel Duty" then
		if value ~= 0 then
			self.SupplyFuel = true
		else
			self.SupplyFuel = false
		end
	end

end

function ENT:Think()

	if ACF.CurTime > self.NextLegalCheck then
		--local minmass = math.floor(self.Mass-6)  -- fuel is light, may as well save complexity and just check it's above empty mass
		self.Legal, self.LegalIssues = ACF_CheckLegal(self, self.Model, math.Round(self.EmptyMass,2), nil, true, true) -- mass-6, as mass update is granular to 5 kg
		self.NextLegalCheck = ACF.Legal.NextCheck(self.legal)
		self:UpdateOverlayText()
	end

	--make sure it's not made spherical
	if self.EntityMods and self.EntityMods.MakeSphericalCollisions then self.Fuel = 0 end

	local dt = CurTime() - (self.LastThink or CurTime())
	local isBattery = self.FuelType == "Electric"

	-- A Universal tank that's been drained dry reverts to typeless, ready to take
	-- on a different fuel next time it's filled.
	if self.IsUniversal and self.FuelType ~= "Universal" and (self.Fuel or 0) <= 0.01 then
		self.FuelType = "Universal"
		self:SetNWString("WireName", "ACE Universal Fuel Tank")
		self:UpdateOverlayText()
	end

	if self.Leaking > 0 then
		self:NextThink( CurTime() + 0.25 )
		self.Fuel = math.max(self.Fuel - self.Leaking,0)
		self.Leaking = math.Clamp(self.Leaking - (1 / math.max(self.Fuel,1)) ^ 0.5, 0, self.Fuel) --fuel tanks are self healing
		Wire_TriggerOutput(self, "Leaking", (self.Leaking > 0) and 1 or 0)
	else
		self:NextThink( CurTime() + (isBattery and 0.5 or 1) )
	end

	--[[ Wireless (radius) charging.
		Liquid fuel tanks no longer auto-refuel by radius - use a fuel
		plug/socket. Batteries keep wireless charging for convenience, but
		it is deliberately slow and lossy (penalised) so a physical plug is
		always the better option for serious logistics. ]]
	if isBattery and self.Active and self.SupplyFuel and self.Fuel > 0 and self.Legal then
		self:NextThink(CurTime())
		local want = (ACF.BatteryRadiusRate or 0.5) * dt / 3600  -- kWh budget this tick

		for _, Tank in pairs(ACF.FuelTanks) do
			if want <= 0 then break end
			-- Receiver must be a different, legal Electric tank that is itself
			-- ACTIVE (electrically connected) and is NOT also in supply mode.
			-- Skipping inactive tanks here is what stops this battery from
			-- "discharging" (state/sound) into a tank that can't accept charge.
			if Tank == self or Tank.FuelType ~= "Electric" or Tank.SupplyFuel or not Tank.Legal or not Tank.Active then continue end
			if (Tank.Capacity - Tank.Fuel) <= 0.01 then continue end
			if self:GetPos():Distance(Tank:GetPos()) >= ACF.RefillDistance then continue end

			local drawn = self:DrawEnergy(want, dt)
			if drawn <= 0 then continue end
			want = want - drawn

			-- Penalty: only a fraction of the drawn energy actually lands.
			local delivered = drawn * (ACF.BatteryRadiusPenalty or 0.35)
			Tank:ChargeBattery(delivered, dt)

			if CurTime() > (Tank.NextSoundTime or 0) then
				sound.Play("ambient/energy/newspark04.wav", Tank:GetPos(), 75, 100, 0.5)
				Tank.NextSoundTime = CurTime() + 1
			end
		end
	end

	-- Wireless (radius) refuel for LIQUID supply tanks: tops up nearby same-type
	-- active tanks, slower than a plug (ACF.FuelRadiusRate). Mirrors the battery
	-- branch above but moves litres instead of kWh.
	if not isBattery and self.Active and self.SupplyFuel and (self.Fuel or 0) > 0 and self.Legal then
		self:NextThink(CurTime())
		local budget = (ACF.FuelRadiusRate or 4) * dt   -- litres this tick

		for _, Tank in pairs(ACF.FuelTanks) do
			if budget <= 0 or (self.Fuel or 0) <= 0 then break end
			if Tank == self or Tank.FuelType == "Electric" or Tank.SupplyFuel or not Tank.Legal or not Tank.Active then continue end
			if not (Tank.CanReceiveFuel and Tank:CanReceiveFuel(self.FuelType)) then continue end
			local room = (Tank.Capacity or 0) - (Tank.Fuel or 0)
			if room <= 0.01 then continue end
			if self:GetPos():Distance(Tank:GetPos()) >= ACF.RefillDistance then continue end

			local amount = math.min(budget, self.Fuel, room)
			if amount <= 0 then continue end
			self.Fuel = self.Fuel - amount
			if self.UpdateFuelMass then self:UpdateFuelMass() end
			Tank:AddFuel(amount, self.FuelType)
			budget = budget - amount

			if CurTime() > (Tank.NextSoundTime or 0) then
				sound.Play("ambient/water/water_spray" .. math.random(1, 2) .. ".wav", Tank:GetPos(), 65, 105, 0.4)
				Tank.NextSoundTime = CurTime() + 1
			end
		end
	end

	-- Publish wireless-supply status for the ACE Conduit overlay.
	self:SetNWBool("AceSupplying", (self.SupplyFuel and self.Active and (self.Fuel or 0) > 0) or false)

	-- Apply buffered battery heat (charge/discharge losses) and dissipate, then
	-- publish the battery's activity (state + net power + health + temp).
	if isBattery then
		local ambient = ACE.AmbientTemp or 20
		self.Heat = ACE.Sustain.Heat.HeatStep(self.Heat or ambient, self.PendingHeatJ or 0, self.Mass, 1, ambient, dt)
		self.PendingHeatJ = 0

		local inE  = self.BattInTick or 0
		local outE = self.BattOutTick or 0
		self.BattInTick, self.BattOutTick = 0, 0
		local st = 0
		if inE > 0 and outE > 0 then st = 3
		elseif inE > 0 then st = 1
		elseif outE > 0 then st = 2 end
		self.BattState = st
		self.BattNetKW = (inE - outE) / math.max(dt / 3600, 1e-9)

		Wire_TriggerOutput(self, "State", st)
		Wire_TriggerOutput(self, "Battery Health", math.Round((self.BattHealth or 1) * 100, 1))
		Wire_TriggerOutput(self, "Temperature", math.Round(self.Heat or ambient, 1))
		Wire_TriggerOutput(self, "Power", math.Round(self.BattNetKW, 2))
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
