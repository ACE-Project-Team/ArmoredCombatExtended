--[[

    ACE_DefineMine( "Example-ID", {

        name               = "Im a Mine", --The full name of the mine.
        model              = "models/cyborgmatt/capacitor_small.mdl", -- The in-game model
        material           = "models/props_canal/canal_bridge_railing_01c", -- The material render. Don't add one if you prefer the default model texture.
        color              = Color(255,255,255), -- The color. Don't add one if you prefer the original color
        weight             = 4, -- The weight of this mine

        heweight           = 1, -- The HE filler mass
        fragmass           = 0.1, -- The HE frag mass
        armdelay           = 2, -- The time (in seconds) this mine needs to be ready to explode, since it was put on ground.

        setrange           = 10, -- The trace which detects the ground. Needed when the mine is looking for ground.

        triggermins        = Vector( -90, -90, -10 ), -- the trigger mins area
        triggermaxs        = Vector( 90, 90, 40 ), -- the same as above, but maxs

        digdepth           = 7.1, -- how much (in units) from the origin center of the model will be inserted into the ground?
        groundinverted     = true, -- If true, the model will be put upside down when its attached to the ground. Bounding-APL model requires it

        ignoreplayers      = false, -- Defines if the mine should be triggered by players or not. NPCs CAN DETONATE IT EVEN IF FALSE.
        shouldjump         = true, -- If true, the mine will "jump" off the ground.
        jumpforce          = 290, -- If the mine will jump, this will tell how much force will be put on it.
        detonationdelay    = 0.5, -- Same as above. How many seconds after the initial jump are required to explode

        customdetonation   = function( MineEntity ) print("a custom detonation") end, -- If needed, you can override the default detonation with this.

    } )
]]

ACE_DefineMine( "APL", {

    name           = "Conventional Anti-Personnel Landmine",
    model          = "models/jaanus/wiretool/wiretool_range.mdl",
    material       = "models/props_canal/metalwall005b",
    color          = Color(255,255,255),
    weight         = 4,

    heweight       = 0.5,
    fragmass       = 0.1,
    armdelay       = 2,

    setrange       = 10,

    triggermins    = Vector( -60, -60, -10 ),
    triggermaxs    = Vector( 60, 60, 40 ),

    digdepth       = 1.05,

} )
ACE_DefineMine( "Bounding-APL", {

    name               = "Bounding Anti-Personnel Landmine",
    model              = "models/cyborgmatt/capacitor_small.mdl",
    material           = "models/props_canal/canal_bridge_railing_01c",
    color              = Color(255,255,255),
    weight             = 4,

    heweight           = 1,
    fragmass           = 0.1,
    armdelay           = 2,

    setrange           = 10,

    -- the trigger zone.
    triggermins        = Vector( -90, -90, -10 ), -- the trigger mins area,
    triggermaxs        = Vector( 90, 90, 40 ), -- the same as above, but maxs

    digdepth           = 7.1, -- how much (in units) from the origin center of the model will be inserted into the ground?
    groundinverted     = true, -- If true, the model will be put upside down when its attached to the ground. Bounding-APL model requires it

    ignoreplayers      = false, -- Defines if the mine should be triggered by players or not. NPCs CAN DETONATE IT EVEN IF FALSE.
    shouldjump         = true, -- If true, the mine will "jump" off the ground.
    jumpforce          = 290, -- If the mine will jump, this will tell how much force will be put on it.
    detonationdelay    = 0.5, -- Same as above. How many seconds after the initial jump are required to explode

} )
