ACE.VignetteStrength = 0
ACE.VignetteMax = 10

net.Receive("ACE_Vignette", function()
	local strength = net.ReadFloat()
	ACE.VignetteStrength = math.min(ACE.VignetteStrength + strength, ACE.VignetteMax)
end)

hook.Add("Think", "ACE_VignetteFade", function()
	if ACE.VignetteStrength > 0 then
		ACE.VignetteStrength = math.max(ACE.VignetteStrength - FrameTime() / 0.5, 0)
	end
end)

local gradDown = Material("vgui/gradient-d")
local gradUp = Material("vgui/gradient-u")
local gradRight = Material("vgui/gradient-r")
local gradLeft = Material("vgui/gradient-l")

hook.Add("HUDPaint", "ACE_VignetteDraw", function()
	if ACE.VignetteStrength <= 0 then return end
	if LocalPlayer():InVehicle() then return end

	local alpha = math.Clamp(ACE.VignetteStrength * 50, 0, 255)
	local scrW, scrH = ScrW(), ScrH()
	local edgeSize = math.min(scrW, scrH) * 0.9

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.SetMaterial(gradUp)
	surface.DrawTexturedRect(0, 0, scrW, edgeSize)

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.SetMaterial(gradDown)
	surface.DrawTexturedRect(0, scrH - edgeSize, scrW, edgeSize)

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.SetMaterial(gradLeft)
	surface.DrawTexturedRect(0, 0, edgeSize, scrH)

	surface.SetDrawColor(0, 0, 0, alpha)
	surface.SetMaterial(gradRight)
	surface.DrawTexturedRect(scrW - edgeSize, 0, edgeSize, scrH)
end)
