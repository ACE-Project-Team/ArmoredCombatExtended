
ACE.BulletEffect = ACE.BulletEffect or {}

function ACE.ManageBulletEffects()

	if next(ACE.BulletEffect) then

		for Index,Bullet in pairs(ACE.BulletEffect) do
			ACE.SimBulletFlight( Bullet, Index )			--This is the bullet entry in the table, the omnipresent Index var refers to this
		end
	end
end
hook.Remove( "Think", "ACE_ManageBulletEffects" )
hook.Add("Think", "ACE_ManageBulletEffects", ACE.ManageBulletEffects)

function ACE.SimBulletFlight( Bullet, Index )

	if not Bullet or not Index then return end

	local DeltaTime = CurTime() - Bullet.LastThink --intentionally not using cached curtime value

	local WaterTr = { }
	WaterTr.start = Bullet.SimPos
	WaterTr.endpos = Bullet.SimPos + Vector(0,0,1)
	WaterTr.mask = MASK_WATER
	local Water = util.TraceLine( WaterTr )


	Bullet.UnderWater = false

	if Water.HitWorld and Water.StartSolid then
			Bullet.UnderWater = true
	end

	local FlightLength = Bullet.SimFlight:Length()

	local Drag = ( Bullet.DragCoef * FlightLength^2 ) / ACE.DragDiv

	if Bullet.UnderWater then
		Drag = Drag * 800
	end
	local ClampFlight = FlightLength * 0.9
	Drag = Bullet.SimFlight:GetNormalized() * math.min(Drag * DeltaTime,ClampFlight)

	Bullet.SimPosLast	= Bullet.SimPos
	Bullet.SimPos		= Bullet.SimPos + (Bullet.SimFlight * ACE.VelScale * DeltaTime)		--Calculates the next shell position
	Bullet.SimFlight	= Bullet.SimFlight + (Bullet.Accel * DeltaTime - Drag)			--Calculates the next shell vector

--	print(Bullet.SimFlight:Length()/39.37)

	if Bullet and Bullet.Effect:IsValid() then
		Bullet.Effect:ApplyMovement( Bullet, Index )
	end
	Bullet.LastThink = CurTime() --ACE.CurTime --intentionally not using cached curtime value

end
