
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include("shared.lua")

CreateConVar("sbox_max_ace_explosive", 20)




function ENT:Initialize()

	self.BulletData = self.BulletData or {}
	self.SpecialDamage = true	--If true needs a special ACE_OnDamage function

	self.Inputs = Wire_CreateInputs( self, { "Detonate" } )
	self.Outputs = Wire_CreateOutputs( self, {} )

	self.ThinkDelay = 0.1

end

local nullhit = {Damage = 0, Overkill = 1, Loss = 0, Kill = false}
function ENT:ACF_OnDamage( Entity , Energy , FrArea , Angle , Inflictor )
	self.ACF.Armour = 0.1
	local HitRes = ACE_PropDamage( Entity , Energy , FrArea , Angle , Inflictor )	--Calling the standard damage prop function
	if self.Detonated or self.DisableDamage then return table.Copy(nullhit) end

	local CanDo = hook.Run("ACE_AmmoExplode", self, self.BulletData )
	if CanDo == false then return table.Copy(nullhit) end

	HitRes.Kill = false
	self:Detonate()

	return table.Copy(nullhit) --This function needs to return HitRes
end

function ENT:TriggerInput( inp, value )
	if inp == "Detonate" and value ~= 0 then
		self:Detonate()
	end
end

function ACE_MakeLegacyExplosive(Owner, Pos, Angle, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Mdl, Data11, Data12, Data13, Data14, Data15)

	if not Owner:CheckLimit("_acf_explosive") then return false end


	--local weapon = ACE.Weapons.Guns[Data1]

	local Bomb = ents.Create("acf_explosive")
	if not Bomb:IsValid() then return false end
	Bomb:SetAngles(Angle)
	Bomb:SetPos(Pos)
	Bomb:Spawn()
	Bomb:SetPlayer(Owner)
	Bomb:CPPISetOwner(Owner)


	Mdl = Mdl or ACE.Weapons.Guns[Id].model

	Bomb.Id = Id
	Bomb:CreateBomb(Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Mdl, Data11, Data12, Data13 , Data14 , Data15)

	Owner:AddCount( "_acf_explosive", Bomb )
	Owner:AddCleanup( "acemenu", Bomb )

	return Bomb
end
list.Set( "ACFCvars", "acf_explosive", {"id", "data1", "data2", "data3", "data4", "data5", "data6", "data7", "data8", "data9", "data10", "mdl", "data11", "data12", "data13", "data14", "data15"} )
duplicator.RegisterEntityClass("acf_explosive", ACE_MakeLegacyExplosive, "Pos", "Angle", "RoundId", "RoundType", "RoundPropellant", "RoundProjectile", "RoundData5", "RoundData6", "RoundData7", "RoundData8", "RoundData9", "RoundData10", "Model" , "RoundData11" , "RoundData12", "RoundData13", "RoundData14", "RoundData15" )

function ENT:CreateBomb(Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Mdl, bdata,Data11 ,Data12, Data13 ,Data14, Data15)

	self:SetModelEasy(Mdl)
	--Data 1 to 4 are should always be Round ID, Round Type, Propellant lenght, Projectile lenght
	self.RoundId			= Data1	--Weapon this round loads into, ie 140mmC, 105mmH ...
	self.RoundType		= Data2	--Type of round, IE AP, HE, HEAT ...
	self.RoundPropellant	= Data3--Lenght of propellant
	self.RoundProjectile	= Data4--Lenght of the projectile
	self.RoundData5		= ( Data5 or 0 )
	self.RoundData6		= ( Data6 or 0 )
	self.RoundData7		= ( Data7 or 0 )
	self.RoundData8		= ( Data8 or 0 )
	self.RoundData9		= ( Data9 or 0 )
	self.RoundData10		= ( Data10 or 0 )
	self.RoundData11		= ( Data11 or 0 )
	self.RoundData12		= ( Data12 or 0 )
	self.RoundData13		= ( Data13 or 0 )
	self.RoundData14		= ( Data14 or 0 )
	self.RoundData15		= ( Data15 or 0 )

	local PlayerData = bdata or ACE_Missile_CompactBulletData(self)

	--local guntable = ACE.Weapons.Guns
	--local gun = guntable[self.RoundId] or {}
	self:ConfigBulletDataShortForm(PlayerData)

end

function ENT:SetModelEasy(mdl)
	local curMdl = self:GetModel()

	if not mdl or curMdl == mdl then
		self.Model = self:GetModel()
		return
	end

	self:SetModel( mdl )
	self.Model = mdl

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_WORLD )

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:Wake()
		phys:EnableMotion(true)
		phys:SetMass( 10 )
	end
