AddCSLuaFile("shared.lua")
SWEP.Base = "weapon_ace_base"
--basic
SWEP.PrintName     = "Mine Detector"
SWEP.Category      = "ACE Weapons"
SWEP.SubCategory   = "Equipment"
SWEP.Purpose       = "Detects and disarms ground mines"
SWEP.Instructions  = "Approach carefully. Disarm requires focus."
SWEP.Author        = "ACE Team"

SWEP.Spawnable     = true
SWEP.Slot          = 5
SWEP.SlotPos       = 1

-- Visual
SWEP.ViewModelFlip   = false
SWEP.ViewModel       = "models/weapons/c_slam.mdl"
SWEP.WorldModel      = "models/weapons/w_slam.mdl"
SWEP.HoldType        = "slam"
SWEP.CSMuzzleFlashes = false

-- No shooting
SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = 0
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "CombineHeavyCannon"

-- Movement
SWEP.CarrySpeedMul = 0.5
SWEP.DeployDelay   = 1

-- Detection settings
SWEP.DetectionRange    = 300
SWEP.DetectionCone     = 60
SWEP.DisarmRange       = 150
SWEP.ScanInterval      = 0.1

-- Sound settings
SWEP.MinBeepInterval   = 0.08
SWEP.MaxBeepInterval   = 1.5

-- Disable base features
SWEP.HeatMax           = 0
SWEP.HasScope          = false

-- Ultra hard mode chance (10%)
SWEP.UltraHardChance   = 0.10

-- Minigame sounds
SWEP.MinigameSounds = {
    zone = {
        "buttons/button17.wav",
        "buttons/button14.wav",
        "buttons/button15.wav",
        "buttons/button16.wav",
        "buttons/button18.wav",
        "buttons/button19.wav",
    },
    fail = "buttons/button10.wav",
    complete = "buttons/bell1.wav",
    start = "buttons/blip1.wav",
    shuffle = "buttons/lever7.wav",
}

-- Base difficulty settings
SWEP.MinigameDifficulty = {
    ["APL"] = {
        sequenceLength = 3,
        baseSliderSpeed = 0.45,
        speedMultiplier = 1.20,
        timeLimit = 15,
        sequenceDelay = 0.7,
    },
    ["Bounding-APL"] = {
        sequenceLength = 4,
        baseSliderSpeed = 0.55,
        speedMultiplier = 1.25,
        timeLimit = 13,
        sequenceDelay = 0.6,
    },
    ["ATL"] = {
        sequenceLength = 4,
        baseSliderSpeed = 0.65,
        speedMultiplier = 1.25,
        timeLimit = 12,
        sequenceDelay = 0.55,
    },
    ["SLAM"] = {
        sequenceLength = 5,
        baseSliderSpeed = 0.70,
        speedMultiplier = 1.28,
        timeLimit = 11,
        sequenceDelay = 0.5,
    },
    ["default"] = {
        sequenceLength = 3,
        baseSliderSpeed = 0.5,
        speedMultiplier = 1.20,
        timeLimit = 14,
        sequenceDelay = 0.65,
    },
}

-- Ultra hard mode overrides
SWEP.UltraHardSettings = {
    zoneCount = 6,
    shuffleZones = true,
    extraSequence = 2,      -- Add 2 more steps
    speedBonus = 0.15,      -- Add to base speed
    speedMultiplierBonus = 0.1,
}

