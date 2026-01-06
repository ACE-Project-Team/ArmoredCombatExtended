include("shared.lua")

SWEP.DrawAmmo       = true
SWEP.DrawCrosshair  = true

local DetectedMines = {}
local LastBeepTime = 0
local MinigameSequence = {}
--local ZoneCount = 4
local ZoneOrder = {1, 2, 3, 4}
--local IsUltraHardMode = false

local BeepSounds = {"buttons/blip1.wav", "buttons/blip2.wav"}

-- 6 colors
local ZoneColors = {
    Color(220, 60, 60),     -- 1: Red
    Color(60, 220, 60),     -- 2: Green
    Color(60, 100, 220),    -- 3: Blue
    Color(220, 220, 60),    -- 4: Yellow
    Color(220, 60, 220),    -- 5: Magenta
    Color(60, 220, 220),    -- 6: Cyan
}

local ZoneColorsDim = {
    Color(70, 20, 20),
    Color(20, 70, 20),
    Color(20, 30, 70),
    Color(70, 70, 20),
    Color(70, 20, 70),
    Color(20, 70, 70),
}

net.Receive("ACE_MineDetector_UpdateMines", function()
    DetectedMines = {}
    local count = net.ReadUInt(8)
    for _ = 1, count do
        table.insert(DetectedMines, {
            position = net.ReadVector(),
            distance = net.ReadFloat(),
            canDisarm = net.ReadBool()
        })
    end
end)

net.Receive("ACE_MineDetector_Sequence", function()
    local length = net.ReadUInt(4)
    MinigameSequence = {}
    for _ = 1, length do
        table.insert(MinigameSequence, net.ReadUInt(4))
    end
    ZoneCount = net.ReadUInt(4)
    IsUltraHardMode = net.ReadBool()
end)

net.Receive("ACE_MineDetector_ZoneOrder", function()
    local count = net.ReadUInt(4)
    ZoneOrder = {}
    for i = 1, count do
        ZoneOrder[i] = net.ReadUInt(4)
    end
end)

function SWEP:OnThink()
    local closestDist = self:GetClosestMineDistance()
    local minigameState = self:GetMinigameState()

    if closestDist > 0 and minigameState == 0 then
        self:HandleBeeping(closestDist)
    end
end

