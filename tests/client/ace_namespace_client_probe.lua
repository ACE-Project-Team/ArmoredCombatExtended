-- Temporary client-side probe. Copy into lua/autorun/client for a manual live-client run.

local results = {
    boot = true,
    realm = "client",
    checks = {},
}
local runId = string.format("%d-%d", os.time(), math.random(1, 2147483647))
results.run_id = runId
local sourceManifestText = file.Read("ace_namespace_client_manifest.txt", "DATA") or ""
local surfaceManifestText = file.Read("ace_namespace_surface_manifest.json", "DATA") or ""
results.source_manifest_sha256 = sourceManifestText
results.source_manifest_bytes = #sourceManifestText
results.surface_manifest_bytes = #surfaceManifestText
local surfaceManifest = util.JSONToTable(surfaceManifestText) or {}
print("[ACE_NAMESPACE_CLIENT_PROBE] run_id=" .. runId)

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

local function finish()
    results.finished = true
    results.output_file = "ace_namespace_client_probe_" .. runId .. ".json"
    file.Write(results.output_file, util.TableToJSON(results, true))
end

local started = false
local function startChecks()
    if started then return end
    started = true
    timer.Simple(0.25, function()
    check("ACE table", istable(ACE), type(ACE))
    check("ACE has no compatibility metatable", not getmetatable(ACE), tostring(getmetatable(ACE)))

    local publicFunctionCount = 0
    for _, value in pairs(ACE or {}) do
        if isfunction(value) then publicFunctionCount = publicFunctionCount + 1 end
    end
    check("ACE client public function table is populated", publicFunctionCount > 100, tostring(publicFunctionCount))

    for _, name in ipairs({
        "CalcArmor", "GetMaterialData", "RenderLight", "RemoveBulletClient", "EmitSound",
    }) do
        checkFunction("ACE." .. name, ACE and ACE[name])
    end

    for _, name in ipairs(surfaceManifest.functions and surfaceManifest.functions.client or {}) do
        checkFunction("source ACE function " .. name, resolveFunction(ACE, name))
    end

    for _, spec in ipairs(surfaceManifest.hooks and surfaceManifest.hooks.client or {}) do
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

    local hookSpecs = {
        { event = "Think", names = { "ACE_VignetteFade", "ACE_Think_SpeedOfSound", "ACE_ManageBulletEffects" } },
        { event = "HUDPaint", names = { "ACE_VignetteDraw" } },
        { event = "PostDrawOpaqueRenderables", names = { "ACE_RenderDamage" } },
        { event = "InitPostEntity", names = { "ACE_RefreshScalables" } },
        { event = "NetworkEntityCreated", names = { "ACE_RefreshScalables_FullUpdate" } },
        { event = "SpawnMenuOpen", names = { "ACEPermissionsSpawnMenuOpen" }, prefixes = { "ACE.SpawnMenuOpen." } },
    }
    for _, spec in ipairs(hookSpecs) do
        local registered = hook.GetTable()[spec.event] or {}
        for _, name in ipairs(spec.names or {}) do
            check("registered ACE client hook " .. spec.event .. ":" .. name, isfunction(registered[name]))
        end
        for _, prefix in ipairs(spec.prefixes or {}) do
            local found = false
            for name, callback in pairs(registered) do
                if isstring(name) and string.StartWith(name, prefix) and isfunction(callback) then
                    found = true
                    break
                end
            end
            check("registered ACE client hook " .. spec.event .. ":" .. prefix .. "*", found)
        end
    end

    for _, className in ipairs({
        "acf_ammo", "acf_engine", "acf_gearbox", "acf_fueltank", "acf_gun", "acf_rack",
        "ace_ammo", "ace_engine", "ace_gearbox", "ace_fueltank", "ace_gun", "ace_rack",
        "ace_crewseat_driver", "ace_searchradar", "ace_missile",
    }) do
        local stored = scripted_ents.GetStored(className)
        check("client scripted entity " .. className, istable(stored) and istable(stored.t))
    end

    for _, name in ipairs({
        "ace_enable_lighting", "ace_sens_irons", "ace_sens_scopes", "ace_tinnitus",
        "ace_sound_volume", "ace_mobility_rope_links", "ace_tool_category",
    }) do
        check("client ACE convar " .. name, GetConVar(name) ~= nil)
    end

    local toolWeapon = weapons.GetStored("gmod_tool")
    for _, name in ipairs({ "acemenu", "acearmorprop", "acechaircam", "acecopy", "acesound" }) do
        local registered = toolWeapon and toolWeapon.Tool and toolWeapon.Tool[name]
        check("client ACE tool " .. name, istable(registered))
        check("client ACE tool " .. name .. " has interaction callback",
            istable(registered) and (isfunction(registered.LeftClick) or isfunction(registered.RightClick) or isfunction(registered.Reload)))
        check("client ACE tool " .. name .. " has panel builder",
            istable(registered) and isfunction(registered.BuildCPanel))
    end

    for _, name in ipairs({
        "ace_ap_impact", "ace_ap_penetration", "ace_ap_ricochet", "ace_bulleteffect",
        "ace_cookoff_puff", "ace_heat_explosion", "ace_missilelaunch", "ace_muzzleflash",
        "ace_racklaunch", "ace_radar_noise", "ace_scaled_detonation", "ace_scaled_explosion",
        "ace_smoke",
    }) do
        local effectCreate = effects and effects.Create
        local definition = isfunction(effectCreate) and effectCreate(name) or nil
        check("client ACE effect " .. name, definition ~= nil)
        check("client ACE effect " .. name .. " has lifecycle", istable(definition)
            and isfunction(definition.Init) and isfunction(definition.Render))
    end

    check("client ACE missile menu configuration is callable",
        ACE and isfunction(ACE.Missiles_CreateMenuConfiguration))

    finish()
    end)
end

hook.Add("InitPostEntity", "ACE_NamespaceClientProbe", startChecks)
timer.Simple(10, startChecks)

timer.Simple(90, function()
    if not results.finished then finish() end
end)
