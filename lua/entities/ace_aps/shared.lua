ENT.Type = "anim"
ENT.Base = "base_wire_entity"
ENT.PrintName = "ACE APS Base"
ENT.WireDebugName = "ACE APS"
ENT.IsAPS = true
ENT.Author = "ACE Project Team"
ENT.Category = "ACE - Entities"
ENT.Spawnable = false
ENT.AdminSpawnable = false

ACE = ACE or {}
ACE.APSPresets = ACE.APSPresets or {
	Static = {
		Charges = 1,
		KillRange = 3,
		ReloadTime = 5,
		RadarSize = "1",
		YawCoverage = 90,
		PitchCoverage = 45,
	},
	Zaslin = {
		Charges = 1,
		KillRange = 3,
		ReloadTime = 15,
		RadarSize = "1",
		YawCoverage = 90,
		PitchCoverage = 45,
	},
}
