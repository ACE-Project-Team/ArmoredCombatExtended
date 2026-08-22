-- Temporary server-side probe. It is copied into the dedicated server only for a validation run.

local results = {
    boot = true,
    realm = "server",
    checks = {},
    spawned = {},
}
local runId = string.format("%d-%d", os.time(), math.random(1, 2147483647))
results.run_id = runId
results.source_manifest_sha256 = file.Read("ace_namespace_runtime_probe_manifest.txt", "DATA") or ""
local surfaceManifest = util.JSONToTable(file.Read("ace_namespace_surface_manifest.json", "DATA") or "") or {}
local integrationManifest = util.JSONToTable(file.Read("ace_namespace_integration_manifest.json", "DATA") or "") or {}
print("[ACE_NAMESPACE_RUNTIME_PROBE] run_id=" .. runId)

local bulletEvents = {
    creation = 0,
    removed = 0,
    penetrated = 0,
    ricochet = 0,
    hit = 0,
}

local probeGun
local probeEntities = {}
local duplicatedEntities = {}
local entityMeta
local originalCPPISetOwner
local originalUniqueID
local cleanedUp = false
local cleanup

local function getHookBullet(first, second)
    if istable(first) then return first end
    if istable(second) then return second end
    if isnumber(first) and istable(ACE.Bullet[first]) then return ACE.Bullet[first] end
    if isnumber(second) and istable(ACE.Bullet[second]) then return ACE.Bullet[second] end
end

local function isProbeBullet(first, second)
    local bullet = getHookBullet(first, second)
    return bullet and bullet.Gun == probeGun
end

hook.Add("ACEOnBulletCreation", "ACE_NamespaceRuntimeProbe_BulletCreation", function(first, second)
    if isProbeBullet(first, second) then bulletEvents.creation = bulletEvents.creation + 1 end
end)
hook.Add("ACEOnBulletRemoved", "ACE_NamespaceRuntimeProbe_BulletRemoved", function(first, second)
    if isProbeBullet(first, second) then bulletEvents.removed = bulletEvents.removed + 1 end
end)
hook.Add("ACEOnBulletPenetrated", "ACE_NamespaceRuntimeProbe_BulletPenetrated", function(first, second)
    if isProbeBullet(first, second) then bulletEvents.penetrated = bulletEvents.penetrated + 1 end
end)
hook.Add("ACEOnBulletRicochet", "ACE_NamespaceRuntimeProbe_BulletRicochet", function(first, second)
    if isProbeBullet(first, second) then bulletEvents.ricochet = bulletEvents.ricochet + 1 end
end)
hook.Add("ACEOnBulletHit", "ACE_NamespaceRuntimeProbe_BulletHit", function(first, second)
    if isProbeBullet(first, second) then bulletEvents.hit = bulletEvents.hit + 1 end
end)

local function check(name, condition, detail)
    results.checks[#results.checks + 1] = {
        name = name,
        ok = condition == true,
        detail = detail,
    }
end

local function checkFunction(name, value)
    check(name, isfunction(value), type(value))
end

local function resolveFunction(root, dottedName)
    local value = root
    dottedName = string.gsub(dottedName, "^ACE%.", "")
    for part in string.gmatch(dottedName, "[^%.]+") do
        if not istable(value) then return nil end
        value = value[part]
    end
    return value
end

