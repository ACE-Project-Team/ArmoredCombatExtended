AddCSLuaFile("shared.lua")
SWEP.Base = "weapon_ace_base"

if CLIENT then
	SWEP.PrintName		= "SZ-Creation Tool"
	SWEP.Slot			= 4
	SWEP.SlotPos		= 3
end

SWEP.Spawnable		= true
SWEP.AdminOnly		= true

SWEP.Category = "ACE Tools"
SWEP.SubCategory = "Tools"

--Visual
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/weapons/v_slam.mdl"
SWEP.WorldModel		= "models/weapons/w_slam.mdl"
SWEP.ReloadSound	= "Weapon_Pistol.Reload"
SWEP.HoldType		= "rpg"
SWEP.CSMuzzleFlashes	= true


-- Other settings
SWEP.Weight			= 10

-- Weapon info
SWEP.Purpose		= "Creates safezones"
SWEP.Instructions	= "Left/Right click to set points. Holding shift sets it to your position else goes to aimpos. Reload to open the menu."

SWEP.Corner1Ent = nil
SWEP.SZCorner1  = Vector()
SWEP.Corner2Ent = nil
SWEP.SZCorner2  = Vector()
SWEP.PreviewEntity = nil --Anchor entity for visual ropes to be attached to.

SWEP.LastMenuOpen = 0

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire( CurTime() + 0.5 )

	if CLIENT then
		return
	end

	local owner = self:GetOwner()
	local PointPos = Vector(0,0,0)
	if owner:IsSprinting() then
		PointPos = owner:GetShootPos()
	else
		local ET = owner:GetEyeTrace()
		if ET.Hit then
			PointPos = ET.HitPos
		end
	end

	if not IsValid(self.Corner1Ent) then
		local propEnt = ents.Create("prop_physics")
		if propEnt:IsValid() then
		propEnt:SetModel( "models/jaanus/wiretool/wiretool_pixel_med.mdl" )
		propEnt:Spawn()
		propEnt:SetNotSolid( true )
		propEnt:SetColor( Color(0,255,0) )

		local phys = propEnt:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion( false )
		end

		self.Corner1Ent = propEnt
		end
	end

	ACE_SendMsg(owner, Color(0,255,0), "[ACE SZ Tool] moved point(1)")
	print("[ACE SZ Tool] moved point(1)")
	self.Corner1Ent:SetPos(PointPos)
	self.SZCorner1  = PointPos

	local soundstr =  "npc/roller/code2.wav"
	self:EmitSound(soundstr,500,100)

	if IsValid(self.Corner1Ent) and IsValid(self.Corner2Ent) then
		if IsValid(self.PreviewEntity) then
			self.PreviewEntity:Remove()
		end
		self.PreviewEntity = ACE_VisualizeSZ(self.SZCorner1, self.SZCorner2)
	end

end

function SWEP:SecondaryAttack()

	self:SetNextSecondaryFire( CurTime() + 0.5 )

	if CLIENT then
		return
	end


	local owner = self:GetOwner()
	local PointPos = Vector(0,0,0)
	if owner:IsSprinting() then
		PointPos = owner:GetShootPos()
	else
		local ET = owner:GetEyeTrace()
		if ET.Hit then
			PointPos = ET.HitPos
		end
	end

	if not IsValid(self.Corner2Ent) then
		local propEnt = ents.Create("prop_physics")
		if propEnt:IsValid() then
		propEnt:SetModel( "models/jaanus/wiretool/wiretool_pixel_med.mdl" )
		propEnt:Spawn()
		propEnt:SetNotSolid( true )
		propEnt:SetColor( Color(255,0,0) )

		local phys = propEnt:GetPhysicsObject()
		if (IsValid(phys)) then
			phys:EnableMotion( false )
		end

		self.Corner2Ent = propEnt
		end
	end

	ACE_SendMsg(owner, Color(255,0,0), "[ACE SZ Tool] moved point(2)")
	print("[ACE SZ Tool] moved point(2)")
	self.Corner2Ent:SetPos(PointPos)
	self.SZCorner2  = PointPos


	local soundstr =  "npc/roller/code2.wav"
	self:EmitSound(soundstr,500,100)

	if IsValid(self.Corner1Ent) and IsValid(self.Corner2Ent) then
		if IsValid(self.PreviewEntity) then
			self.PreviewEntity:Remove()
		end
		self.PreviewEntity = ACE_VisualizeSZ(self.SZCorner1, self.SZCorner2)
	end

end

function SWEP:Think()
end

function SWEP:Reload()

	if CurTime() < self.LastMenuOpen then return false end
	self.LastMenuOpen = CurTime() + 2

	local owner = self:GetOwner()
	CmdStr = ""
	CmdStr = CmdStr .. "LocalPlayer():ConCommand('ace_szcreationmenu"
	CmdStr = CmdStr .. " " --Arg Seperator
	CmdStr = CmdStr .. math.Round( self.SZCorner1.x,2 )
	CmdStr = CmdStr .. " " --Arg Seperator
	CmdStr = CmdStr .. math.Round( self.SZCorner1.y,2 )
	CmdStr = CmdStr .. " " --Arg Seperator
	CmdStr = CmdStr .. math.Round( self.SZCorner1.z,2 )
	CmdStr = CmdStr .. " " --Arg Seperator
	CmdStr = CmdStr .. math.Round( self.SZCorner2.x,2 )
	CmdStr = CmdStr .. " " --Arg Seperator
	CmdStr = CmdStr .. math.Round( self.SZCorner2.y,2 )
	CmdStr = CmdStr .. " " --Arg Seperator
	CmdStr = CmdStr .. math.Round( self.SZCorner2.z,2 )
	CmdStr = CmdStr .. "')" --Arg Seperator and end

	print(CmdStr)
	owner:SendLua( CmdStr )
	--owner:ConCommand(CmdStr)


	self:DefaultReload(ACT_VM_RELOAD)

	self:Think()
	return true
end
