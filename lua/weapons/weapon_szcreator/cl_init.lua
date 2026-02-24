include("shared.lua")

SWEP.DrawAmmo		= false
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox	= true
SWEP.BounceWeaponIcon	= true


concommand.Add("ace_szcreationmenu", function(_, _, args)
    local frame = vgui.Create( "DFrame" )
    frame:SetSize( 300, 100 )
    frame:SetSizable(false)

    frame:SetDraggable(false)
    frame:SetTitle("[ACE] Safezone Creation Tool")

    frame:Center()
    frame:SetVisible(true)
    frame:MakePopup()
    frame:ShowCloseButton(true)

    frame:SetScreenLock(true)

    local SZName = ""

    local TextEntry = vgui.Create( "DTextEntry", frame ) -- create the form as a child of frame
    TextEntry:Dock( TOP )
    TextEntry:DockMargin( 0, 5, 0, 0 )
    TextEntry:SetPlaceholderText( "<Enter a name for the safezone here>" )
    TextEntry.OnChange = function( self )
        SZName = self:GetValue()
    end

    local x,y = frame:GetSize()
    local button = vgui.Create( "DButton", frame)
    button:SetText( "Create Safezone" )
    button:SetSize(100,30)
    button:SetPos( x / 2 - 50, y / 2 + 10)
    button.DoClick = function()
        frame:Close()
        --print("Min: " .. args[1] .. "x, " .. args[2] .. "y, " .. args[3] .. "z")
        print("Attempted Command: " .. "ACF_AddSafeZone " .. (SZName or "NoName") .. " " .. (args[1] or "n/a") .. " " .. (args[2] or "n/a") .. " " .. (args[3] or "n/a") .. " " .. (args[4] or "n/a") .. " " .. (args[5] or "n/a") .. " " .. (args[6] or "n/a"))
        LocalPlayer():ConCommand("ACF_AddSafeZone " .. SZName .. " " .. args[1] .. " " .. args[2] .. " " .. args[3] .. " " .. args[4] .. " " .. args[5] .. " " .. args[6])
        LocalPlayer():ConCommand("ACF_SaveSafeZones")
    end
end )
