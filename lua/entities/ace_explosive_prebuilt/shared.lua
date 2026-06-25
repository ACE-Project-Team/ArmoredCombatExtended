ENT.Type            = "anim"
ENT.Base            = "base_wire_entity"
ENT.PrintName       = "ACE Prebuilt Explosive"
ENT.WireDebugName   = "ACE Explosive"
ENT.Author          = "ACE Team"
-- This is the shared base; the actual Q-menu entries are the thin variants
-- (ace_bomb_satchel / ace_bomb_aerial / ace_bomb_barrel) that inherit it.
ENT.Spawnable       = false
ENT.AdminSpawnable  = false

-- Defaults; variants override these.
ENT.ChargeName      = "Explosive"
ENT.ChargeModel     = "models/props_junk/propanecanister001a.mdl"
ENT.FillerFraction  = 0.65

DEFINE_BASECLASS("base_wire_entity")
