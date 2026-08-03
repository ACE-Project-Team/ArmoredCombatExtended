AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

SWEP.Weight = 5

util.AddNetworkString("ACE_MineDetector_UpdateMines")
util.AddNetworkString("ACE_MineDetector_Sequence")
util.AddNetworkString("ACE_MineDetector_ZoneOrder")

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:ResetState()

    self.DetectedMines = {}
    self.StoredMineTypes = {}
    self.NextScan = 0

    self.Minigame = {
        sequence = {},
        difficulty = nil,
        startTime = 0,
        sliderDirection = 1,
        nextZoneShow = 0,
        currentShowIndex = 0,
        replayStartTime = 0,
        zoneOrder = {1, 2, 3, 4},
        isUltraHard = false,
        shouldShuffle = false,
    }
end

function SWEP:ResetState()
    self:SetClosestMineDistance(-1)
    self:SetStoredMineCount(#(self.StoredMineTypes or {}))
    self:SetIsScanning(true)
    self:SetMinigameState(0)
    self:SetSliderPosition(0)
    self:SetCurrentSequenceIndex(0)
    self:SetShowingZone(0)
    self:SetZoneCount(4)
    self:SetZonesShuffled(false)
    self:SetIsUltraHard(false)
    self:SetCurrentSliderSpeed(0.5)
    self:SetTargetMine(NULL)
end

function SWEP:OnThink()
    if not self:GetIsScanning() then return end

    local curTime = CurTime()
    local minigameState = self:GetMinigameState()

    if minigameState > 0 then
        self:UpdateMinigame(curTime)
        return
    end

    if curTime >= self.NextScan then
        self.NextScan = curTime + self.ScanInterval
        self:ScanForMines()
    end
end

function SWEP:ScanForMines()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.DetectedMines = self:GetMinesInRange()

    if #self.DetectedMines > 0 then
        local closest = self.DetectedMines[1]
        self:SetClosestMineDistance(closest.distance)
        self:SetClosestMine(closest.entity)
    else
        self:SetClosestMineDistance(-1)
        self:SetClosestMine(NULL)
    end

    self:NetworkDetectedMines()
end

function SWEP:NetworkDetectedMines()
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    net.Start("ACE_MineDetector_UpdateMines")
        net.WriteUInt(#self.DetectedMines, 8)
        for _, mineData in ipairs(self.DetectedMines) do
            net.WriteVector(mineData.position)
            net.WriteFloat(mineData.distance)
            net.WriteBool(mineData.canDisarm)
        end
    net.Send(owner)
end

-------------------------------------------------
-- MINIGAME
-------------------------------------------------

local function ShuffleTable(tbl)
    local shuffled = {}
    for i, v in ipairs(tbl) do
        shuffled[i] = v
    end

    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    return shuffled
end

function SWEP:StartMinigame(mine)
    local owner = self:GetOwner()
    if not IsValid(owner) or not IsValid(mine) then return end

    local baseDifficulty = self:GetMineDifficulty(mine)

    -- Roll for ultra hard mode (rare!)
    local isUltraHard = math.random() < self.UltraHardChance
    local ultraSettings = self.UltraHardSettings

    -- Determine zone count
    local zoneCount = isUltraHard and ultraSettings.zoneCount or 4

    -- Calculate actual difficulty values
    local sequenceLength = baseDifficulty.sequenceLength
    local baseSpeed = baseDifficulty.baseSliderSpeed
    local speedMult = baseDifficulty.speedMultiplier

    if isUltraHard then
        sequenceLength = sequenceLength + ultraSettings.extraSequence
        baseSpeed = baseSpeed + ultraSettings.speedBonus
        speedMult = speedMult + ultraSettings.speedMultiplierBonus
    end

    -- Initial zone order
    local zoneOrder = {}
    for i = 1, zoneCount do
        zoneOrder[i] = i
    end

    -- Generate sequence (no repeats)
    local sequence = {}
    local lastZone = 0
    for _ = 1, sequenceLength do
        local zone
        repeat
            zone = math.random(1, zoneCount)
        until zone ~= lastZone
        table.insert(sequence, zone)
        lastZone = zone
    end

    self.Minigame = {
        sequence = sequence,
        difficulty = baseDifficulty,
        startTime = CurTime(),
        sliderDirection = 1,
        nextZoneShow = CurTime() + 0.5,
        currentShowIndex = 0,
        replayStartTime = 0,
        zoneOrder = zoneOrder,
        isUltraHard = isUltraHard,
        shouldShuffle = isUltraHard and ultraSettings.shuffleZones,
        actualSpeedMult = speedMult,
        timeLimit = baseDifficulty.timeLimit,
    }

    self:SetTargetMine(mine)
    self:SetMinigameState(1)
    self:SetCurrentSequenceIndex(0)
    self:SetSliderPosition(0)
    self:SetShowingZone(0)
    self:SetZoneCount(zoneCount)
    self:SetZonesShuffled(false)
    self:SetIsUltraHard(isUltraHard)
    self:SetCurrentSliderSpeed(baseSpeed)

    -- Send to client
    net.Start("ACE_MineDetector_Sequence")
        net.WriteUInt(#sequence, 4)
        for _, zone in ipairs(sequence) do
            net.WriteUInt(zone, 4)
        end
        net.WriteUInt(zoneCount, 4)
        net.WriteBool(isUltraHard)
    net.Send(owner)

    self:SendZoneOrder(zoneOrder)

    owner:EmitSound(self.MinigameSounds.start, 60, isUltraHard and 80 or 100)

    -- Ominous sound for ultra hard
    if isUltraHard then
        timer.Simple(0.2, function()
            if IsValid(owner) then
                owner:EmitSound("ambient/alarms/warningbell1.wav", 50, 120)
            end
        end)
    end
end

function SWEP:SendZoneOrder(zoneOrder)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    net.Start("ACE_MineDetector_ZoneOrder")
        net.WriteUInt(#zoneOrder, 4)
        for _, zone in ipairs(zoneOrder) do
            net.WriteUInt(zone, 4)
        end
    net.Send(owner)
end

function SWEP:ShuffleZones()
    local owner = self:GetOwner()

    self.Minigame.zoneOrder = ShuffleTable(self.Minigame.zoneOrder)
    self:SetZonesShuffled(true)

    self:SendZoneOrder(self.Minigame.zoneOrder)

    if IsValid(owner) then
        owner:EmitSound(self.MinigameSounds.shuffle, 70, 100)
    end
end

function SWEP:UpdateMinigame(curTime)
    local state = self:GetMinigameState()
    local owner = self:GetOwner()

    if not IsValid(owner) then
        self:EndMinigame(false)
        return
    end

    local mine = self:GetTargetMine()
    if not IsValid(mine) then
        self:EndMinigame(false)
        return
    end

    local distance = owner:EyePos():Distance(mine:GetPos())
    if distance > self.DisarmRange * 1.5 then
        self:EndMinigame(false)
        return
    end

    if state == 2 then
        local elapsed = curTime - self.Minigame.replayStartTime
        if elapsed > self.Minigame.timeLimit then
            self:EndMinigame(false)
            return
        end
    end

    if state == 1 then
        self:UpdateMemorizePhase(curTime)
    elseif state == 2 then
        self:UpdateReplayPhase()
    end
end

function SWEP:UpdateMemorizePhase(curTime)
    local owner = self:GetOwner()
    local delay = self.Minigame.difficulty.sequenceDelay

    if curTime >= self.Minigame.nextZoneShow then
        self:SetShowingZone(0)

        timer.Simple(0.12, function()
            if not IsValid(self) or self:GetMinigameState() ~= 1 then return end

            self.Minigame.currentShowIndex = self.Minigame.currentShowIndex + 1

            if self.Minigame.currentShowIndex <= #self.Minigame.sequence then
                local zone = self.Minigame.sequence[self.Minigame.currentShowIndex]
                self:SetShowingZone(zone)

                if IsValid(owner) then
                    owner:EmitSound(self.MinigameSounds.zone[zone] or self.MinigameSounds.zone[1], 75, 90 + zone * 8)
                end
            else
                self:SetShowingZone(0)

                if self.Minigame.shouldShuffle then
                    timer.Simple(0.3, function()
                        if not IsValid(self) then return end
                        self:ShuffleZones()

                        timer.Simple(0.5, function()
                            if not IsValid(self) then return end
                            self:StartReplayPhase()
                        end)
                    end)
                else
                    self:StartReplayPhase()
                end
            end
        end)

        self.Minigame.nextZoneShow = curTime + delay
    end
end

function SWEP:StartReplayPhase()
    self:SetMinigameState(2)
    self:SetCurrentSequenceIndex(1)
    self:SetSliderPosition(0)
    self.Minigame.replayStartTime = CurTime()
    self.Minigame.sliderDirection = 1
end

function SWEP:UpdateReplayPhase()
    local speed = self:GetCurrentSliderSpeed()
    local dt = FrameTime()
    local newPos = self:GetSliderPosition() + (speed * dt * self.Minigame.sliderDirection)

    if newPos >= 1 then
        newPos = 1
        self.Minigame.sliderDirection = -1
    elseif newPos <= 0 then
        newPos = 0
        self.Minigame.sliderDirection = 1
    end

    self:SetSliderPosition(newPos)
end

function SWEP:GetActualZoneAtPosition(visualPosition)
    local zoneCount = self:GetZoneCount()
    local zoneWidth = 1 / zoneCount

    local visualZoneIndex = 1
    for i = 1, zoneCount do
        if visualPosition < i * zoneWidth then
            visualZoneIndex = i
            break
        end
        visualZoneIndex = i
    end

    return self.Minigame.zoneOrder[visualZoneIndex]
end

function SWEP:AttemptClick()
    local state = self:GetMinigameState()
    local owner = self:GetOwner()

    if state ~= 2 then return end
    if not IsValid(owner) then return end

    local sliderPos = self:GetSliderPosition()
    local actualZone = self:GetActualZoneAtPosition(sliderPos)
    local sequenceIndex = self:GetCurrentSequenceIndex()
    local expectedZone = self.Minigame.sequence[sequenceIndex]

    if actualZone == expectedZone then
        owner:EmitSound(self.MinigameSounds.zone[actualZone] or self.MinigameSounds.zone[1], 75, 100 + sequenceIndex * 12)

        if sequenceIndex >= #self.Minigame.sequence then
            self:EndMinigame(true)
        else
            local nextIndex = sequenceIndex + 1
            self:SetCurrentSequenceIndex(nextIndex)

            local newSpeed = self:GetCurrentSliderSpeed() * self.Minigame.actualSpeedMult
            self:SetCurrentSliderSpeed(newSpeed)
        end
    else
        self:EndMinigame(false)
    end
end

function SWEP:EndMinigame(success)
    local owner = self:GetOwner()
    local mine = self:GetTargetMine()
    local isSLAM = IsValid(mine) and mine:GetClass() == "ace_slammine"

    self:SetMinigameState(0)
    self:SetSliderPosition(0)
    self:SetCurrentSequenceIndex(0)
    self:SetShowingZone(0)
    self:SetZonesShuffled(false)
    self:SetIsUltraHard(false)
    self:SetTargetMine(NULL)
    self:SetCurrentSliderSpeed(0.5)

    if not IsValid(owner) then return end

    if success then
        owner:EmitSound(self.MinigameSounds.complete, 75, 100)

        if IsValid(mine) then
            self:CollectMine(mine)
        end
    else
        owner:EmitSound(self.MinigameSounds.fail, 75, 70)

        -- 30% chance explosion on fail
        if IsValid(mine) and math.random() < 0.30 then
            timer.Simple(0.2, function()
                if not IsValid(mine) then return end

                if isSLAM then
                    -- SLAM uses Triggered flag
                    mine.Triggered = true
                    mine:Remove()
                else
                    -- Regular mines use Detonate
                    mine:Detonate()
                end
            end)
        end
    end

    self.NextScan = CurTime() + 0.5
end

function SWEP:CollectMine(mine)
    local owner = self:GetOwner()
    if not IsValid(owner) or not IsValid(mine) then return end

    local mineType = self:IdentifyMineType(mine)
    local isSLAM = mine:GetClass() == "ace_slammine"

    table.insert(self.StoredMineTypes, {
        type = mineType,
        isSLAM = isSLAM,
        bulletdata = isSLAM and table.Copy(mine.Bulletdata) or nil,
    })
    self:SetStoredMineCount(#self.StoredMineTypes)

    owner:GiveAmmo(1, self.Secondary.Ammo, true)

    -- Remove without triggering explosion
    if isSLAM then
        mine.Triggered = false  -- Ensure it doesn't explode
    end
    mine:Remove()

    self.NextScan = 0
end

-------------------------------------------------
-- INPUT
-------------------------------------------------

function SWEP:PrimaryAttack()
    local curTime = CurTime()
    if curTime < self:GetNextPrimaryFire() then return end

    self:SetNextPrimaryFire(curTime + 0.1)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local minigameState = self:GetMinigameState()

    if minigameState == 2 then
        self:AttemptClick()
        return
    end

    if minigameState == 1 then
        return
    end

    local closestMine = self:GetClosestMine()

    if not IsValid(closestMine) then
        owner:EmitSound("buttons/button10.wav", 50, 100)
        return
    end

    local distance = owner:EyePos():Distance(closestMine:GetPos())

    if distance > self.DisarmRange then
        owner:EmitSound("buttons/button10.wav", 50, 120)
        return
    end

    if owner:GetVelocity():Length() > 50 then
        return
    end

    self:StartMinigame(closestMine)
end

function SWEP:SecondaryAttack()
    local curTime = CurTime()
    if curTime < self:GetNextSecondaryFire() then return end

    self:SetNextSecondaryFire(curTime + 0.8)

    if self:GetMinigameState() > 0 then
        self:EndMinigame(false)
        return
    end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if #self.StoredMineTypes == 0 then
        owner:EmitSound("buttons/button10.wav", 50, 100)
        return
    end

    if owner:GetVelocity():Length() > 50 then
        return
    end

    local eyePos = owner:EyePos()
    local forward = owner:EyeAngles():Forward()
    local deployPos = eyePos + forward * 48

    local tr = util.TraceLine({
        start = deployPos,
        endpos = deployPos - Vector(0, 0, 100),
        filter = owner,
        mask = MASK_SOLID_BRUSHONLY
    })

    if not tr.Hit then
        return
    end

    local mineData = table.remove(self.StoredMineTypes)
    self:SetStoredMineCount(#self.StoredMineTypes)
    owner:RemoveAmmo(1, self.Secondary.Ammo)

    local mine

    if mineData.isSLAM then
        -- Recreate SLAM mine
        mine = ents.Create("ace_slammine")
        if IsValid(mine) then
            mine:SetPos(tr.HitPos + tr.HitNormal * 2)
            mine:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
            mine.Bulletdata = mineData.bulletdata
            mine.DamageOwner = owner
            mine.ExplosionDelay = 0.15
            mine:Spawn()
        end
    else
        -- Regular mine
        mine = ACE_CreateMine(mineData.type, tr.HitPos + Vector(0, 0, 5), Angle(0, owner:EyeAngles().y, 0), owner)
    end

    if IsValid(mine) then
        owner:EmitSound("weapons/slam/mine_mode.wav", 60, 100)
        self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    else
        table.insert(self.StoredMineTypes, mineData)
        self:SetStoredMineCount(#self.StoredMineTypes)
        owner:GiveAmmo(1, self.Secondary.Ammo, true)
    end
end

function SWEP:Reload()
    if self:GetMinigameState() > 0 then
        self:EndMinigame(false)
        return
    end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if #self.StoredMineTypes == 0 then
        return
    end

    local count = #self.StoredMineTypes

    self.StoredMineTypes = {}
    self:SetStoredMineCount(0)
    owner:RemoveAmmo(count, self.Secondary.Ammo)

    owner:EmitSound("physics/metal/metal_canister_impact_hard1.wav", 70, 100)

    timer.Simple(0.3, function()
        if IsValid(owner) then
            owner:EmitSound("physics/metal/metal_box_break1.wav", 60, 80)
        end
    end)

    self:SendWeaponAnim(ACT_VM_RELOAD)
end

function SWEP:Equip(newOwner)
    if IsValid(newOwner) and newOwner:IsPlayer() then
        self.NormalPlayerWalkSpeed = newOwner:GetWalkSpeed()
        self.NormalPlayerRunSpeed = newOwner:GetRunSpeed()
    end
end
