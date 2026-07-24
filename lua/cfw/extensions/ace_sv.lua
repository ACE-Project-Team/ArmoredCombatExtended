local CLASS = CFW.Classes.Contraption
if CLIENT then return end -- CFW's loader will also load this file on the client when in a singleplayer game for some reason

TraceLine = util.TraceLine

-- Maintains a table of ACE components for each contraption
do
    -- Keep projectile traces from re-entering the firing contraption, including when its physics
    -- motion makes the traceback segment overlap armor behind the muzzle.
    hook.Add("cfw.contraption.created", "CFW_ACE_BulletFilter", function(con)
        con.BulletFilter = {}
    end)

    hook.Add("cfw.contraption.entityAdded", "CFW_ACE_Entities", function(con, ent)
        if not IsValid(ent) then return end

        local class = ent:GetClass()

        if class:match("^ace_") or class:match("^acf_") then
            if not con.aceEntities then con.aceEntities = {} end
            con.aceEntities[ent] = true
        end

        con.BulletFilter = con.BulletFilter or {}
        con.BulletFilter[#con.BulletFilter + 1] = ent
        con.BulletFilter[ent] = true
    end)

    hook.Add("cfw.contraption.entityRemoved", "CFW_ACE_BulletFilter", function(con, ent)
        local filter = con.BulletFilter
        if not filter then return end

        for index = #filter, 1, -1 do
            if filter[index] == ent then
                table.remove(filter, index)
                break
            end
        end

        filter[ent] = nil
    end)

    hook.Add("cfw.contraption.entityRemoved", "CFW_ACE_Entities", function(con, ent)
        if not IsValid(ent) then return end
        if not con.aceEntities then return end

        con.aceEntities[ent] = nil

        if not next(con.aceEntities) then
            con.aceEntities = nil
        end
    end)
end

--- Returns the baseplate of a contraption
---@return Entity Baseplate The baseplate of the contraption
function CLASS:GetACEBaseplate()
    local curBase = self.aceBaseplate

    if IsValid(curBase) and IsValid(curBase:GetPhysicsObject()) and curBase:CFW_GetContraption() == self then
        return curBase
    end

    local maxConstraintCount = 0
    local fallbackBaseplate -- If the contraption doesn't have any constraints, just use something that isn't parented
    local baseplate

    for ent in pairs(self.ents) do
        if IsValid(ent) and IsValid(ent:GetPhysicsObject()) and not IsValid(ent:GetParent()) then
            local count = #constraint.GetTable(ent)

            fallbackBaseplate = ent

            if count > maxConstraintCount then
                maxConstraintCount = count
                baseplate = ent
            end
        end
    end

    self.aceBaseplate = baseplate or fallbackBaseplate

    return self.aceBaseplate
end

--- Returns the height of a contraption's baseplate above the ground
---@return number Height The height of the baseplate above the ground
function CLASS:GetACEAltitude()
    if self.aceAltitudeLastCheck and (CurTime() - self.aceAltitudeLastCheck < 0.01) then
        return self.aceAltitude
    end

    self.aceAltitudeLastCheck = CurTime()

    local baseplate = self:GetACEBaseplate()

    if not IsValid(baseplate) then return end

    local pos = baseplate:GetPos()

    local trace = TraceLine({
        start = pos,
        endpos = pos - Vector(0, 0, 10000),
        mask = MASK_SOLID_BRUSHONLY
    })

    local altitude = pos.z - trace.HitPos.z
    self.aceAltitude = altitude

    return altitude
end

--- Returns the hottest entity in a contraption and its temperature
---@return Entity
---@return number
function CLASS:GetACEHottestEntity()
    local aceEntities = self.aceEntities

    if not aceEntities then return end

    local hottest
    local highestTemp = 0

    for ent in pairs(aceEntities) do
        if ent.Heat then
            local temp = ent.Heat
            if temp > highestTemp then
                hottest = ent
                highestTemp = temp
            end
        end
    end

    return hottest, highestTemp
end

--- Returns a table of all heat sources in a contraption
---@return table
function CLASS:GetACEHotEnts()
    local aceEntities = self.aceEntities

    if not aceEntities then return end

    local hotEnts = {}

    for ent in pairs(aceEntities) do
        if ent.Heat then
            hotEnts[#hotEnts + 1] = ent
        end
    end

    return hotEnts
end

--- Returns a weighted average position of all heat sources in a contraption
---@return Vector
function CLASS:GetACEHeatPosition()
    local aceEntities = self.aceEntities

    if not aceEntities then return end

    local totalTemp = 0
    local totalPos = Vector(0, 0, 0)

    for ent in pairs(aceEntities) do
        if ent.Heat then
            local temp = ent.Heat
            totalTemp = totalTemp + temp
            totalPos = totalPos + ent:GetPos() * temp
        end
    end

    return totalPos / totalTemp
end
