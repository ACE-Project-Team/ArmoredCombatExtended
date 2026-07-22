
ACE.Missile.RadarBehaviour = ACE.Missile.RadarBehaviour or {}
ACE.Missile.DefaultRadarSound = ACE.Missile.DefaultRadarSound or "buttons/button16.wav"

ACE.Missile.RadarBehaviour["DIR-AM"] =
{
	GetDetectedEnts = function(self)
		return ACE_Missile_GetMissilesInCone(self, self:GetForward(), self.ConeDegs)
	end
}


ACE.Missile.RadarBehaviour["OMNI-AM"] =
{
	GetDetectedEnts = function(self)
		return ACE_Missile_GetMissilesInSphere(self, self.Range)
	end
}
