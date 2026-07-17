--[[---------------------------------------------------------
Initializes the effect. The data is a table of data
which was passed from the server.
-----------------------------------------------------------]]

local EffectDebugCvar = CreateClientConVar("acf_effect_debug", "0", true, false, "Log ACE clientside effect entry/exit.")
local function DebugEffect(tag)
    if EffectDebugCvar:GetBool() then
        print(("[ACE Effect] %s"):format(tag))
    end
end

function EFFECT:Init( data )
    DebugEffect("acf_smoke Init:Enter")
    self.Origin = data:GetOrigin()
    self.DirVec = data:GetNormal() --Used for shell flight velocity
    self.DirVecNormal = self.DirVec:GetNormalized()
    self.Colour = data:GetStart()
    self.Radius = data:GetRadius() --Slow deployinging smoke. Radius in meters
    self.Magnitude = data:GetMagnitude() --Fast deploying WP. Radius in meters
    --print(self.Radius .. " " .. self.Magnitude)
    self.Emitter = ParticleEmitter( self.Origin )

    local ImpactTr = { }
        ImpactTr.start = self.Origin - self.DirVecNormal * 20
        ImpactTr.endpos = self.Origin + self.DirVecNormal * 20
        ImpactTr.mins = Vector(0,0,0)
        ImpactTr.maxs = Vector(0,0,0)
    local Impact = util.TraceHull(ImpactTr)										--Trace to see if it will hit anything
    self.Normal = Impact.HitNormal

    local GroundTr = { }
        GroundTr.start = self.Origin + Vector(0,0,1)
        GroundTr.endpos = self.Origin - Vector(0,0,1) * self.Radius
        GroundTr.mask = 131083
        GroundTr.mins = Vector(0,0,0)
        GroundTr.maxs = Vector(0,0,0)
    local Ground = util.TraceHull(GroundTr)

    local SmokeColor = self.Colour or Vector(255,255,255)
    if not Ground.HitWorld then Ground.HitNormal = Vector(0,0,1) end

    --[[if adjusting, update display data / crate text in smoke round
    if self.Magnitude > 0 then
        --self:SmokeFiller( Ground, SmokeColor, self.Magnitude * 1.25, 1.0, 6 + self.Magnitude / 10 ) --quick build and dissipate
    end

    if self.Radius > 0 then
        --self:SmokeFiller( Ground, SmokeColor, self.Radius * 1.25, 0.15, 20 + self.Radius / 4 ) --slow build but long lasting
    end
    ]]--
    local SmokeMul = 3

    self:StartSmoke(Ground, SmokeColor, self.DirVec, self.Magnitude * SmokeMul, math.max(self.Radius * 4,self.Magnitude) * SmokeMul ) --The initial puff and streamers before the smoke gets up to size

    local Radius = math.max(self.Radius + self.Magnitude) * 15
    local Flash = EffectData()
        Flash:SetOrigin( self.Origin)
        Flash:SetNormal( self.DirVecNormal )
        Flash:SetRadius( math.Round(math.max(Radius / 39.37, 1),2) )
    util.Effect( "ACF_Scaled_Explosion", Flash )

    ACE.SBlast( self.Origin, self.Magnitude, false, Ground.HitWorld ) --hitwater is false

    self.Emitter:Finish()
    DebugEffect("acf_smoke Init:Exit")
end

