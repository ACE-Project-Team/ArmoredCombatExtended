AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

----------------------------------- The Mine Entity -----------------------------------
do

	function ENT:Initialize()

		self.Ready = false
		self.HasGround = false
		self.PhysgunDisabled = true

	end

	local function ArmingMode( Mine )

		local GroundTr = {}
		GroundTr.start = Mine:GetPos() + Vector(0,0,5)
		GroundTr.endpos = Mine:GetPos() + Vector(0,0,-Mine.setrange)
		GroundTr.mask = MASK_NPCWORLDSTATIC

		local Trace = util.TraceLine(GroundTr)

		if Trace.Hit and Trace.HitWorld then

			if not Mine.HasGround then

				local Offset = Vector(0,0,Mine.digdepth)
				local Position = Trace.HitPos + (Mine.GroundInverted and Offset or -Offset )
				local Angles = Trace.HitNormal:Angle() + (Mine.GroundInverted and Angle(-90,0,0) or Angle(90,0,0) )

				Mine:SetPos( Position )
				Mine:SetAngles( Angles )
				Mine.physObj:EnableMotion(false)
				Mine.HasGround = true
			end

			timer.Simple(Mine.ArmingTime, function()
				if IsValid(Mine) then
					Mine.Ready = true
				end
			end)

		end
	end

	local function ActiveMode( Mine )

		local mins = Mine.triggermins
		local maxs = Mine.triggermaxs

		local TriggerData = {}
		TriggerData.start = Mine:WorldSpaceCenter()
		TriggerData.endpos = TriggerData.start
		TriggerData.ignoreworld  = true
		TriggerData.mins = mins
		TriggerData.maxs = maxs
		TriggerData.mask = MASK_SHOT_HULL
		TriggerData.filter = function( ent ) if ( ent:GetClass() ~= "ace_mine" ) then return true end end

		debugoverlay.Box(TriggerData.start, TriggerData.mins, TriggerData.maxs, 0.5, Color(255,100,0, 50))

		local TriggerTrace = util.TraceHull( TriggerData )

		if TriggerTrace.Hit and Mine.IsJumper then

			if not Mine.HasJumped then
				local FinalForce =  Mine:GetUp() * Mine.physObj:GetMass() * (Mine.GroundInverted and -Mine.JumpForce or Mine.JumpForce)

				Mine.physObj:EnableMotion(true)
				Mine.physObj:ApplyForceCenter( FinalForce )
				Mine:EmitSound("weapons/amr/sniper_fire.wav", 75, 190, 1, CHAN_WEAPON )

				Mine.HasJumped = true
			end

			timer.Simple(0.5, function()
				if IsValid(Mine) and IsValid(Mine.physObj) then
					Mine:Detonate()

				end
			end)

		elseif TriggerTrace.Hit then
			if not Mine.ignoreplayers or (Mine.ignoreplayers and not TriggerTrace.Entity:IsPlayer()) then
				Mine:Detonate()
			end
		end
	end

	function ENT:Think()

		--Mine will look for ground during the arming process
		if not self.Ready then
			ArmingMode( self )
		else
			ActiveMode( self )
		end
	end

	function ENT:Detonate()
		if self.CustomMineDetonation then self.CustomMineDetonation( self ) return end

		self:Remove()

		local HEWeight = self.HEWeight
		local FragMass = self.FragMass
		local Radius = ACE.CalculateHERadius( HEWeight )
		local ExplosionOrigin = self:LocalToWorld(Vector(0,0,5))

		ACF_HE( ExplosionOrigin, Vector(0,0,1), HEWeight, FragMass, self.DamageOwner, self, self) --0.5 is standard antipersonal mine

		local Flash = EffectData()
			Flash:SetOrigin( ExplosionOrigin )
			Flash:SetNormal( Vector(0,0,-1) )
			Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
		util.Effect( "ACF_Scaled_Explosion", Flash )

	end

	function ENT:CanTool(ply, _, toolname)
		if ((CPPI and self:CPPICanTool(ply, "remover")) or (not CPPI)) and toolname == "remover" then
			return true
		end

		return false
	end

	function ENT:CanProperty(ply, property)
		if ((CPPI and self:CPPICanTool(ply, "remover")) or (not CPPI)) and property == "remover" then
			return true
		end

		return false
	end