cleanup = function()
    if cleanedUp then return end
    cleanedUp = true
    timer.Remove("ACE_NamespaceRuntimeProbeTimeout")
    for index, bullet in pairs(ACE.Bullet or {}) do
        if isProbeBullet(bullet) then pcall(ACE.RemoveBullet, index) end
    end
    hook.Remove("ACEOnBulletCreation", "ACE_NamespaceRuntimeProbe_BulletCreation")
    hook.Remove("ACEOnBulletRemoved", "ACE_NamespaceRuntimeProbe_BulletRemoved")
    hook.Remove("ACEOnBulletPenetrated", "ACE_NamespaceRuntimeProbe_BulletPenetrated")
    hook.Remove("ACEOnBulletRicochet", "ACE_NamespaceRuntimeProbe_BulletRicochet")
    hook.Remove("ACEOnBulletHit", "ACE_NamespaceRuntimeProbe_BulletHit")
    hook.Remove("InitPostEntity", "ACE_NamespaceRuntimeProbe")
    hook.Remove("GLuaTest_Finished", "ACE_NamespaceRuntimeProbe")
    for _, ent in ipairs(probeEntities) do
        if IsValid(ent) then ent:Remove() end
    end
    for _, ent in ipairs(duplicatedEntities) do
        if IsValid(ent) then ent:Remove() end
    end
    if entityMeta then
        entityMeta.CPPISetOwner = originalCPPISetOwner
        entityMeta.UniqueID = originalUniqueID
    end
end

local function writeResults(gluatest)
    if results.finished then return end
    results.gluatest = gluatest
    results.bullet_events = bulletEvents
    results.finished = true
    cleanup()
    results.output_file = "ace_namespace_runtime_probe_" .. runId .. ".json"
    file.Write(results.output_file, util.TableToJSON(results, true))
end

