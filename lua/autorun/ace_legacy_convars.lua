-- Keep renamed ACE settings alive while the canonical names move to ace_*.
-- This bridge only concerns convars; ACE functions remain genuinely migrated.

local serverConVars = {
    { "acf_ballistics_debug", "ace_ballistics_debug", "0" },
    { "acf_explosion_debug", "ace_explosion_debug", "0" },
    { "acf_debug_crewseat_models", "ace_debug_crewseat_models", "0" },
    { "sbox_max_acf_gun", "sbox_max_ace_gun", "32" },
    { "sbox_max_acf_rapidgun", "sbox_max_ace_rapidgun", "6" },
    { "sbox_max_acf_largegun", "sbox_max_ace_largegun", "4" },
    { "sbox_max_acf_smokelauncher", "sbox_max_ace_smokelauncher", "40" },
    { "sbox_max_acf_ammo", "sbox_max_ace_ammo", "100" },
    { "sbox_max_acf_misc", "sbox_max_ace_misc", "100" },
    { "sbox_max_acf_rack", "sbox_max_ace_rack", "24" },
    { "sbox_max_acf_explosive", "sbox_max_ace_explosive", "20" },
    { "sbox_max_acf_gforce_meter", "sbox_max_ace_gforce_meter", "10" },
    { "sbox_max_acf_missileradar", "sbox_max_ace_missileradar", "6" },
    { "sbox_max_acf_vheat_source", "sbox_max_ace_vheat_source", "3" },
    { "sbox_max_acf_wind_sensor", "sbox_max_ace_wind_sensor", "10" },
    { "acf_mines_max", "ace_mines_max", "50" },
    { "acf_meshvalue", "ace_meshvalue", "1" },
    { "acf_legality_enginesrequirefuel", "ace_legality_enginesrequirefuel", "1" },
    { "acf_legality_largeenginesneeddriver", "ace_legality_largeenginesneeddriver", "1" },
    { "acf_legality_largeenginethreshold", "ace_legality_largeenginethreshold", "100" },
    { "acf_legality_largegunsneedgunner", "ace_legality_largegunsneedgunner", "1" },
    { "acf_legality_largegunthreshold", "ace_legality_largegunthreshold", "40" },
    { "acf_legalcheck", "ace_legalcheck", "1" },
    { "acf_legal_ignore_model", "ace_legal_ignore_model", "0" },
    { "acf_legal_ignore_solid", "ace_legal_ignore_solid", "0" },
    { "acf_legal_ignore_mass", "ace_legal_ignore_mass", "0" },
    { "acf_legal_ignore_material", "ace_legal_ignore_material", "0" },
    { "acf_legal_ignore_inertia", "ace_legal_ignore_inertia", "0" },
    { "acf_legal_ignore_makesphere", "ace_legal_ignore_makesphere", "0" },
    { "acf_legal_ignore_visclip", "ace_legal_ignore_visclip", "0" },
    { "acf_legal_ignore_parent", "ace_legal_ignore_parent", "0" },
    { "acf_enable_dp", "ace_enable_dp", "0" },
    { "acf_kepush", "ace_kepush", "1" },
    { "acf_hepush", "ace_hepush", "1" },
    { "acf_recoilpush", "ace_recoilpush", "1" },
    { "acf_healthmod", "ace_healthmod", "1" },
    { "acf_armormod", "ace_armormod", "1" },
    { "acf_ammomod", "ace_ammomod", "1" },
    { "acf_gunfire", "ace_gunfire", "1" },
    { "acf_debris_lifetime", "ace_debris_lifetime", "30" },
    { "acf_debris_children", "ace_debris_children", "1" },
    { "acf_spalling", "ace_spalling", "1" },
    { "acf_spalling_multipler", "ace_spalling_multiplier", "1" },
    { "acf_explosions_scaled_he_max", "ace_explosions_scaled_he_max", "100" },
    { "acf_explosions_scaled_ents_max", "ace_explosions_scaled_ents_max", "5" },
    { "acf_wind", "ace_wind", "600" },
    { "acf_legacyrecoil", "ace_legacyrecoil", "0" }
}

local clientConVars = {
    { "acf_enable_lighting", "ace_enable_lighting", "1", true, false },
    { "acf_sens_irons", "ace_sens_irons", "0.5", true, false },
    { "acf_sens_scopes", "ace_sens_scopes", "0.2", true, false },
    { "acf_tinnitus", "ace_tinnitus", "1", true, false },
    { "acf_sound_volume", "ace_sound_volume", "100", true, false },
    { "ACF_MobilityRopeLinks", "ace_mobility_rope_links", "1", true, false },
    { "ACF_GunInfoWhileSeated", "ace_gun_info_while_seated", "0", true, false },
    { "ACF_AmmoInfoWhileSeated", "ace_ammo_info_while_seated", "0", true, false },
    { "ACF_EngineInfoWhileSeated", "ace_engine_info_while_seated", "0", true, false },
    { "ACF_FuelInfoWhileSeated", "ace_fuel_info_while_seated", "0", true, false },
    { "ACF_GearboxInfoWhileSeated", "ace_gearbox_info_while_seated", "0", true, false },
    { "ACF_ToolInfoWhileSeated", "ace_tool_info_while_seated", "0", true, false },
    { "acf_tool_category", "ace_tool_category", "0", true, false },
    { "acf_survey_message", "ace_survey_message", "1", true, false },
    { "acf_effect_debug", "ace_effect_debug", "0", true, false },
    { "acfarmorprop_area", "acearmorprop_area", "0", false, true },
    { "acfarmorprop_ductility", "acearmorprop_ductility", "0", false, true },
    { "acfarmorprop_material", "acearmorprop_material", "0", false, true },
    { "acfarmorprop_thickness", "acearmorprop_thickness", "0", false, true }
}

local function bridgeConVar(legacyName, currentName, default, archive, userData)
    local legacy = GetConVar(legacyName)
    if not legacy then
        if CLIENT then
            legacy = CreateClientConVar(legacyName, default, archive, userData)
        else
            legacy = CreateConVar(legacyName, default, archive == false and 0 or FCVAR_ARCHIVE)
        end
    end

    local current = GetConVar(currentName)
    if not current then return end

    local callbackId = "ACE_LegacyCVar_" .. currentName
    local syncing = false
    local currentWasConfigured = false

    local function setValue(convar, value)
        syncing = true
        convar:SetString(value)
        syncing = false
    end

    cvars.RemoveChangeCallback(legacyName, callbackId .. "_Legacy")
    cvars.RemoveChangeCallback(currentName, callbackId .. "_Current")

    cvars.AddChangeCallback(legacyName, function(_, _, value)
        if syncing or currentWasConfigured then return end
        setValue(current, value)
    end, callbackId .. "_Legacy")

    cvars.AddChangeCallback(currentName, function(_, _, value)
        if syncing then return end
        currentWasConfigured = true
        setValue(legacy, value)
    end, callbackId .. "_Current")

    if current:GetString() == default and legacy:GetString() ~= default then
        setValue(current, legacy:GetString())
    else
        setValue(legacy, current:GetString())
    end
end

local function bridgeList(list)
    for _, data in ipairs(list) do
        bridgeConVar(data[1], data[2], data[3], data[4], data[5])
    end
end

if SERVER then bridgeList(serverConVars) end
if CLIENT then bridgeList(clientConVars) end

hook.Add("InitPostEntity", "ACE_LegacyConVars", function()
    if SERVER then bridgeList(serverConVars) end
    if CLIENT then bridgeList(clientConVars) end
end)
