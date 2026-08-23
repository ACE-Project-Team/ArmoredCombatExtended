AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_explosive_prebuilt")

duplicator.RegisterEntityClass("ace_bomb_aerial", function(ply, Pos, Ang)
	return ACE.MakePrebuiltExplosive(ply, "ace_bomb_aerial", Pos, Ang)
end, "Pos", "Angle")
