ENT.Type            = "anim"
ENT.Base            = "ace_scalability"
ENT.PrintName       = "ACE Explosive Charge"
ENT.WireDebugName   = "ACE Explosive Charge"
ENT.Author          = "ACE Team"
-- Scalable charge is configured/spawned from the ACF menu, not the Q spawnmenu
-- (the fixed-size pre-built charges are the Q-menu ones).
ENT.Spawnable       = false
ENT.AdminSpawnable  = false

DEFINE_BASECLASS("ace_scalability")

ENT.IsMaster = true
