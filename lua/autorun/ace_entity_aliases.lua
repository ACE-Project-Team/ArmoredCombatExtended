-- Register ACE-named entity classes without breaking legacy dupes or external addons.
-- The implementation remains shared with the legacy class until its family is fully migrated.
AddCSLuaFile()

ACE = ACE or {}
ACE.EntityAliases = ACE.EntityAliases or {
    ace_ammo = "acf_ammo",
    ace_engine = "acf_engine",
    ace_explosive = "acf_explosive",
    ace_fakecrate2 = "acf_fakecrate2",
    ace_fueltank = "acf_fueltank",
    ace_gearbox = "acf_gearbox",
    ace_gun = "acf_gun",
    ace_missile_to_rack = "acf_missile_to_rack",
    ace_missileradar = "acf_missileradar",
    ace_opticalcomputer = "acf_opticalcomputer",
    ace_rack = "acf_rack",
}

local function registerAlias(alias, legacy)
    if not scripted_ents or not scripted_ents.GetStored or not scripted_ents.Register then return end
    if scripted_ents.GetStored(alias) then return end

    local stored = scripted_ents.GetStored(legacy)
    if not istable(stored) or not istable(stored.t) then return end

    local definition = table.Copy(stored.t)
    definition.Base = legacy
    definition.ClassName = alias
    scripted_ents.Register(definition, alias)
end

local function registerAllAliases()
    for alias, legacy in pairs(ACE.EntityAliases) do
        registerAlias(alias, legacy)
    end
end

registerAllAliases()
if timer and timer.Simple then
    timer.Simple(0, registerAllAliases)
end
hook.Add("Initialize", "ACE_RegisterEntityAliases", registerAllAliases)
hook.Add("InitPostEntity", "ACE_RegisterEntityAliases", registerAllAliases)
