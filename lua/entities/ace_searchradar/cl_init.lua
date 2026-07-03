include("shared.lua")

local ACF_GunInfoWhileSeated = CreateClientConVar("ACF_GunInfoWhileSeated", 0, true, false)
local ENTITY = FindMetaTable("Entity")
local CLIENT_IDLE_THINK_INTERVAL = 0.25

local function SetRadarSequence(self, name)
	local sequence = self:LookupSequence(name)
	if sequence < 0 then sequence = 0 end

	self:ResetSequence(sequence)
end

local function ResetRadarSpinBone(self)
	-- Clear any leftover radar_rot manipulation from the old manual-spin scheme so the bone is not frozen
	-- at a stale angle now that the model's own animation drives the spin. No-op for models without the bone.
	local bone = self:LookupBone("radar_rot")

	if bone then
		self:ManipulateBoneAngles(bone, angle_zero)
	end
end

-- Spherical radar models (radar_sp_*) carry their own "active"/"idle" sequences and a radar_rot bone.
-- Let the model's own animation spin the sphere: on activation play the "active" sequence and enable
-- AutomaticFrameAdvance so the engine advances the animation every frame (base_anim's field, matching the
-- sibling ace_rwr_sphere). The old manual radar_rot bone spin is gone -- it fought the model's animation
-- and stalled. Dish/directional models (radar_sml/mid/big) have no bones or sequences and never spun.
local function AdvanceActiveRadar(self)
	if not self:GetNWBool("ACE_RadarActive", false) then
		if self.ACE_RadarClientActive then
			SetRadarSequence(self, "idle")
			self.AutomaticFrameAdvance = false
			ResetRadarSpinBone(self)
			self.ACE_RadarClientActive = false
		end

		ENTITY.SetNextClientThink(self, CurTime() + CLIENT_IDLE_THINK_INTERVAL)

		return true
	end

	if not self.ACE_RadarClientActive then
		SetRadarSequence(self, "active")
		self.AutomaticFrameAdvance = true
		ResetRadarSpinBone(self)
		self.ACE_RadarClientActive = true
	end

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


