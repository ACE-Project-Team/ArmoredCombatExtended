
local cat = ((ACF.CustomToolCategory and ACF.CustomToolCategory:GetBool()) and "ACF" or "Construction");

TOOL.Category		= cat
TOOL.Name			= "#tool.acfmenu.name"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar[ "type" ] = "gun"
TOOL.ClientConVar[ "id" ] = "7.62mmMG" --Used by guns and crates (as example)

TOOL.ClientConVar[ "data1" ] = "7.62mmMG"
TOOL.ClientConVar[ "data2" ] = "AP"
TOOL.ClientConVar[ "data3" ] = 0
TOOL.ClientConVar[ "data4" ] = 0
TOOL.ClientConVar[ "data5" ] = 0
TOOL.ClientConVar[ "data6" ] = 0
TOOL.ClientConVar[ "data7" ] = 0
TOOL.ClientConVar[ "data8" ] = 0
TOOL.ClientConVar[ "data9" ] = 0
TOOL.ClientConVar[ "data10" ] = 0
TOOL.ClientConVar[ "data11" ] = 0
TOOL.ClientConVar[ "data12" ] = 0
TOOL.ClientConVar[ "data13" ] = 0
TOOL.ClientConVar[ "data14" ] = 0
TOOL.ClientConVar[ "data15" ] = 0
TOOL.ClientConVar[ "entitydata" ] = ""

TOOL.SelectedEntities = {}

cleanup.Register( "acfmenu" )

if CLIENT then
	TOOL.Information = {
		{ name = "left", stage = 0 },
		{ name = "right", stage = 0 },

		{ name = "stage1.link", stage = 1, icon = "gui/rmb.png" },
		{ name = "stage1.unlink", stage = 1, icon = "gui/rmb.png", icon2 = "gui/info" },
		{ name = "stage1.multiselect", icon = "gui/rmb.png", icon2 = "gui/info", stage = 1 },
		{ name = "stage1.reload", stage = 1, icon = "gui/r.png" }
	}

	--[[------------------------------------
		BuildCPanel
	--------------------------------------]]
	function TOOL.BuildCPanel( CPanel )

		local pnldef_ACFmenu = vgui.RegisterFile( "acf/client/cl_acfmenu_gui.lua" )

		-- create
		local DPanel = vgui.CreateFromTable( pnldef_ACFmenu )
		CPanel:AddPanel( DPanel )

	end
end

-- Spawn/update functions
function TOOL:LeftClick( trace )

	if CLIENT then return true end
	if not IsValid( trace.Entity ) and not trace.Entity:IsWorld() then return false end

	local ply	= self:GetOwner()
	local Type	= self:GetClientInfo( "type" )
	local Id	= self:GetClientInfo( "id" )
	local entClass
	local TypeId = ACF.Weapons[Type][Id]

	if not TypeId then
		if Type == "Ammo" then
			entClass = "acf_ammo"
		elseif Type == "FuelTanks" then
			entClass = "acf_fueltanks"
		end
	else
		entClass = TypeId["ent"]
	end

	local DupeClass = duplicator.FindEntityClass( entClass )

	if DupeClass then

		local ArgTable = {}
		ArgTable[2] = trace.HitNormal:Angle():Up():Angle()
		ArgTable[1] = trace.HitPos + trace.HitNormal * 50

		debugoverlay.Cross(trace.HitPos, 5, 5, Color(255,0,0), true)
		debugoverlay.Cross(ArgTable[1], 5, 5, Color(255,0,0), true)

		local ArgList = list.Get("ACFCvars")

		-- Reading the list packaged with the ent to see what client CVar it needs
		for Number, Key in pairs( ArgList[entClass] ) do
			ArgTable[ Number + 2 ] = self:GetClientInfo( Key )
		end

		if trace.Entity:GetClass() == entClass and trace.Entity.CanUpdate then
			table.insert( ArgTable, 1, ply )
			local success, msg = trace.Entity:Update( ArgTable )
			ACF_SendNotify( ply, success, msg )
		else
			-- Using the Duplicator entity register to find the right factory function
			local Ent = DupeClass.Func( ply, unpack( ArgTable ) ) --aka function like MakeACF_Ammo
			if not IsValid(Ent) then ACF_SendNotify(ply, false, "#tool.acfmenu.creationfailed") return false end

			Ent:Activate()
			Ent:DropToFloor()
			Ent:GetPhysicsObject():EnableMotion( false )

			undo.Create( entClass )
				undo.AddEntity( Ent )
				undo.SetPlayer( ply )
			undo.Finish()
		end

		return true
	else
		print("Didn't find entity duplicator records")
	end

end

function TOOL:SelectEntity(ent)
	if CLIENT then return end

	if not self.SelectedEntities[ent] then
		self.SelectedEntities[ent] = ent:GetColor()
		ent:SetColor(Color(0, 255, 0))
	else
		ent:SetColor(self.SelectedEntities[ent])
		self.SelectedEntities[ent] = nil
	end
end

function TOOL:DeselectAll()
	if CLIENT then return end

	for ent, color in pairs(self.SelectedEntities) do
		if IsValid(ent) then
			ent:SetColor(color)
		end

		self.SelectedEntities[ent] = nil
	end
end

local function linkEnts(e1, e2, unlink)
	if e1.IsMaster and e2:GetClass() ~= "acf_engine" and (e1:GetClass() ~= "acf_gearbox" or e2:GetClass() ~= "acf_gearbox") then
		if unlink then
			return e1:Unlink(e2)
		else
			return e1:Link(e2)
		end
	elseif e2.IsMaster then
		if unlink then
			return e2:Unlink(e1)
		else
			return e2:Link(e1)
		end
	else
		return false, "Neither entity is a master entity"
	end
end

function TOOL:RightClick( trace )
	local ent = trace.Entity
	local ply = self:GetOwner()
	local validEnt = IsValid(ent)
	local stage = self:GetStage()

	if validEnt and stage == 0 then
		self:SelectEntity(ent)
		self:SetStage(1)

		return true
	elseif stage == 1 then
		if not validEnt then
			self:DeselectAll()
			self:SetStage(0)

			return true
		end

		local holdingShift = ply:KeyDown(IN_SPEED)
		local holdingUse = ply:KeyDown(IN_USE)

		if holdingShift then
			if validEnt then
				self:SelectEntity(ent)
			end

			return true
		else
			if SERVER then
				for selected in pairs(self.SelectedEntities) do
					if ent ~= selected and validEnt and IsValid(selected) then
						local success, msg = linkEnts(ent, selected, holdingUse)

						ACF_SendNotify(ply, success, msg)
					end
				end
			end

			self:DeselectAll()
			self:SetStage(0)

			return true
		end
	end
end

function TOOL:Holster()
	self:SetStage(0)
	self:DeselectAll()
end

function TOOL:Reload()
	self:SetStage(0)
	self:DeselectAll()

	return self:GetStage() == 1
end