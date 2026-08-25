if not SERVER then return end

if not ACE or not ACE.Scheduler then include("ace/server/sv_ace_scheduler.lua") end
include("ace/server/sv_ace_wind_sensor_scheduler.lua")
include("ace/server/sv_ace_scalability_scheduler.lua")
include("ace/server/sv_ace_vheat_source_scheduler.lua")
include("ace/server/sv_ace_gforce_meter_scheduler.lua")
include("ace/server/sv_ace_debris_scheduler.lua")
include("ace/server/sv_ace_gun_autosound_scheduler.lua")
include("ace/server/sv_ace_ammo_cookoff_scheduler.lua")
include("ace/server/sv_ace_damage_effect_scheduler.lua")
include("ace/server/sv_ace_flare_scheduler.lua")
include("ace/server/sv_ace_sonar_scheduler.lua")

local enabled = not GetConVar or not GetConVar("ace_scheduler_enabled") or GetConVar("ace_scheduler_enabled"):GetBool()
if enabled then ACE.Scheduler.Enable() end
