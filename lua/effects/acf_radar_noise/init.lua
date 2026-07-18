--[[---------------------------------------------------------
Initializes the effect. The data is a table of data
which was passed from the server.
-----------------------------------------------------------]]
function EFFECT:Init( data )

	local Radar    = data:GetEntity()
	if IsValid(Radar) then
		local Sound        = Radar:GetNWString( "Sound", "" )
		local SoundPitch   = Radar:GetNWInt( "SoundPitch", 100 )

		if not ACE.IsValidSound( Sound ) then
			Sound = ACFM.DefaultRadarSound
		end

		ACE.SimpleSound( Sound, Radar:WorldSpaceCenter(), SoundPitch, 1000 )
	end
end


--[[---------------------------------------------------------
	THINK
-----------------------------------------------------------]]
function EFFECT:Think( )
	return false
end

--[[---------------------------------------------------------
	Draw the effect
-----------------------------------------------------------]]
function EFFECT:Render()
end
