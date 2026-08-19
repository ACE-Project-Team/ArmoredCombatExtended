net.Receive("ACE_SettingsSync", function(_, ply)
    if not ply:IsSuperAdmin() then return end

    local setting = net.ReadString()

    -- Sync all settings to a client requesting them
    -- This is kinda hardcoded, maybe at some point there can be a list of settings to sync?
    if setting == "_request" then
        local settings = util.TableToJSON({
            -- General
            ace_hepush = GetConVar("ace_hepush"):GetFloat(),
            ace_kepush = GetConVar("ace_kepush"):GetFloat(),
            ace_recoilpush = GetConVar("ace_recoilpush"):GetFloat(),
            ace_gunfire = GetConVar("ace_gunfire"):GetFloat(),
            ace_legacyrecoil = GetConVar("ace_legacyrecoil"):GetFloat(),
            ace_wind = GetConVar("ace_wind"):GetFloat(),

            -- Damage Scaling
            ace_healthmod = GetConVar("ace_healthmod"):GetFloat(),
            ace_armormod = GetConVar("ace_armormod"):GetFloat(),
            ace_ammomod = GetConVar("ace_ammomod"):GetFloat(),

            -- Debris & Spalling
            ace_debris_lifetime = GetConVar("ace_debris_lifetime"):GetFloat(),
            ace_debris_children = GetConVar("ace_debris_children"):GetFloat(),
            ace_spalling = GetConVar("ace_spalling"):GetFloat(),
            ace_spalling_multiplier = GetConVar("ace_spalling_multiplier"):GetFloat(),

            -- Cooking Off / Scaled Explosions
            ace_explosions_scaled_he_max = GetConVar("ace_explosions_scaled_he_max"):GetFloat(),
            ace_explosions_scaled_ents_max = GetConVar("ace_explosions_scaled_ents_max"):GetFloat(),

            -- Vehicle Legality
            ace_legalcheck = GetConVar("ace_legalcheck"):GetFloat(),
            ace_legality_enginesrequirefuel = GetConVar("ace_legality_enginesrequirefuel"):GetFloat(),
            ace_legality_largeenginesneeddriver = GetConVar("ace_legality_largeenginesneeddriver"):GetFloat(),
            ace_legality_largeenginethreshold = GetConVar("ace_legality_largeenginethreshold"):GetFloat(),
            ace_legality_largegunsneedgunner = GetConVar("ace_legality_largegunsneedgunner"):GetFloat(),
            ace_legality_largegunthreshold = GetConVar("ace_legality_largegunthreshold"):GetFloat(),
            ace_legal_ignore_model = GetConVar("ace_legal_ignore_model"):GetFloat(),
            ace_legal_ignore_solid = GetConVar("ace_legal_ignore_solid"):GetFloat(),
            ace_legal_ignore_mass = GetConVar("ace_legal_ignore_mass"):GetFloat(),
            ace_legal_ignore_material = GetConVar("ace_legal_ignore_material"):GetFloat(),
            ace_legal_ignore_inertia = GetConVar("ace_legal_ignore_inertia"):GetFloat(),
            ace_legal_ignore_makesphere = GetConVar("ace_legal_ignore_makesphere"):GetFloat(),
            ace_legal_ignore_visclip = GetConVar("ace_legal_ignore_visclip"):GetFloat(),
            ace_legal_ignore_parent = GetConVar("ace_legal_ignore_parent"):GetFloat(),

            -- Prop Protection
            ace_enable_dp = GetConVar("ace_enable_dp"):GetFloat(),
            ace_restrictinfo = GetConVar("ace_restrictinfo"):GetFloat(),
        })

        settings = util.Compress(settings)

        net.Start("ACE_SettingsSync")
        net.WriteUInt(#settings, 16)
        net.WriteData(settings, #settings)
        net.Send(ply)

        return
    else
        local value = math.Round(net.ReadFloat(), 2)

        ACE_ChatMessageGlobal("[ACE] " .. setting .. " changed to " .. value)
        RunConsoleCommand(setting, value)
    end
end)
