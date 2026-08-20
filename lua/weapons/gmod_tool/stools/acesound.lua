
ACE = ACE or {}

local cat = ((ACE.CustomToolCategory and ACE.CustomToolCategory:GetBool()) and "ACF" or "Construction");

TOOL.Category		= cat
TOOL.Name			= "#tool.acesound.name"
TOOL.Command		= nil
TOOL.ConfigName		= ""

TOOL.ClientConVar["pitch"] = "1"

if CLIENT then

	TOOL.Information = {

		{ name = "left", icon = "gui/lmb.png" },
		{ name = "right", icon = "gui/rmb.png" },
		{ name = "reload", icon = "gui/r.png" },

	}

end

local GunClasses = ACE.Classes.GunClass
local GunTable = ACE.Weapons.Guns

local EngineTable = ACE.Weapons.Engines

ACE.SoundToolSupport = ACE.SoundToolSupport or {

	acf_gun = {

		GetSound = function(ent) return { Sound = ent.Sound, Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch", soundData.Pitch )
		end,

		ResetSound = function(ent)

			local Class = ent.Class
			local lookup = GunTable[ent.Id]

			local sound = lookup.sound or GunClasses[Class]["sound"]

			local soundData = { Sound = sound, Pitch = 100 }

			local setSound = ACE.SoundToolSupport["acf_gun"].SetSound
			setSound( ent, soundData )
		end,

		NewFormat = function()
		end
	},

	acf_engine = {

		GetSound = function(ent) return { Sound = ent.SoundPath, Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.SoundPath = soundData.Sound
			ent.SoundPitch = soundData.Pitch
		end,

		ResetSound = function(ent)

			local Id = ent.Id
			local pitch = EngineTable[Id]["pitch"] or 1
			local sound = EngineTable[Id]["sound"] or ""

			local soundData = { Sound = sound, Pitch = pitch }

			local setSound = ACE.SoundToolSupport["acf_engine"].SetSound
			setSound( ent, soundData )
		end
	},

	acf_rack = {

		GetSound = function(ent) return { Sound = ent.Sound, Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)

			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch",  soundData.Pitch )
		end,

		ResetSound = function(ent)

			local Class = ent.Class
			local sound = GunClasses[Class]["sound"] or ""

			local soundData = { Sound = sound, Pitch = 100 }

			local setSound = ACE.SoundToolSupport["acf_rack"].SetSound
			setSound( ent, soundData )
		end,

		NewFormat = function()
		end

	},

	acf_missileradar = {

		GetSound = function(ent) return { Sound = ent.Sound or ACE.Missile.DefaultRadarSound, Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch",  soundData.Pitch )
		end,

		ResetSound = function(ent)
			local soundData = {Sound = ACE.Missile.DefaultRadarSound, Pitch = 100}

			local setSound = ACE.SoundToolSupport["acf_missileradar"].SetSound
			setSound( ent, soundData )
		end
	},

	ace_crewseat_gunner = {

		GetSound = function(ent) return { Sound = ent.Sound or "npc/combine_soldier/die1.wav", Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch",  soundData.Pitch )
		end,

		ResetSound = function(ent)
			local soundData = {Sound = "npc/combine_soldier/die1.wav", Pitch = 100}

			local setSound = ACE.SoundToolSupport["ace_crewseat_gunner"].SetSound
			setSound( ent, soundData )
		end
	},

	ace_crewseat_driver = {

		GetSound = function(ent) return { Sound = ent.Sound or "npc/combine_soldier/die1.wav", Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch",  soundData.Pitch )
		end,

		ResetSound = function(ent)
			local soundData = {Sound = "npc/combine_soldier/die1.wav", Pitch = 100}

			local setSound = ACE.SoundToolSupport["ace_crewseat_driver"].SetSound
			setSound( ent, soundData )
		end
	},

	ace_crewseat_loader = {

		GetSound = function(ent) return { Sound = ent.Sound or "npc/combine_soldier/die1.wav", Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch",  soundData.Pitch )
		end,

		ResetSound = function(ent)
			local soundData = {Sound = "npc/combine_soldier/die1.wav", Pitch = 100}

			local setSound = ACE.SoundToolSupport["ace_crewseat_loader"].SetSound
			setSound( ent, soundData )
		end
	},

	ace_sonar = {

		GetSound = function(ent) return { Sound = ent.Sound or "acf_extra/ACE/sensors/Sonar/coldwaters.wav", Pitch = ent.SoundPitch or 100 } end,

		SetSound = function(ent, soundData)
			ent.Sound = soundData.Sound
			ent.SoundPitch = soundData.Pitch
			ent:SetNWString( "Sound", soundData.Sound )
			ent:SetNWInt( "SoundPitch",  soundData.Pitch )
		end,

		ResetSound = function(ent)
			local soundData = {Sound = "acf_extra/ACE/sensors/Sonar/coldwaters.wav", Pitch = 100}

			local setSound = ACE.SoundToolSupport["ace_crewseat_driver"].SetSound
			setSound( ent, soundData )
		end
	},

	NewFormat = function()
	end

}

local function ReplaceSound( _ , Entity , data)
	if not IsValid( Entity ) then return end
	local existing = Entity.EntityMods and Entity.EntityMods.ace_replacesound
	data = existing or data
	local sound = data[1]
	local pitch = tonumber(data[2]) or 100
	local isNew = data[3]

	if pitch < 10 then
		pitch = pitch * 100
	end

	local class = Entity:GetClass()
	local support = ACE.SoundToolSupport[class]

	if support then

		-- Before to the implementation, sounds were still being granted with the pitch you had on the slider,
		-- making that the official integration makes it to use it, altering the supposed non pitch it had before
		-- This should fix it, making sure to tag it with a new format in future applications.
		if support.NewFormat and not isNew then
			pitch = 100
		end

		local newdata = {sound, pitch, true}
		support.SetSound(Entity, {Sound = sound, Pitch = pitch})
		duplicator.StoreEntityModifier( Entity, "ace_replacesound", newdata )
		duplicator.ClearEntityModifier( Entity, "acf_replacesound" )
	end
end

duplicator.RegisterEntityModifier( "ace_replacesound", ReplaceSound )
duplicator.RegisterEntityModifier( "acf_replacesound", ReplaceSound )

local function IsReallyValid(trace, ply)
	if not trace.Entity:IsValid() then return false end
	if trace.Entity:IsPlayer() then return false end
	if SERVER and not trace.Entity:GetPhysicsObject():IsValid() then return false end

	local class = trace.Entity:GetClass()
	if not ACE.SoundToolSupport[class] then
		ACE.SendNotify( ply, false, "#tool.acesound.unsupported" )

		return false
	end

	return true

end

function TOOL:LeftClick( trace )
	if CLIENT then return true end
	if not IsReallyValid( trace, self:GetOwner() ) then return false end

	local sound = self:GetOwner():GetInfo("wire_soundemitter_sound")
	local pitch = self:GetClientInfo("pitch")
	ReplaceSound( self:GetOwner(), trace.Entity, {sound, pitch, true} )
	return true
end

function TOOL:RightClick( trace )
	if CLIENT then return true end
	if not IsReallyValid( trace, self:GetOwner() ) then return false end

	local class = trace.Entity:GetClass()
	local support = ACE.SoundToolSupport[class]
	if not support then return false end

	local soundData = support.GetSound(trace.Entity)

	self:GetOwner():ConCommand("wire_soundemitter_sound " .. soundData.Sound);

	if soundData.Pitch then
		self:GetOwner():ConCommand(self:GetMode() .. "_pitch " .. soundData.Pitch);
	end

	return true
end

function TOOL:Reload( trace )
	if CLIENT then return true end
	if not IsReallyValid( trace, self:GetOwner() ) then return false end

	local class = trace.Entity:GetClass()
	local support = ACE.SoundToolSupport[class]
	if not support then return false end

	support.ResetSound(trace.Entity)

	duplicator.ClearEntityModifier( trace.Entity, "ace_replacesound" )
	duplicator.ClearEntityModifier( trace.Entity, "acf_replacesound" )

	return true
end

if CLIENT then

	function TOOL.BuildCPanel(panel)
		local wide = panel:GetWide()

		panel:Help( "#tool.acesound.info" )

		local SoundNameText = vgui.Create("DTextEntry", ValuePanel)
		SoundNameText:SetText("")
		SoundNameText:SetWide(wide - 20)
		SoundNameText:SetTall(20)
		SoundNameText:SetMultiline(false)
		SoundNameText:SetConVar("wire_soundemitter_sound")
		SoundNameText:SetVisible(true)
		SoundNameText:Dock(LEFT)
		panel:AddItem(SoundNameText)

		local SoundBrowserButton = vgui.Create("DButton")
		SoundBrowserButton:SetText("#tool.acesound.openbrowser")
		SoundBrowserButton:SetWide(wide)
		SoundBrowserButton:SetTall(20)
		SoundBrowserButton:SetVisible(true)
		SoundBrowserButton:SetIcon( "icon16/application_view_list.png" )
		SoundBrowserButton.DoClick = function()
			RunConsoleCommand("wire_sound_browser_open", SoundNameText:GetValue(), "1")
		end
		panel:AddItem(SoundBrowserButton)

		local SoundPre = vgui.Create("DPanel")
		SoundPre:SetWide(wide)
		SoundPre:SetTall(20)
		SoundPre:SetVisible(true)

		local SoundPreWide = SoundPre:GetWide()

		local SoundPrePlay = vgui.Create("DButton", SoundPre)
		SoundPrePlay:SetText("#tool.acesound.play")
		SoundPrePlay:SetWide(SoundPreWide / 2)
		SoundPrePlay:SetPos(0, 0)
		SoundPrePlay:SetTall(20)
		SoundPrePlay:SetVisible(true)
		SoundPrePlay:SetIcon( "icon16/sound.png" )
		SoundPrePlay.DoClick = function()
			RunConsoleCommand("play",SoundNameText:GetValue())
		end

		local SoundPreStop = vgui.Create("DButton", SoundPre)
		SoundPreStop:SetText("#tool.acesound.stop")
		SoundPreStop:SetWide(SoundPreWide / 2)
		SoundPreStop:SetPos(SoundPreWide / 2, 0)
		SoundPreStop:SetTall(20)
		SoundPreStop:SetVisible(true)
		SoundPreStop:SetIcon( "icon16/sound_mute.png" )
		SoundPreStop.DoClick = function()
			RunConsoleCommand("play", "common/NULL.WAV") --Playing a silent sound will mute the preview but not the sound emitters.
		end
		panel:AddItem(SoundPre)
		SoundPre:InvalidateLayout(true)
		SoundPre.PerformLayout = function()
			local SoundPreWide = SoundPre:GetWide()
			SoundPrePlay:SetWide(SoundPreWide / 2)
			SoundPreStop:SetWide(SoundPreWide / 2)
			SoundPreStop:SetPos(SoundPreWide / 2, 0)
		end

		local CopyButton = vgui.Create("DButton")
		CopyButton:SetText("#tool.acesound.copy")
		CopyButton:SetWide(wide)
		CopyButton:SetTall(20)
		CopyButton:SetIcon( "icon16/page_copy.png" )
		CopyButton:SetVisible(true)
		CopyButton.DoClick = function()
			SetClipboardText( SoundNameText:GetValue())
		end
		panel:AddItem(CopyButton)

		local ClearButton = vgui.Create("DButton")
		ClearButton:SetText("#tool.acesound.clear")
		ClearButton:SetWide(wide)
		ClearButton:SetTall(20)
		ClearButton:SetIcon( "icon16/cancel.png" )
		ClearButton:SetVisible(true)
		ClearButton.DoClick = function()
			SoundNameText:SetValue("")
			RunConsoleCommand("wire_soundemitter_sound", "")
		end
		panel:AddItem(ClearButton)

		panel:NumSlider( "#tool.acesound.pitch", "acesound_pitch", 10, 255, 0 )
		panel:ControlHelp( "#tool.acesound.pitchdesc" )
	end

	--[[
		This is another dirty hack that prevents the sound emitter tool from automatically equipping when a sound is selected in the sound browser.
		However, this hack only applies if the currently equipped tool is the sound replacer and you're trying to switch to the wire sound tool.
		Additionally, if you're using a weapon instead of a tool and you choose a sound while the sound replacer menu is displayed, you will be redirected to it.

		The sound emitter will be equipped normally when switching to any other tool at the time of the change.
	]]

	spawnmenu.ActivateToolLegacy = spawnmenu.ActivateToolLegacy or spawnmenu.ActivateTool

	function spawnmenu.ActivateTool( tool, bool_menu, ... )

		local CurTool = LocalPlayer():GetTool()

		if CurTool and CurTool.Mode then

			local CurMode = isstring(CurTool.Mode) and CurTool.Mode or ""

			if tool == "wire_soundemitter" and CurMode == "acesound" then
				tool = CurMode
			end

		end

		spawnmenu.ActivateToolLegacy( tool, bool_menu, ... )
	end

end
