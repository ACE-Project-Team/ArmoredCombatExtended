ACE_DefineMine( "ATL", {

    name           = "Conventional Anti-Tank Landmine",
    model          = "models/maxofs2d/button_02.mdl",
    material       = "models/props_canal/metalwall005b",
    color          = Color(255,255,255),
    weight         = 8,

    heweight       = 50,
    fragmass       = 50,
    armdelay       = 2,

    setrange       = 10,

    -- the trigger zone.
    triggermins    = Vector( -30, -30, -10 ),
    triggermaxs    = Vector( 30, 30, 40 ),

    digdepth       = 2.5,
    ignoreplayers  = true,

} )