function SWEP:HandleBeeping(distance)
    local curTime = CurTime()
    local distanceRatio = math.Clamp(distance / self.DetectionRange, 0, 1)
    local beepInterval = Lerp(distanceRatio, self.MinBeepInterval, self.MaxBeepInterval)

    if curTime >= LastBeepTime + beepInterval then
        LastBeepTime = curTime
        surface.PlaySound(BeepSounds[math.random(#BeepSounds)])
    end
end

function SWEP:DoDrawCrosshair(x, y)
    local minigameState = self:GetMinigameState()

    if minigameState > 0 then
        self:DrawMinigameUI(x, y)
        return true
    end

    -- Crosshair
    surface.SetDrawColor(0, 255, 0, 200)
    surface.DrawLine(x - 8, y, x + 8, y)
    surface.DrawLine(x, y - 8, x, y + 8)

    -- Stored count
    local storedCount = self:GetStoredMineCount()
    if storedCount > 0 then
        surface.SetFont("Trebuchet18")
        surface.SetTextColor(255, 255, 255, 180)
        surface.SetTextPos(x + 12, y + 12)
        surface.DrawText(storedCount)
    end

    -- Proximity indicator
    local closestDist = self:GetClosestMineDistance()
    if closestDist > 0 then
        local canDisarm = closestDist <= self.DisarmRange
        local pulse = math.sin(CurTime() * (canDisarm and 6 or 3)) * 0.3 + 0.7
        local radius = (canDisarm and 20 or 30) * pulse

        if canDisarm then
            surface.SetDrawColor(0, 255, 0, 200)
        else
            local urgency = 1 - (closestDist / self.DetectionRange)
            surface.SetDrawColor(255, 150 * (1 - urgency), 0, 150 + urgency * 100)
        end

        local segments = 20
        for i = 1, segments do
            local ang1 = math.rad((i - 1) / segments * 360)
            local ang2 = math.rad(i / segments * 360)
            surface.DrawLine(
                x + math.cos(ang1) * radius,
                y + math.sin(ang1) * radius,
                x + math.cos(ang2) * radius,
                y + math.sin(ang2) * radius
            )
        end
    end

    return true
end

function SWEP:DrawMinigameUI(x, y)
    local state = self:GetMinigameState()
    local showingZone = self:GetShowingZone()
    local sliderPos = self:GetSliderPosition()
    local zonesShuffled = self:GetZonesShuffled()
    local zoneCount = self:GetZoneCount()
    local isUltraHard = self:GetIsUltraHard()

    local panelW = 260 + zoneCount * 22
    local panelH = 80
    local panelX, panelY = x - panelW / 2, y - panelH / 2

    -- Background (red tint for ultra hard)
    if isUltraHard then
        surface.SetDrawColor(20, 5, 5, 240)
    else
        surface.SetDrawColor(5, 5, 5, 230)
    end
    surface.DrawRect(panelX, panelY, panelW, panelH)

    -- Border (red for ultra hard)
    if isUltraHard then
        local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7
        surface.SetDrawColor(150 * pulse, 20, 20, 255)
    else
        surface.SetDrawColor(30, 30, 30, 255)
    end
    surface.DrawOutlinedRect(panelX, panelY, panelW, panelH, isUltraHard and 2 or 1)

    -- Zone bar
    local barPadding = 15
    local barX = panelX + barPadding
    local barY = panelY + 15
    local barW = panelW - barPadding * 2
    local barH = 50
    local zoneW = barW / zoneCount

    for i = 1, zoneCount do
        local zoneX = barX + (i - 1) * zoneW
        local colorIndex = ZoneOrder[i] or i
        local color

        if state == 1 then
            -- Memorize: show colors, light up active
            if showingZone == colorIndex then
                color = ZoneColors[colorIndex]
            else
                color = ZoneColorsDim[colorIndex]
            end
        else
            -- Replay: all dimmed, no hints
            color = ZoneColorsDim[colorIndex]
        end

        surface.SetDrawColor(color)
        surface.DrawRect(zoneX + 1, barY + 1, zoneW - 2, barH - 2)

        if i < zoneCount then
            surface.SetDrawColor(15, 15, 15, 255)
            surface.DrawRect(zoneX + zoneW - 1, barY, 2, barH)
        end
    end

    -- Shuffle flash effect
    if zonesShuffled and state == 2 then
        local shuffleAlpha = math.max(0, 150 - (CurTime() % 1) * 200)
        if shuffleAlpha > 0 then
            surface.SetDrawColor(255, 255, 255, shuffleAlpha)
            surface.DrawOutlinedRect(barX - 2, barY - 2, barW + 4, barH + 4, 2)
        end
    end

    -- Slider
    if state == 2 then
        local sliderX = barX + sliderPos * barW

        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawRect(sliderX - 4, barY - 2, 8, barH + 4)

        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(sliderX - 2, barY - 4, 4, barH + 8)

        surface.DrawRect(sliderX - 4, barY - 6, 8, 3)
        surface.DrawRect(sliderX - 4, barY + barH + 3, 8, 3)
    end

    -- Progress dots
    local totalSteps = #MinigameSequence
    if totalSteps > 0 then
        local currentIndex = self:GetCurrentSequenceIndex()
        local dotY = panelY + panelH - 10
        local dotSpacing = 8
        local dotsStartX = x - (totalSteps * dotSpacing) / 2

        for i = 1, totalSteps do
            local dotX = dotsStartX + (i - 1) * dotSpacing + 2

            if state == 1 then
                surface.SetDrawColor(60, 60, 60, 255)
            else
                if i < currentIndex then
                    surface.SetDrawColor(0, 180, 0, 255)
                elseif i == currentIndex then
                    local pulse = math.sin(CurTime() * 8) * 0.4 + 0.6
                    surface.SetDrawColor(255 * pulse, 255 * pulse, 255 * pulse, 255)
                else
                    surface.SetDrawColor(40, 40, 40, 255)
                end
            end

            surface.DrawRect(dotX, dotY, 4, 4)
        end
    end

    -- Speed bars
    if state == 2 then
        local speed = self:GetCurrentSliderSpeed()
        local speedLevel = math.floor((speed - 0.4) / 0.1)

        for i = 1, math.min(speedLevel, 10) do
            local barHeight = 2 + i * 2
            local r = math.min(120 + i * 14, 255)
            local g = math.max(100 - i * 10, 0)
            surface.SetDrawColor(r, g, 30, 200)
            surface.DrawRect(panelX + panelW - 5 - i * 4, panelY + panelH - 5 - barHeight, 3, barHeight)
        end
    end
end

function SWEP:DrawHUD()
    if not self:GetIsScanning() then return end
    if self:GetMinigameState() > 0 then return end

    -- Draw mine markers
    for _, mineData in ipairs(DetectedMines) do
        self:DrawMineMarker(mineData)
    end

    -- Draw radar
    self:DrawRadar()
end

function SWEP:DrawMineMarker(mineData)
    local screenPos = mineData.position:ToScreen()
    if not screenPos.visible then return end

    local x, y = screenPos.x, screenPos.y

    local color
    if mineData.canDisarm then
        color = Color(0, 255, 0, 220)
    else
        local ratio = math.Clamp(mineData.distance / self.DetectionRange, 0, 1)
        color = Color(255, 200 * (1 - ratio), 0, 180)
    end

    surface.SetDrawColor(color)

    local size = mineData.canDisarm and 14 or 10

    for offset = 0, 3 do
        local s = size - offset * 2
        if s > 0 then
            surface.DrawLine(x, y - s, x - s * 0.6, y + s * 0.5)
            surface.DrawLine(x - s * 0.6, y + s * 0.5, x + s * 0.6, y + s * 0.5)
            surface.DrawLine(x + s * 0.6, y + s * 0.5, x, y - s)
        end
    end
end

function SWEP:DrawRadar()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- Bigger, more visible radar
    local size = 120
    local padding = 25
    local centerX = ScrW() - padding - size / 2
    local centerY = ScrH() - padding - size / 2

    -- Solid background
    surface.SetDrawColor(0, 0, 0, 180)
    draw.NoTexture()

    -- Draw filled circle background
    local segments = 32
    for r = size / 2, 5, -5 do
        local alpha = 180 - (size / 2 - r) * 2
        surface.SetDrawColor(0, 10, 0, alpha)
        for i = 1, segments do
            local ang1 = math.rad((i - 1) / segments * 360)
            local ang2 = math.rad(i / segments * 360)

            surface.DrawLine(
                centerX + math.cos(ang1) * r,
                centerY + math.sin(ang1) * r,
                centerX + math.cos(ang2) * r,
                centerY + math.sin(ang2) * r
            )
        end
    end

    -- Outer ring
    surface.SetDrawColor(0, 150, 0, 255)
    for i = 1, segments do
        local ang1 = math.rad((i - 1) / segments * 360)
        local ang2 = math.rad(i / segments * 360)
        surface.DrawLine(
            centerX + math.cos(ang1) * size / 2,
            centerY + math.sin(ang1) * size / 2,
            centerX + math.cos(ang2) * size / 2,
            centerY + math.sin(ang2) * size / 2
        )
    end

    -- Inner rings
    surface.SetDrawColor(0, 80, 0, 150)
    for _, ringSize in ipairs({0.66, 0.33}) do
        local r = size / 2 * ringSize
        for i = 1, segments do
            local ang1 = math.rad((i - 1) / segments * 360)
            local ang2 = math.rad(i / segments * 360)
            surface.DrawLine(
                centerX + math.cos(ang1) * r,
                centerY + math.sin(ang1) * r,
                centerX + math.cos(ang2) * r,
                centerY + math.sin(ang2) * r
            )
        end
    end

    -- Cross lines
    surface.SetDrawColor(0, 60, 0, 100)
    surface.DrawLine(centerX - size / 2, centerY, centerX + size / 2, centerY)
    surface.DrawLine(centerX, centerY - size / 2, centerX, centerY + size / 2)

    -- Player direction indicator (fixed at top - player is always looking "up" on radar)
    surface.SetDrawColor(0, 255, 0, 255)
    -- Triangle pointing up
    local triSize = 8
    surface.DrawLine(centerX, centerY - triSize, centerX - triSize * 0.6, centerY + triSize * 0.3)
    surface.DrawLine(centerX - triSize * 0.6, centerY + triSize * 0.3, centerX + triSize * 0.6, centerY + triSize * 0.3)
    surface.DrawLine(centerX + triSize * 0.6, centerY + triSize * 0.3, centerX, centerY - triSize)

    -- Mine blips (relative to player facing direction)
    local eyePos = owner:EyePos()
    local eyeYaw = owner:EyeAngles().y

    for _, mineData in ipairs(DetectedMines) do
        local toMine = mineData.position - eyePos

        -- Get angle relative to player's facing direction
        local mineWorldAngle = math.deg(math.atan2(toMine.y, toMine.x))
        local relativeAngle = (mineWorldAngle * -1) + eyeYaw

        -- Convert to radar coordinates (up is forward)
        local radarAngle = math.rad(-relativeAngle + 90)

        local mineDist = math.Clamp(mineData.distance / self.DetectionRange, 0, 1)
        local blipDist = size / 2 * mineDist * 0.9

        local blipX = centerX + math.cos(radarAngle) * blipDist
        local blipY = centerY - math.sin(radarAngle) * blipDist  -- Negative because screen Y is inverted

        -- Blip color
        if mineData.canDisarm then
            surface.SetDrawColor(0, 255, 0, 255)
        else
            -- Pulsing red
            local pulse = math.sin(CurTime() * 5 + mineData.distance) * 0.3 + 0.7
            surface.SetDrawColor(255 * pulse, 50, 0, 255)
        end

        -- Draw blip (small square with glow effect)
        surface.DrawRect(blipX - 4, blipY - 4, 8, 8)
        surface.SetDrawColor(255, 255, 255, 100)
        surface.DrawOutlinedRect(blipX - 4, blipY - 4, 8, 8, 1)
    end

    -- Sweep line effect
    local sweepAngle = (CurTime() * 2) % (math.pi * 2)
    surface.SetDrawColor(0, 255, 0, 100)
    local sweepX = centerX + math.cos(sweepAngle) * size / 2
    local sweepY = centerY + math.sin(sweepAngle) * size / 2
    surface.DrawLine(centerX, centerY, sweepX, sweepY)

    -- Fading trail
    for i = 1, 8 do
        local trailAngle = sweepAngle - i * 0.1
        local alpha = 100 - i * 12
        if alpha > 0 then
            surface.SetDrawColor(0, 255, 0, alpha)
            local trailX = centerX + math.cos(trailAngle) * size / 2
            local trailY = centerY + math.sin(trailAngle) * size / 2
            surface.DrawLine(centerX, centerY, trailX, trailY)
        end
    end

    -- Label
    surface.SetFont("Trebuchet18")
    surface.SetTextColor(0, 200, 0, 200)
    local labelW = surface.GetTextSize("RADAR")
    surface.SetTextPos(centerX - labelW / 2, centerY + size / 2 + 5)
    surface.DrawText("RADAR")
end

hook.Add("HUDPaint", "ACE_MineDetector_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "weapon_ace_minedetector" then return end

    wep:DrawHUD()
end)