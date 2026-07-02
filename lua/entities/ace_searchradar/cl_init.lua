include("shared.lua")

local ACF_GunInfoWhileSeated = CreateClientConVar("ACF_GunInfoWhileSeated", 0, true, false)
local ENTITY = FindMetaTable("Entity")
local RADAR_BONE_ANGLE = Angle(0, 0, 0)
local CLIENT_IDLE_THINK_INTERVAL = 0.25

local function SetRadarSequence(self, name)
	local sequence = self:LookupSequence(name)
	if sequence < 0 then sequence = 0 end

	self:ResetSequence(sequence)
end

local function GetActiveSequence(self)
	local sequence = self.ACE_RadarActiveSequence

	if sequence == nil then
		sequence = self:LookupSequence("active")
		if sequence < 0 then sequence = 0 end

		self.ACE_RadarActiveSequence = sequence
	end

	return sequence
end

local function GetSequenceSweepRate(self)
	local duration = self:SequenceDuration(GetActiveSequence(self)) or 0
	local rate = self:GetNWFloat("ACE_RadarAnimationRate", 1)

	if duration <= 0 then return 360 * rate end

	return 360 * rate / duration
end

local function GetRadarSweepRate(self)
	local sampleTime = self:GetNWFloat("ACE_RadarSweepTime", -1)

	if sampleTime >= 0 then
		local rate = self:GetNWFloat("ACE_RadarSweepRate", 0)
		if rate ~= 0 then return rate end
	end

	return GetSequenceSweepRate(self)
end

-- Stateless dish angle = CurTime() * rate: a pure function of time, so the dish spins perfectly smoothly
-- and can never stall, lurch, or drift regardless of NWVar timing. The previous accumulate-per-frame +
-- correct-toward-server-sample scheme managed to do all three across successive fixes (erratic spin,
-- then stop-after-one-tick). Rate is the server sweep rate (search) or the model animation rate
-- (missile/tracking). Rotational PHASE is cosmetic for a spinning dish, so we deliberately do not chase
-- the server's exact scan bearing -- that sync is precisely what kept breaking.
local function AdvanceRadarVisualAngle(self)
	if not self:GetNWBool("ACE_RadarActive", false) then
		return self.ACE_RadarVisualAngle or 0
	end

	local angle = (CurTime() * GetRadarSweepRate(self)) % 360
	self.ACE_RadarVisualAngle = angle

	return angle
end

local function AnimateRadarBone(self)
	local model = self:GetModel()

	if self.ACE_RadarSpinModel ~= model then
		self.ACE_RadarSpinBone = nil
		self.ACE_RadarSpinModel = model
		self.ACE_RadarActiveSequence = nil
		self.ACE_RadarVisualAngle = nil
		self.ACE_RadarSweepSampleTime = nil
		self.ACE_RadarVisualUpdateTime = nil
	end

	local bone = self.ACE_RadarSpinBone

	if bone == nil then
		bone = self:LookupBone("radar_rot") or false
		self.ACE_RadarSpinBone = bone
	end

	if not bone then return end

	if not self:GetNWBool("ACE_RadarActive", false) then
		if self.ACE_RadarBoneActive then
			RADAR_BONE_ANGLE[1] = 0
			RADAR_BONE_ANGLE[2] = 0
			RADAR_BONE_ANGLE[3] = 0
			self:ManipulateBoneAngles(bone, RADAR_BONE_ANGLE)
			self:SetupBones()
			self.ACE_RadarVisualAngle = nil
			self.ACE_RadarSweepSampleTime = nil
			self.ACE_RadarVisualUpdateTime = nil
			self.ACE_RadarBoneActive = false
		end

		return
	end

	RADAR_BONE_ANGLE[1] = 0
	RADAR_BONE_ANGLE[2] = AdvanceRadarVisualAngle(self)
	RADAR_BONE_ANGLE[3] = 0

	self:ManipulateBoneAngles(bone, RADAR_BONE_ANGLE)
	self:SetupBones()
	self.ACE_RadarBoneActive = true
end

local function AdvanceActiveRadar(self)
	if not self:GetNWBool("ACE_RadarActive", false) then
		if self.ACE_RadarClientActive then
			SetRadarSequence(self, "idle")
			self.ACE_RadarClientActive = false
		end

		self.ACE_RadarVisualUpdateTime = nil
		ENTITY.SetNextClientThink(self, CurTime() + CLIENT_IDLE_THINK_INTERVAL)

		return true
	end

	if not self.ACE_RadarClientActive then
		SetRadarSequence(self, "idle")
		self.ACE_RadarClientActive = true
		self.ACE_RadarVisualUpdateTime = nil
	end

	AdvanceRadarVisualAngle(self)
	self:SetPlaybackRate(self:GetNWFloat("ACE_RadarAnimationRate", 1))
	ENTITY.SetNextClientThink(self, CurTime())

	return true
end

function ENT:Initialize()

	self.BaseClass.Initialize( self )
	ENTITY.SetNextClientThink(self, CurTime())

end

function ENT:Think()
	return AdvanceActiveRadar(self)
end

function ENT:Draw()

	local lply = LocalPlayer()
	local hideBubble = not ACF_GunInfoWhileSeated:GetBool() and IsValid(lply) and lply:InVehicle()

	AnimateRadarBone(self)
	self.BaseClass.DoNormalDraw(self, false, hideBubble)
	Wire_Render(self)

	if self.GetBeamLength and (not self.GetShowBeam or self:GetShowBeam()) then
		-- Every SENT that has GetBeamLength should draw a tracer. Some of them have the GetShowBeam boolean
		Wire_DrawTracerBeam( self, 1, self.GetBeamHighlight and self:GetBeamHighlight() or false )
	end

end

function ACFTrackRadarGUICreate( Table )

	acfmenupanel:CPanelText("Name", Table.name, "DermaDefaultBold")

	local RadarMenu = acfmenupanel.CData.DisplayModel

	RadarMenu = vgui.Create( "DModelPanel", acfmenupanel.CustomDisplay )
		RadarMenu:SetModel( Table.model )
		RadarMenu:SetCamPos( Vector( 250, 500, 250 ) )
		RadarMenu:SetLookAt( Vector( 0, 0, 0 ) )
		RadarMenu:SetFOV( 20 )
		RadarMenu:SetSize(acfmenupanel:GetWide(),acfmenupanel:GetWide())
		RadarMenu.LayoutEntity = function() end
	acfmenupanel.CustomDisplay:AddItem( RadarMenu )

	acfmenupanel:CPanelText("ClassDesc", ACF.Classes.Radar[Table.class].desc)
	acfmenupanel:CPanelText("GunDesc", Table.desc)
	acfmenupanel:CPanelText("ViewCone", "View cone : " .. ((Table.viewcone or 180) * 2) .. " degs")
	acfmenupanel:CPanelText("Weight", "Weight : " .. Table.weight .. " kg")
	--acfmenupanel:CPanelText("GunParentable", "\nThis radar can be parented\n","DermaDefaultBold")

	acfmenupanel.CustomDisplay:PerformLayout()

end


