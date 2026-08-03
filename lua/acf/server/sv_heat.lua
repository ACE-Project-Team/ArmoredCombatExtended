--Every funciton will return Heat. The only difference is how the Heat is created from
--VERY IMPORTANT: If ACF3 changed some of their functions/value names, then it would be required to check this code below too.

-----------------------------------[ HEAT PARAMETERS ]-----------------------------------


------Ambient Temperature. Engine Heat will not be lower than this. In Celcius.
	ACE.AmbientTemp = 20

------How much the distance affects Heat detection for IR seeker? Higher => Less Heat detected at distant targets - Def: 1
	ACE.HeatDistanceLoss = 0.5

----------------------------------------------------------------------------------------/
----------------------------------------------------------------------------------------/
------------------------------------/FUNCTIONS BELOW------------------------------------/
----------------------------------------------------------------------------------------/

--[[-------------------------------------------------------------------------------------
	ACE_InfraredHeatFromProp( self, Target , dist )  --used mostly by infrared guidance

->  Input information:

	guidance - infrared guidance
	Target - Ent Target to track Heat
	dist - distance between the missile and the Target

]]---------------------------------------------------------------------------------------
function ACE_InfraredHeatFromProp( Target, dist )

	if not IsValid(Target) then print("[ACE | WARN]- Unable to track Heat. Target Entity not valid!") return 0 end
	if not dist then print("[ACE | WARN]- Unable to track Heat. dist not valid!") return end

	local entpos = Target:GetPos()
	local GroundTr = util.TraceHull( {
		start = entpos,
		endpos = entpos + Vector(0,0,-500) , --12 meters off ground
		collisiongroup  = COLLISION_GROUP_WORLD,
		mins = Vector( 0, 0, 0 ),
		maxs = Vector( 0, 0, 0 ),
		filter = function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end
	}) --Hits anything in the world.

	local Speed = Target:GetVelocity():Length()
	local Heat = 0 --Heat will be added to this.
	Heat = Heat + (Speed / 35.2 ) --35.2 is 150 heat from 300 mph. 17.6 formula. 300mph / 2 mph per heat / 17.6 units/mph
	if not GroundTr.Hit then Heat = Heat + 150 end --Add 150C if the target is above the ground

	--A tank going 60mph will generate 30 extra heat plus engine heat
	--An aircraft going 200 mph will generate 100 heat plus 150
	--An aircraft going 300 mph will generate 150 heat plus 150

	return Heat
end

--[[-------------------------------------------------------------------------------------
	ACE_HeatFromGun( Gun, Heat, DeltaTime )  --used by Guns

->  Input information:

	Gun - The Gun Entity
	Heat - Current Heat of this gun
	DeltaTime - Delta time of this gun

]]---------------------------------------------------------------------------------------
function ACE_HeatFromGun( Gun , Heat, DeltaTime )

	local phys = Gun:GetPhysicsObject()
	local Mass = phys:GetMass()

--Decided to keep this code as note

	--local Energyloss = ((42500 * (-Heat))) * (1 + (Mass ^ 0.5) * 2/75) * DeltaTime * 0.03
	--Heat = math.max(Heat +(Energyloss/(Mass ^ 0.5) * 2/743.2),0)

	--Creates Heat when firing. Just as note, IK last shot will not create Heat, not really relevant though
	if Gun.HeatFire then

		Heat = Heat + (((0.2 + Gun.BulletData.PropMass) ^ 1.05 * 150000) / (Mass ^ 0.5) / 743.2)
		Gun.HeatFire = false
	--Dissipates when not firing
	else

		local Diff = Heat - ACE.AmbientTemp
		Heat = Heat - Diff * DeltaTime * 0.1 --* 0.35

	end


	return Heat
end