end

----------------------------------- Extra Initialization for the mine -----------------------------------
do

	-- Initialize the necessary data to cache the mine counter per player.
	function InitializePlayerMineCounter( ply )
		ACE.MineOwners = ACE.MineOwners or {}
		ACE.MineOwners[ply] = {}
	end
	hook.Add( "PlayerInitialSpawn", "ACE_InitPlayerMineCounter", InitializePlayerMineCounter )

	-- We dont need mines to stay on the map if the owner leaves.
	function DeleteDisconnectPlayerMines( ply )
		if not ACE.MineOwners[ply] then return end
		for _, mine in ipairs(ACE.MineOwners[ply]) do
			mine:Remove()
		end
	end
	hook.Add( "PlayerDisconnected", "Playerleave", DeleteDisconnectPlayerMines )

end

----------------------------------- Mine Global Spawn function -----------------------------------
do
	local function CheckMineLimit( Owner )
		local limit = #ACE.MineOwners[Owner] < GetConVar("acf_mines_max"):GetInt()
		--print(#ACE.MineOwners[Owner], GetConVar("acf_mines_max"):GetInt(), limit)
		return limit
	end

	local function VerifyMineLimits(Owner)

		if not CheckMineLimit( Owner ) then
			local OldMine = ACE.MineOwners[Owner][1]
			if IsValid(OldMine) then
				OldMine:Remove()
			end
		end
	end

	local function AddMineToLimit( Owner, Mine )
		table.insert( ACE.MineOwners[Owner], Mine )
		--print("Mine registered count to player " .. Owner:Nick() .. ": " .. #ACE.MineOwners[Owner] )
	end

	local MineTable = ACE.MineData

	function ACE.CreateMine( MineId, Pos, Angle, Owner )
		if not IsValid(Owner) then return end

		VerifyMineLimits(Owner)

		local Mine = ents.Create( "ace_mine" )
		if IsValid( Mine ) then

			local MineData = MineTable[MineId]
			if not MineData then return end

			Mine.ArmingTime       = MineData.armdelay or 0
			Mine.HEWeight         = MineData.heweight or 0
			Mine.FragMass         = MineData.fragmass or 0

			Mine.weight           = MineData.weight or 1
			Mine.ignoreplayers    = MineData.ignoreplayers
			Mine.IsJumper         = MineData.shouldjump
			Mine.JumpForce        = MineData.shouldjump and MineData.jumpforce or nil

			Mine.setrange         = MineData.setrange or 1
			Mine.triggermins      = MineData.triggermins or vector_origin
			Mine.triggermaxs      = MineData.triggermaxs or vector_origin

			Mine.digdepth         = MineData.digdepth or 0
			Mine.GroundInverted   = MineData.groundinverted

			Mine.CustomMineDetonation = MineData.customdetonation

			Mine:CPPISetOwner(Entity(0))
			Mine.DamageOwner = Owner -- Done to avoid owners from manipulating the entity, but allowing the damage to be credited by him.

			Mine:SetPos( Pos )
			Mine:SetAngles( Angle )

			Mine:SetModel( MineData.model )
			Mine:SetMaterial( MineData.material )
			Mine:SetColor( MineData.color or Color(255,255,255) )

			Mine:SetMoveType(MOVETYPE_VPHYSICS);
			Mine:PhysicsInit(SOLID_VPHYSICS);
			Mine:SetSolid(SOLID_VPHYSICS);
			Mine:Spawn()

			local physObj = Mine:GetPhysicsObject()
			if IsValid(physObj) then

				Mine.physObj = physObj
				physObj:SetMass(MineData.weight)
				physObj:Wake()
			end

			AddMineToLimit( Owner, Mine )

			return Mine
		end
	end
end

ACE_CreateMine = ACE.CreateMine