hook.Add("InitPostEntity", "ACE_NamespaceRuntimeProbe", function()
    timer.Simple(0.25, function()
    check("ACE table", istable(ACE), type(ACE))
    check("ACE has no compatibility metatable", not getmetatable(ACE), tostring(getmetatable(ACE)))

    for _, name in ipairs({
        "CalcArmor", "CheckLegal", "GetMaterialData", "GetWeaponUser",
        "MarkArmorDirty", "NotifyPointsInvalidated", "EnsurePointsState",
        "Missile_BulletLaunch", "Missile_ExpandBulletData", "AcquireBullet",
        "RegisterBullet", "BulletClient",
    }) do
        checkFunction("ACE." .. name, ACE and ACE[name])
    end

    for _, name in ipairs(surfaceManifest.functions and surfaceManifest.functions.server or {}) do
        checkFunction("source ACE function " .. name, resolveFunction(ACE, name))
    end

    for _, spec in ipairs(surfaceManifest.hooks and surfaceManifest.hooks.server or {}) do
        local registered = hook.GetTable()[spec.event] or {}
        local found = false
        if string.sub(spec.identifier, -1) == "." then
            for identifier, callback in pairs(registered) do
                if isstring(identifier) and string.StartWith(identifier, spec.identifier) and isfunction(callback) then
                    found = true
                    break
                end
            end
        else
            found = isfunction(registered[spec.identifier])
        end
        check("source registered hook " .. spec.event .. ":" .. spec.identifier, found)
    end

    local publicFunctionCount = 0
    for _, value in pairs(ACE or {}) do
        if isfunction(value) then publicFunctionCount = publicFunctionCount + 1 end
    end
    check("ACE public function table is populated", publicFunctionCount > 100, tostring(publicFunctionCount))

    for _, event in ipairs({
        "ACE_BulletDamage", "ACE_PlayerChangedZone", "ACE_ProtectionModeChanged",
        "AdvDupe_FinishPasting", "CleanUpMap", "EntityRemoved", "InitPostEntity", "Initialize",
        "OnEntityCreated", "PhysgunPickup", "PlayerAuthed", "PlayerDisconnected", "PlayerEnteredVehicle",
        "PlayerFrozeObject", "PlayerInitialSpawn", "PlayerNoClip", "PlayerSpawnedSENT",
        "PlayerSpawnedSWEP", "PlayerSpawnedVehicle", "PlayerUnfrozeObject", "Primitive_PostRebuildPhysics",
        "Primitive_PreRebuildPhysics", "ProperClippingClipAdded", "ProperClippingPhysicsClipped",
        "ProperClippingPhysicsReset", "Think", "Tick", "cfw.contraption.created",
        "cfw.contraption.entityAdded", "cfw.contraption.entityRemoved", "cfw.contraption.merged",
        "cfw.contraption.removed", "cfw.contraption.split", "cfw.family.added", "cfw.family.created",
        "cfw.family.subbed",
    }) do
        local registered = hook.GetTable()[event]
        check("registered hook " .. event, istable(registered) and next(registered) ~= nil)
    end

    for _, className in ipairs({
        "acf_ammo", "acf_engine", "acf_gearbox", "acf_fueltank", "acf_gun",
        "acf_rack", "ace_ammo", "ace_engine", "ace_gearbox", "ace_fueltank", "ace_gun",
        "ace_rack", "ace_crewseat_driver", "ace_searchradar", "ace_missile",
    }) do
        local stored = scripted_ents.GetStored(className)
        check("scripted entity " .. className, istable(stored) and istable(stored.t))
    end

    for _, name in ipairs({
        "sbox_max_ace_gun", "sbox_max_ace_ammo", "sbox_max_ace_rack", "sbox_max_ace_crewseat",
        "sbox_max_ace_explosive", "ace_mines_max", "ace_legality_enginesrequirefuel",
        "ace_legalcheck", "ace_enable_dp", "ace_gunfire", "ace_spalling",
    }) do
        check("server ACE convar " .. name, GetConVar(name) ~= nil)
    end

    check("Starfall ACE library registered", istable(SF) and istable(SF.Libraries) and SF.Libraries.acf == true)
    check("ACE integration manifest loaded", integrationManifest.schema == 1 and istable(integrationManifest.e2) and istable(integrationManifest.starfall))
    for _, name in ipairs(integrationManifest.e2 and integrationManifest.e2.names or {}) do
        check("E2 ACE function " .. name .. " registered", istable(wire_expression2_funclist) and wire_expression2_funclist[name] == true)
    end

    local owner = ents.Create("prop_physics")
    local ownerOk = IsValid(owner)
    if ownerOk then
        probeEntities[#probeEntities + 1] = owner
        entityMeta = FindMetaTable("Entity")
        -- Headless-only compatibility shims: the dedicated server has no player/CPPI addon.
        if entityMeta then
            originalCPPISetOwner = entityMeta.CPPISetOwner
            originalUniqueID = entityMeta.UniqueID
        end
        if entityMeta and not originalCPPISetOwner then
            entityMeta.CPPISetOwner = function(self, ownerEnt) self._TestCPPIOwner = ownerEnt end
        end
        if entityMeta and not originalUniqueID then
            entityMeta.UniqueID = function(self) return "ACE_HEADLESS_" .. self:EntIndex() end
        end
        owner:SetModel("models/props_c17/oildrum001.mdl")
        owner:SetPos(Vector(0, 0, 64))
        owner:Spawn()
        owner.CheckLimit = function() return true end
        owner.AddCount = function() end
        owner.AddCleanup = function() end
    end
    check("spawn tank owner prop", ownerOk)

    local rackId = ACE.Weapons and ACE.Weapons.Racks and (ACE.Weapons.Racks["1xRK"] and "1xRK" or next(ACE.Weapons.Racks))
    local factorySpecs = {
        { class = "acf_engine", factory = ACE.MakeEngine, args = { "3.2-B4" } },
        { class = "acf_gearbox", factory = ACE.MakeGearbox, args = { "1Gear-T-S", 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.5 } },
        { class = "acf_fueltank", factory = ACE.MakeFuelTank, args = { "Tank_4x4x2", "Tank_4x4x2", "Petrol", "Box" } },
        { class = "acf_gun", factory = ACE.MakeGun, args = { "100mmC" } },
        -- The crate model ID is not the round definition. Supply the same gun,
        -- round, propellant, and projectile fields that a real ammo spawn sends.
        { class = "acf_ammo", factory = ACE.MakeAmmo, args = { "Shell100mm", "100mmC", "AP", 10, 15 } },
        { class = "acf_rack", factory = ACE.MakeRack, args = { rackId } },
    }
    local tankParts = {}
    local tankPartsByClass = {}
    for index, spec in ipairs(factorySpecs) do
        local called, ent = pcall(spec.factory, owner, Vector(index * 64, 0, 64), Angle(0, 0, 0), unpack(spec.args))
        local ok = called and IsValid(ent)
        results.spawned[#results.spawned + 1] = { class = spec.class, ok = ok, id = spec.args[1], detail = tostring(ent) }
        check("spawn " .. spec.class .. " through factory", ok, tostring(ent))
        if ok then
            tankParts[#tankParts + 1] = ent
            probeEntities[#probeEntities + 1] = ent
            tankPartsByClass[spec.class] = ent
            local activated, activationError = pcall(ent.Activate, ent)
            check("activate " .. spec.class, activated, tostring(activationError))
        end
    end
    check("spawn representative tank assembly", #tankParts == #factorySpecs)
    local stateParity = true
    for _, ent in ipairs(tankParts) do
        local state = ACE.GetEntityState(ent)
        stateParity = stateParity and state == ent.ACE and ent.ACF == ent.ACE
    end
    check("tank entities use canonical ACE state", stateParity)

    local gun = tankPartsByClass.acf_gun
    probeGun = gun
    local ammo = tankPartsByClass.acf_ammo
    local gunnerCalled, gunner = pcall(ACE.MakeCrewseatGunner, owner, Vector(256, 64, 64), Angle(0, 0, 0), "Crewseat_Gunner", "Sitting")
    if IsValid(gunner) then probeEntities[#probeEntities + 1] = gunner end
    check("spawn gunner seat for fire test", gunnerCalled and IsValid(gunner), tostring(gunner))
    local gunnerLinkCalled, gunnerLinkResult, gunnerLinkError = false, false, "missing gun or gunner"
    if IsValid(gun) and IsValid(gunner) then
        gunnerLinkCalled, gunnerLinkResult, gunnerLinkError = pcall(gun.Link, gun, gunner)
    end
    check("link spawned gunner to gun", gunnerLinkCalled and gunnerLinkResult == true, tostring(gunnerLinkError or gunnerLinkResult))
    local linkCalled, linkResult, linkError = false, false, "missing gun or ammo"
    if IsValid(gun) and IsValid(ammo) then
        linkCalled, linkResult, linkError = pcall(gun.Link, gun, ammo)
    end
    check("link spawned gun to ammo", linkCalled and linkResult == true, tostring(linkError or linkResult))
    if linkCalled and linkResult == true then
        check("linked ammo is loadable", ammo.Ammo > 0 and ammo.Load == true and ammo.Legal == true,
            string.format("ammo=%s capacity=%s load=%s legal=%s", tostring(ammo.Ammo), tostring(ammo.Capacity), tostring(ammo.Load), tostring(ammo.Legal)))
        check("gun retained ammo link", #gun.AmmoLink == 1, tostring(#gun.AmmoLink))
        local loadCalled, loadResult = pcall(gun.LoadAmmo, gun, false, true)
        check("load linked ammo into gun", loadCalled and loadResult == true, tostring(loadResult))
        results.fire_state = {
            ammo = ammo.Ammo,
            capacity = ammo.Capacity,
            load = ammo.Load,
            legal = ammo.Legal,
            gun_bullet_type = gun.BulletData and gun.BulletData.Type,
            gun_ready = gun.Ready,
            gun_legal = gun.Legal,
            ammo_links = #gun.AmmoLink,
        }
        local fireCalled, fireError = pcall(gun.FireShell, gun)
        check("fire linked gun shell", fireCalled, tostring(fireError))
        check("bullet creation hook fired once", bulletEvents.creation == 1, tostring(bulletEvents.creation))
    end
    results.bullet_events = bulletEvents

    local dupeCalled, dupeError = pcall(function()
        check("duplicator CopyEnts API", isfunction(duplicator and duplicator.CopyEnts))
        check("duplicator Paste API", isfunction(duplicator and duplicator.Paste))
        if not isfunction(duplicator and duplicator.CopyEnts) or not isfunction(duplicator and duplicator.Paste) then return end

        local copied = duplicator.CopyEnts({ gun, ammo })
        check("copy ACE gun and ammo for dupe", istable(copied) and istable(copied.Entities) and table.Count(copied.Entities) >= 2,
            tostring(copied and copied.Entities and table.Count(copied.Entities)))
        if not istable(copied) or not istable(copied.Entities) then return end

        -- Wire's installed duplicator wrapper emits AdvDupe_FinishPasting with this
        -- owner. ACE's scalability adapter reads the player option through GetInfo;
        -- provide the server-only equivalent on the existing headless owner shim.
        owner.GetInfo = function() return "0" end
		local pasted = duplicator.Paste(owner, copied.Entities, copied.Constraints or {})
        local pastedCount = 0
        for _, ent in pairs(pasted or {}) do
            if IsValid(ent) then
                pastedCount = pastedCount + 1
                duplicatedEntities[#duplicatedEntities + 1] = ent
            end
        end
        check("paste ACE gun and ammo", pastedCount >= 2, tostring(pastedCount))

        local pastedGun
        local pastedAmmo
        for _, ent in pairs(pasted or {}) do
            if IsValid(ent) and ent:GetClass() == "acf_gun" then pastedGun = ent end
            if IsValid(ent) and ent:GetClass() == "acf_ammo" then pastedAmmo = ent end
        end
        check("pasted ACE gun is present", IsValid(pastedGun))
        check("pasted ACE ammo is present", IsValid(pastedAmmo))
        if IsValid(pastedGun) and IsValid(pastedAmmo) then
            check("pasted gun uses canonical ACE state", ACE.GetEntityState(pastedGun) == pastedGun.ACE and pastedGun.ACF == pastedGun.ACE)
            check("pasted ammo uses canonical ACE state", ACE.GetEntityState(pastedAmmo) == pastedAmmo.ACE and pastedAmmo.ACF == pastedAmmo.ACE)
            check("pasted gun retains ammo link", pastedGun.AmmoLink and #pastedGun.AmmoLink >= 1,
                tostring(pastedGun.AmmoLink and #pastedGun.AmmoLink))
        end
    end)
    check("exercise real duplicator round-trip", dupeCalled, tostring(dupeError))

    local assemblyOk, assemblyError = pcall(function()
        local contraption = CFW.createContraption()
        contraption:Add(owner)
        for _, ent in ipairs(tankParts) do contraption:Add(ent) end
        check("create CFW tank contraption", CFW.Contraptions[contraption] == true)
        check("CFW tank contraption contains all parts", contraption.count == #tankParts + 1, tostring(contraption.count))
        for _, ent in ipairs(tankParts) do CFW.connect(owner, ent) end
        check("tank owner has CFW contraption", owner:CFW_GetContraption() == contraption)
        for _, ent in ipairs(tankParts) do
            check("tank part linked to CFW contraption", ent:CFW_GetContraption() == contraption)
        end
        for _, ent in ipairs(tankParts) do CFW.disconnect(owner, ent:EntIndex()) end
        check("disconnect CFW tank links", contraption._removed == true and CFW.Contraptions[contraption] == nil)
        if not contraption._removed then contraption:Defuse() end
        check("defuse CFW tank contraption", contraption._removed == true and CFW.Contraptions[contraption] == nil)
    end)
    check("exercise CFW tank lifecycle", assemblyOk, tostring(assemblyError))
    end)
end)

hook.Add("GLuaTest_Finished", "ACE_NamespaceRuntimeProbe", function(testGroups, testResults)
    local failures = 0
    for _, result in pairs(testResults or {}) do
        if result.success == false then failures = failures + 1 end
    end
    timer.Simple(1, function()
        writeResults({ groups = #testGroups, failures = failures })
    end)
end)

timer.Create("ACE_NamespaceRuntimeProbeTimeout", 120, 1, function()
    if not results.finished then
        writeResults({ error = "GLuaTest_Finished was not observed before timeout" })
    end
end)