--[[-------------------------------------------------------------------------------------
	ACE_HeatFromEngine( Engine , Radiator )  --used mostly by engines

->  Input information:

	Engine - The Engine Entity

]]---------------------------------------------------------------------------------------
function ACE_HeatFromEngine( Engine )

	--bullshiet code below, better using tables next time

	if Engine.NAE then return end
	if not Engine.FlyRPM then print("[ACE | WARN]- RPM not found in this ent. Heat will not create this time!")  Engine.NAE = true return end

	local ExTemp = 0			--> Defines how hot is the engine when it is active? DONT TOUCH
	local Temp = Engine.Heat	--> Current Temperature


	if Engine.Active then

		local RPM  = Engine.FlyRPM  --> RPM of said engin
		local Heat = 0			--> Heat from engine

		---Highly uneffective code below. Guaranteed to get cancer once you read this---

		--Diesel Engines are cooler tbh
		if Engine.FuelType == "Diesel" then
			--print("Diesel Engine")
			Heat = RPM / 90000
			ExTemp = 50

		--Petrol Engines are oof of heat
		elseif Engine.FuelType == "Petrol" then
			--print("Petrol Engine")
			Heat = RPM / 100000
			ExTemp = 60

		--Electric engines are more efficient, so they will make less heat than oil based engines
		elseif Engine.FuelType == "Electric" then
			--print("Electric Engine")
			Heat = RPM / 60000
			ExTemp = 5

		--completely messy code, i hate it. ACF3 will cover this better
		elseif Engine.FuelType == "Multifuel" then
			--print("MultiFuel Category")

			--Ground Gas turbines. This is going crazy at this point
			if Engine.EngineType == "Radial" then
				--print("Ground Gas Turbine")
				Heat = RPM / 100000
				ExTemp = 60

			--Aero-turbines. deal with that temperature. AGT 1500 is cooler though
			elseif Engine.EngineType == "Turbine" then
				--print("Aero Turbine")
				Heat = RPM / 30000
				ExTemp = 350

			--Any multifuel Engine that is not a gas turbine.
			--Since they can use both petrol or diesel that i´ll leave a average of them
			else
				--print("MutiFuel Engine")
				Heat = RPM / 100000
				ExTemp = 55

			end
		end

		Temp = Temp + Heat

	end

	local Diff = Temp - (ACE.AmbientTemp + ExTemp )
	Temp = Temp - Diff / 750

	return Temp

end

function ACE_HeatFromRadar(Radar, Delta)
	local CurHeat = Radar.Heat
	local AmbientTemp = ACE.AmbientTemp

	local HeatWhileActive = 7 -- Degrees increase per second while active
	local CoolingCoefficient = 0.1 -- Degrees decrease per second per degree above ambient

	local CoolingRate = (CurHeat - AmbientTemp) * CoolingCoefficient * Delta
	local HeatingRate = 0

	if Radar.Active then
		HeatingRate = HeatWhileActive * Delta
	end

	local NewHeat = CurHeat + HeatingRate - CoolingRate

	return NewHeat
end






--[[-------------------------------------------------------------------------------------
	ACE_HeatFromGearbox( Gearbox )  --used mostly by gearboxes. Not used atm

->  Input information:

	Gearbox - The Gearbox Entity

]]---------------------------------------------------------------------------------------
--NOTE: disabled until i compile more information about gearbox code. the code works though
function ACE_HeatFromGearbox( Gearbox , InputRPM )

	if not Gearbox:IsValid() then
		print("Missing Gearbox")
		Temp = 0
		return Temp
	end
	if not InputRPM then
		print("Missing RPM")
		Temp = 0
		return Temp
	end

	local ExTemp = 5

	local Temp = Gearbox.Heat

	Temp = Temp + math.abs(Gearbox.GearRatio) * InputRPM * 0.0005

	local Diff = Temp - (ACE.AmbientTemp + ExTemp)

	Temp = Temp - Diff / 100

	return Temp
end


--THIS CODE NEEDS A REWRITE, USELESS ATM BUT I WILL KEEP IT HERE
--[[
function ACE_HeatFromEngine( Engine , Radiator )  --radiator?!? woooo

	--print(Engine.EngineType)

	local RPM  = 0

	if Engine.Active then
		RPM = Engine.FlyRPM
	end


	--Diesel Engines are cooler tbh
	local Heat = 0.003 * RPM / 2500

	--Petrol Engines are oof of heat
	if Engine.EngineType == 'GenericPetrol' then
		Heat = 0.005 * RPM / 2500

	--Electric engines are more efficient, so they will make less heat than oil based engines
	elseif Engine.EngineType == 'Electric' then
		Heat = 0.00125 * RPM / 2500

	--Turbines are the hottest engine for now
	elseif Engine.EngineType == 'Turbine' then
		Heat = 0.0025 * RPM / 2500

	end
	Engine.Heat = Engine.Heat + Heat * RPM * 0.01

-----------------------------------------------------------------------------------------
	--These parts need rewrite, since we dont have radiators yet
	local Phys = Engine:GetPhysicsObject()

	local Area = Phys:GetVolume() * 2--3452 * 2 --+ 10000  --engine + radiator
	local Volume = Phys:GetVolume() * 2 --+ 7000 --engine + radiator

	local Mul = Area / Volume
-----------------------------------------------------------------------------------------

	local Diff = Engine.Heat - ACE.AmbientTemp

	Engine.Heat = Engine.Heat - Diff * Mul * 0.0025

	return Engine.Heat

end
]]--