function EFFECT:StartSmoke( _, SmokeColor, ShootVector, WPRadius, SRadius ) --GTR
    DebugEffect("acf_smoke StartSmoke:Enter")

    local SmokeRadiusMul = 40 --Size multiplier for smoke particles to be 1 meter
    local StartTime = 0.75

    -- Calculate the wind effect on velocity and gravity
    -- Apply wind effect based on wind direction and windStrength
    local snorm = ShootVector:GetNormalized()
    local velocity = snorm * 12 * 39.37
    local gravity1 = Vector(0, 0, -65) --Used for initial smoke puff. Meant to be predictable.
    local gravity2 = gravity1 + ACF.Wind * 0.2
    local Speed = velocity:Length()
    --velocity = Vector(0, 0, 0)
    --gravity = Vector(0, 0, 0)



    for _ = 0,3 do

        --velocity = velocity * 1.25
        gravity1 = gravity1 * 1.35
        gravity2 = gravity2 * 1.35

        for _ = 0, 2 do

            local Smoke = self.Emitter:Add("particle/particle_smokegrenade", self.Origin)
            if Smoke then
                Smoke:SetVelocity(velocity)
                Smoke:SetLifeTime(0)
                Smoke:SetDieTime(StartTime)
                Smoke:SetStartAlpha(0)
                Smoke:SetEndAlpha(255)
                Smoke:SetStartSize(WPRadius * SmokeRadiusMul / StartTime / 4 * 1)
                Smoke:SetEndSize(WPRadius * SmokeRadiusMul * 1)
                Smoke:SetAirResistance(0)
                Smoke:SetGravity(gravity1)
                Smoke:SetCollide( true )
                Smoke:SetColor(SmokeColor.x, SmokeColor.y, SmokeColor.z)
            end

        end

        local Smoke = self.Emitter:Add("particle/smokesprites_000" .. math.random(1,6), self.Origin)
        if Smoke then
            Smoke:SetVelocity(velocity)
            Smoke:SetLifeTime(0)
            Smoke:SetDieTime(StartTime)
            Smoke:SetStartAlpha(30)
            Smoke:SetEndAlpha(255)
            Smoke:SetStartSize(WPRadius * SmokeRadiusMul / StartTime / 4 * 1)
            Smoke:SetEndSize(WPRadius * SmokeRadiusMul * 1)
            Smoke:SetAirResistance(0)
            Smoke:SetGravity(gravity1)
            Smoke:SetCollide( true )
            Smoke:SetColor(SmokeColor.x, SmokeColor.y, SmokeColor.z)
        end

        for _ = 0, 7 do

        local Smoke = self.Emitter:Add("effects/splash2", self.Origin)
        if Smoke then
            Smoke:SetVelocity( 1.5 * Speed * (snorm + VectorRand() * 0.4) )
            Smoke:SetLifeTime(0)
            Smoke:SetDieTime(StartTime * 1.5)
            Smoke:SetStartAlpha(255)
            Smoke:SetEndAlpha(30)
            Smoke:SetStartSize(WPRadius * SmokeRadiusMul / StartTime / 24)
            Smoke:SetEndSize(WPRadius * SmokeRadiusMul / 24 )
            Smoke:SetAirResistance(0)
            Smoke:SetGravity(gravity1 * 3)
            Smoke:SetCollide( true )
            Smoke:SetColor(SmokeColor.x, SmokeColor.y, SmokeColor.z)
            local Length = 25 * WPRadius * SmokeRadiusMul / StartTime / 38
            Smoke:SetStartLength( Length )
            Smoke:SetEndLength( Length * 1 )
        end

        end

        local OffsetPos = self.Origin + velocity * StartTime + 0.5 * gravity1 * StartTime^2

        local tr2 = util.TraceHull( {
            start = self.Origin,
            endpos = OffsetPos,
            mins = vector_origin,
            maxs = vector_origin
        } )

        if tr2.Hit then
            OffsetPos = self.Origin
        end

        for _ = 0, 3 do

            local Smoke = self.Emitter:Add("particle/particle_smokegrenade1", OffsetPos)
            if Smoke then
                Smoke:SetVelocity(velocity + gravity1 * StartTime)
                Smoke:SetLifeTime(-StartTime)
                Smoke:SetDieTime(10) --20
                Smoke:SetStartAlpha(255)
                Smoke:SetEndAlpha(10) --10 for debugging. 15 for actuality
                Smoke:SetStartSize(WPRadius * SmokeRadiusMul)
                Smoke:SetEndSize(WPRadius * SmokeRadiusMul)
                Smoke:SetRollDelta(math.Rand(-0.2, 0.2))
                Smoke:SetAirResistance(50)
                Smoke:SetGravity(gravity2 + VectorRand() * WPRadius * 5)
                Smoke:SetCollide( true )
                Smoke:SetColor(SmokeColor.x, SmokeColor.y, SmokeColor.z)
            end

        end

        for _ = 0, 3 do

            local Smoke = self.Emitter:Add("particle/smokesprites_000" .. math.random(1,6), OffsetPos)
            if Smoke then
                Smoke:SetVelocity(velocity + gravity1 * StartTime)
                Smoke:SetLifeTime(-StartTime)
                Smoke:SetDieTime(15) --20
                Smoke:SetStartAlpha(255)
                Smoke:SetEndAlpha(10)
                Smoke:SetStartSize(WPRadius * SmokeRadiusMul)
                Smoke:SetEndSize(WPRadius * SmokeRadiusMul)
                Smoke:SetRollDelta(math.Rand(-0.3, 0.3))
                Smoke:SetAirResistance(50)
                Smoke:SetGravity(gravity2 + VectorRand() * WPRadius * 5)
                Smoke:SetCollide( true )
                Smoke:SetColor(SmokeColor.x, SmokeColor.y, SmokeColor.z)
            end

        end



    for _ = 0, 3 do

        local Smoke = self.Emitter:Add("particle/smokesprites_000" .. math.random(1,6), OffsetPos)
        if Smoke then
            Smoke:SetVelocity(velocity + gravity1 * StartTime)
            Smoke:SetLifeTime(-StartTime)
            Smoke:SetDieTime(35) --25
            Smoke:SetStartAlpha(255)
            Smoke:SetEndAlpha(5)
            Smoke:SetStartSize(math.max(WPRadius * SmokeRadiusMul,SRadius * SmokeRadiusMul / 25))
            Smoke:SetEndSize(SRadius * SmokeRadiusMul)
            Smoke:SetRollDelta(math.Rand(-0.3, 0.3))
            Smoke:SetAirResistance(50)
            Smoke:SetGravity(gravity2)
            Smoke:SetCollide( true )
            Smoke:SetColor(SmokeColor.x, SmokeColor.y, SmokeColor.z)
        end

    end



    --[[
    --Radius Debugging Circle
    local Test = SRadius * 1.3 * 1 --1.3 for lethal radius. 1.0 for Indicated radius of HE
    local B = self.Emitter:Add( "effects/splashwake3", self.Origin )

    if B then
        B:SetLifeTime( 0 )
        B:SetDieTime( 6 )
        B:SetStartAlpha( 255 )
        B:SetEndAlpha( 255 )
        B:SetStartSize( 20.915 * Test )
        B:SetEndSize( 20.915 * Test )
        B:SetColor( 255, 255, 255 )
    end
    ]]--

    end

    DebugEffect("acf_smoke StartSmoke:Exit")

end




--keep this here, error pops up if it's removed
function EFFECT:Render()
end

