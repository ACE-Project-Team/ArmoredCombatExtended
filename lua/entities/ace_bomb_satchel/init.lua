AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_explosive_prebuilt")

-- The Make/SpawnFunction/logic all live on the base. Looked up lazily so the
-- base entity having loaded after this one doesn't matter.
duplicator.RegisterEntityClass("ace_bomb_satchel", function(ply, Pos, Ang)
	return ACE_MakePrebuiltExplosive(ply, "ace_bomb_satchel", Pos, Ang)
end, "Pos", "Angle")
