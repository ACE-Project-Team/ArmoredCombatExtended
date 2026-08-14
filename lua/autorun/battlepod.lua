local function HandleACFPodAnimation( _, player )
	return player:LookupSequence("drive_pd")
end

local Category = "Armoured Combat Framework"

local V =  {
	Name = "Standard Driver Pod",
	Class = "prop_vehicle_prisoner_pod",
	Category = Category,

	Author = "Lazermaniac",
	Information = "Modified prisonpod for more realistic player damage",
	Model = "models/vehicles/driver_pod.mdl",
	KeyValues = {
					vehiclescript	=	"scripts/vehicles/prisoner_pod.txt",
					limitview		=	"0"
				},
	Members = {
					HandleAnimation = HandleACFPodAnimation
	}
}
list.Set( "Vehicles", "ACE_pod", V )

local V = {
	-- Required information
	Name = "Standard Pilot Seat",
	Class = "prop_vehicle_prisoner_pod",
	Category = Category,

	-- Optional information
	Author = "Lazermaniac",
	Information = "A generic seat for accurate damage modelling.",
	Model = "models/vehicles/pilot_seat.mdl",
	KeyValues = {
					vehiclescript	=	"scripts/vehicles/prisoner_pod.txt",
					limitview		=	"0"
				},
}
list.Set( "Vehicles", "ACE_pilotseat", V )

-- Keep old dupes using the former ACF vehicle key without adding a duplicate spawn-menu entry.