function SWEP:SetupDataTables()
    local BaseClass = baseclass.Get(self.Base)
    if BaseClass and BaseClass.SetupDataTables then
        BaseClass.SetupDataTables(self)
    end

    self:NetworkVar("Float", 0, "ClosestMineDistance")
    self:NetworkVar("Float", 1, "SliderPosition")
    self:NetworkVar("Float", 2, "CurrentSliderSpeed")
    self:NetworkVar("Entity", 0, "ClosestMine")
    self:NetworkVar("Entity", 1, "TargetMine")
    self:NetworkVar("Int", 1, "StoredMineCount")
    self:NetworkVar("Int", 2, "MinigameState")          -- 0=inactive, 1=memorize, 2=replay
    self:NetworkVar("Int", 3, "CurrentSequenceIndex")
    self:NetworkVar("Int", 4, "ShowingZone")
    self:NetworkVar("Int", 5, "ZoneCount")
    self:NetworkVar("Bool", 1, "IsScanning")
    self:NetworkVar("Bool", 2, "ZonesShuffled")
    self:NetworkVar("Bool", 3, "IsUltraHard")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:ResetState()

    self.DetectedMines = {}
    self.NextScan = 0
    self.NextBeep = 0

    self.Minigame = {
        sequence = {},
        difficulty = nil,
        startTime = 0,
        sliderDirection = 1,
        nextZoneShow = 0,
        currentShowIndex = 0,
        replayStartTime = 0,
        zoneOrder = {1, 2, 3, 4},
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

function SWEP:GetMineDifficulty(mine)
    if not IsValid(mine) then return self.MinigameDifficulty["default"] end
    local mineType = self:IdentifyMineType(mine)
    return self.MinigameDifficulty[mineType] or self.MinigameDifficulty["default"]
end

function SWEP:IdentifyMineType(mine)
    if not IsValid(mine) then return "default" end

    if mine:GetClass() == "ace_slammine" then
        return "SLAM"
    end

    for mineId, mineData in pairs(ACE.MineData or {}) do
        if mine:GetModel() == mineData.model then
            return mineId
        end
    end

    if mine.ignoreplayers then
        return "ATL"
    elseif mine.IsJumper then
        return "Bounding-APL"
    else
        return "APL"
    end
end

function SWEP:GetCurrentZone()
    local pos = self:GetSliderPosition()
    local zoneCount = self:GetZoneCount()
    local zoneWidth = 1 / zoneCount

    for i = 1, zoneCount do
        if pos < i * zoneWidth then
            return i
        end
    end

    return zoneCount
end

function SWEP:IsInDetectionCone(targetPos)
    local owner = self:GetOwner()
    if not IsValid(owner) then return false end

    local eyePos = owner:EyePos()
    local forward = owner:EyeAngles():Forward()
    local toTarget = (targetPos - eyePos):GetNormalized()

    local dot = forward:Dot(toTarget)
    local angleToTarget = math.deg(math.acos(math.Clamp(dot, -1, 1)))

    return angleToTarget <= (self.DetectionCone / 2)
end

function SWEP:GetMinesInRange()
    local owner = self:GetOwner()
    if not IsValid(owner) then return {} end

    local eyePos = owner:EyePos()
    local mines = {}

    local function AddMine(ent, isSLAM)
        if not IsValid(ent) then return end

        local minePos = ent:GetPos()
        local distance = eyePos:Distance(minePos)

        if distance <= self.DetectionRange and self:IsInDetectionCone(minePos) then
            table.insert(mines, {
                entity = ent,
                distance = distance,
                position = minePos,
                canDisarm = distance <= self.DisarmRange,
                isSLAM = isSLAM or false
            })
        end
    end

    for _, ent in ipairs(ents.FindByClass("ace_mine")) do
        AddMine(ent, false)
    end

    for _, ent in ipairs(ents.FindByClass("ace_slammine")) do
        AddMine(ent, true)
    end

    table.sort(mines, function(a, b) return a.distance < b.distance end)
    return mines
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:Reload() end

function SWEP:Think()
    self:OnThink()
end

function SWEP:OnThink() end

function SWEP:Holster()
    if SERVER then
        self:SetIsScanning(false)
        self:SetMinigameState(0)
        self:SetShowingZone(0)
    end
    return true
end

function SWEP:Deploy()
    self:SetNextPrimaryFire(CurTime() + self.DeployDelay)
    self:SetNextSecondaryFire(CurTime() + self.DeployDelay)

    if SERVER then
        self:SetIsScanning(true)
        self:SetMinigameState(0)
        self:SetShowingZone(0)
    end

    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end