end

function ENT:SetBulletData(bdata)

	if not (bdata.IsShortForm or bdata.Data5) then error("acf_explosive requires short-form bullet-data but was given expanded bullet-data.") end

	bdata = ACE_Missile_CompactBulletData(bdata)

	self:CreateBomb(
		bdata.Data1 or bdata.Id,
		bdata.Type or bdata.Data2,
		bdata.PropLength or bdata.Data3,
		bdata.ProjLength or bdata.Data4,
		bdata.Data5,
		bdata.Data6,
		bdata.Data7,
		bdata.Data8,
		bdata.Data9,
		bdata.Data10,
		bdata.Data11,
		bdata.Data12,
		bdata.Data13,
		bdata.Data14,
		bdata.Data15,
		nil,
		bdata)

	self:ConfigBulletDataShortForm(bdata)
end

function ENT:ConfigBulletDataShortForm(bdata)
	bdata = ACE_Missile_ExpandBulletData(bdata)

	self.BulletData = bdata
	self.BulletData.Entity = self
	self.BulletData.Crate = self:EntIndex()
	self.BulletData.Owner = self.BulletData.Owner or self:CPPIGetOwner()

	local phys = self:GetPhysicsObject()
	if (IsValid(phys)) then
		phys:SetMass( bdata.ProjMass or bdata.RoundMass or bdata.Mass or 10 )
	end

	self:RefreshClientInfo()
end


function ENT:Think()

	self:NextThink(CurTime() + self.ThinkDelay)

	return true

end

function ENT:Detonate(overrideBData)

	if self.Detonated then return end
	self.Detonated = true

	local bdata = overrideBData or self.BulletData
	local phys  = self:GetPhysicsObject()
	local pos	= self:GetPos()

	local phyvel =  phys and phys:GetVelocity() or Vector(0, 0, 1000)
	bdata.Flight =  bdata.Flight or phyvel

	if overrideBData then

		if self.Fuse.PerformDetonation then
			self.Fuse:PerformDetonation( self, bdata, phys, pos )
		else
			ACE.Fuse.Contact():PerformDetonation( self, bdata, phys, pos )
		end
	end

	timer.Simple(3, function() if IsValid(self) then if IsValid(self.FakeCrate) then self.FakeCrate:Remove() end self:Remove() end end)

	debugoverlay.Text(pos, "Missile Pos", 10 )

	--debugoverlay.Line(pos, bdata.Pos, 10, Color(255, 0, 0))
	--debugoverlay.Cross(pos, 5, 5, Color(255,255,0))
	--debugoverlay.Cross(bdata.Pos, 5, 5, Color(255,255,255))

end

--Restored old PropHit function, with some modifications so it doenst fuck up
function ENT:DoReplicatedPropHit(Bullet)

	local FlightRes = { Entity = self, HitNormal = self.HitNorm, HitPos = Bullet.Pos, HitGroup = HITGROUP_GENERIC }
	local Index = Bullet.Index

	local bulletPropImpact = ACE.RoundTypes[Bullet.Type]["propimpact"]
	local Retry = bulletPropImpact( Index, Bullet, FlightRes.Entity ,  FlightRes.HitNormal , FlightRes.HitPos , FlightRes.HitGroup )				--If we hit stuff then send the resolution to the damage function

	--This is crucial, to avoid 2nd tandem munitions spawn on 1st Bullet hitpos
	Bullet.FirstPos = FlightRes.HitPos

	--Internally used in case of HEAT hitting world, penetrating or not
	if Retry == "Penetrated" then

		ACE_Missile_ResetVelocity(Bullet)

		if Bullet.OnPenetrated then Bullet.OnPenetrated(Index, Bullet, FlightRes) end

		ACE_BulletClient( Index, Bullet, "Update" , 2 , FlightRes.HitPos  )
		ACE_CalcBulletFlight( Index, Bullet, true )
	else

		if Bullet.OnEndFlight then Bullet.OnEndFlight(Index, Bullet, FlightRes) end

		ACE_BulletClient( Index, Bullet, "Update" , 1 , FlightRes.HitPos  )
		local bulletEndFlight = ACE.RoundTypes[Bullet.Type]["endflight"]
		bulletEndFlight( Index, Bullet, FlightRes.HitPos, FlightRes.HitNormal )
	end

end

function ENT:EnableClientInfo(bool)
	self.ClientInfo = bool
	self:SetNWBool("VisInfo", bool)

	if bool then
		self:RefreshClientInfo()
	end
end

function ENT:RefreshClientInfo()

	ACE_Missile_MakeCrateForBullet(self, self.BulletData)

end
