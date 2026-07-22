
local AmmoTable = {}  --Start ammo containers listing

--[[----------------
	Ammo Format
--------------------

local Ammo1x1x1 = {}											--Definition. The new ammocrate must have this first!
	Ammo1x1x1.id = "Ammo1x1x1"								--ID. This will be the "name" that will appear on the ammo section.
	Ammo1x1x1.ent = "acf_ammo"								--Entity Class. In this case, acf_ammo.
	Ammo1x1x1.type = "Ammo"									--Ammo, don´t change.
	Ammo1x1x1.name = "Modular Ammo Crate"						--Name. not very useful but it should have one.
	Ammo1x1x1.desc = "Modular Ammo Crate 2x4x4 Size\n"		--Desc. This is the desc of the ammocrate that will appear once selected.
	Ammo1x1x1.model = "models/hunter/blocks/cube05x05x05.mdl.mdl"--The model of this ammocrate
	Ammo1x1x1.weight = 10										--Weight of the ammocrate when its fully empty. Remember that.
	Ammo1x1x1.Lenght = 10										--X dimension of this ammocrate.
	Ammo1x1x1.Width = 10										--Y dimension of this ammocrate.
	Ammo1x1x1.Height = 10										--Z dimension of this ammocrate.
	Ammo1x1x1.volume = 1000									--Volume of this ammocrate. Looks deprecated since you can get the volume by multipling X * Y*Z
AmmoTable["Ammo1x1x1"] = Ammo1x1x1							--Putting the ammocrate on the AmmoTable



]]--
------------------------------
--Ammocrate Smallest -> Largest
------------------------------
local AmmoSmall = {}
	AmmoSmall.id = "AmmoSmall"
	AmmoSmall.ent = "acf_ammo"
	AmmoSmall.type = "Ammo"
	AmmoSmall.name = "Small Ammo Crate"
	AmmoSmall.desc = "Small ammo crate\n"
	AmmoSmall.model = "models/ammocrate_small.mdl"
	AmmoSmall.weight = 10
	AmmoSmall.Lenght = 22.955019
	AmmoSmall.Width = 8.370775
	AmmoSmall.Height = 14.521590
	AmmoSmall.volume = 2198
AmmoTable["AmmoSmall"] = AmmoSmall

local AmmoMedCube = {}
	AmmoMedCube.id = "AmmoMedCube"
	AmmoMedCube.ent = "acf_ammo"
	AmmoMedCube.type = "Ammo"
	AmmoMedCube.name = "Medium cubic ammo crate"
	AmmoMedCube.desc = "Medium cubic ammo crate\n"
	AmmoMedCube.model = "models/ammocrate_medium_small.mdl"
	AmmoMedCube.weight = 80
	AmmoMedCube.Lenght = 26.913317
	AmmoMedCube.Width = 28.773201
	AmmoMedCube.Height = 26.708260
	AmmoMedCube.volume = 17769
AmmoTable["AmmoMedCube"] = AmmoMedCube

local AmmoMedium = {}
	AmmoMedium.id = "AmmoMedium"
	AmmoMedium.ent = "acf_ammo"
	AmmoMedium.type = "Ammo"
	AmmoMedium.name = "Medium Ammo Crate"
	AmmoMedium.desc = "Medium ammo crate\n"
	AmmoMedium.model = "models/ammocrate_medium.mdl"
	AmmoMedium.weight = 150
	AmmoMedium.Lenght = 52.339195
	AmmoMedium.Width = 28.773201
	AmmoMedium.Height = 26.708260
	AmmoMedium.volume = 35105
AmmoTable["AmmoMedium"] = AmmoMedium

local AmmoLarge = {}
	AmmoLarge.id = "AmmoLarge"
	AmmoLarge.ent = "acf_ammo"
	AmmoLarge.type = "Ammo"
	AmmoLarge.name = "Large Ammo Crate"
	AmmoLarge.desc = "Large ammo crate\n"
	AmmoLarge.model = "models/ammocrate_large.mdl"
	AmmoLarge.weight = 1000
	AmmoLarge.Lenght = 53.150623
	AmmoLarge.Width = 55.965065
	AmmoLarge.Height = 52.612392
	AmmoLarge.volume = 140503
AmmoTable["AmmoLarge"] = AmmoLarge

local AmmoSuperLarge = {}
	AmmoSuperLarge.id = "AmmoSuperLarge"
	AmmoSuperLarge.ent = "acf_ammo"
	AmmoSuperLarge.type = "Ammo"
	AmmoSuperLarge.name = "Super Large Ammo Crate"
	AmmoSuperLarge.desc = "Super Large ammo crate\n"
	AmmoSuperLarge.model = "models/ammocrate_superlarge.mdl"
	AmmoSuperLarge.weight = 5000
	AmmoSuperLarge.Lenght = 103.710205
	AmmoSuperLarge.Width = 103.988159
	AmmoSuperLarge.Height = 104.474785
	AmmoSuperLarge.volume = 1124025
AmmoTable["AmmoSuperLarge"] = AmmoSuperLarge
------------------------------
--Ammocrate 1x1x8 -> 1x1x2
------------------------------
local Ammo1x1x8 = {}
	Ammo1x1x8.id = "Ammo1x1x8"
	Ammo1x1x8.ent = "acf_ammo"
	Ammo1x1x8.type = "Ammo"
	Ammo1x1x8.name = "Modular Ammo Crate"
	Ammo1x1x8.desc = "Modular Ammo Crate 1x1x8 Size\n"
	Ammo1x1x8.model = "models/ammocrates/ammo_1x1x8.mdl"
	Ammo1x1x8.weight = 40
	Ammo1x1x8.Lenght = 14.416653
	Ammo1x1x8.Width = 89.584518
	Ammo1x1x8.Height = 12.141979
	Ammo1x1x8.volume = 10872
AmmoTable["Ammo1x1x8"] = Ammo1x1x8

local Ammo1x1x6 = {}
	Ammo1x1x6.id = "Ammo1x1x6"
	Ammo1x1x6.ent = "acf_ammo"
	Ammo1x1x6.type = "Ammo"
	Ammo1x1x6.name = "Modular Ammo Crate"
	Ammo1x1x6.desc = "Modular Ammo Crate 1x1x6 Size\n"
	Ammo1x1x6.model = "models/ammocrates/ammo_1x1x6.mdl"
	Ammo1x1x6.weight = 30
	Ammo1x1x6.Lenght = 14.416653
	Ammo1x1x6.Width = 66.942780
	Ammo1x1x6.Height = 12.175970
	Ammo1x1x6.volume = 8202
AmmoTable["Ammo1x1x6"] = Ammo1x1x6

local Ammo1x1x4 = {}
	Ammo1x1x4.id = "Ammo1x1x4"
	Ammo1x1x4.ent = "acf_ammo"
	Ammo1x1x4.type = "Ammo"
	Ammo1x1x4.name = "Modular Ammo Crate"
	Ammo1x1x4.desc = "Modular Ammo Crate 1x1x4 Size\n"
	Ammo1x1x4.model = "models/ammocrates/ammo_1x1x4.mdl"
	Ammo1x1x4.weight = 20
	Ammo1x1x4.Lenght = 14.416653
	Ammo1x1x4.Width = 45.500008
	Ammo1x1x4.Height = 12.225470
	Ammo1x1x4.volume = 5519
AmmoTable["Ammo1x1x4"] = Ammo1x1x4

local Ammo1x1x2 = {}
	Ammo1x1x2.id = "Ammo1x1x2"
	Ammo1x1x2.ent = "acf_ammo"
	Ammo1x1x2.type = "Ammo"
	Ammo1x1x2.name = "Modular Ammo Crate"
	Ammo1x1x2.desc = "Modular Ammo Crate 1x1x2 Size\n"
	Ammo1x1x2.model = "models/ammocrates/ammo_1x1x2.mdl"
	Ammo1x1x2.weight = 10
	Ammo1x1x2.Lenght = 14.416653
	Ammo1x1x2.Width = 22.871534
	Ammo1x1x2.Height = 12.225470
	Ammo1x1x2.volume = 2743
AmmoTable["Ammo1x1x2"] = Ammo1x1x2
------------------------------
--Ammocrate 2x2x1 -> 2x2x8
------------------------------
local Ammo2x2x1 = {}
	Ammo2x2x1.id = "Ammo2x2x1"
	Ammo2x2x1.ent = "acf_ammo"
	Ammo2x2x1.type = "Ammo"
	Ammo2x2x1.name = "Modular Ammo Crate"
	Ammo2x2x1.desc = "Modular Ammo Crate 2x2x1 Size\n"
	Ammo2x2x1.model = "models/ammocrates/ammocrate_2x2x1.mdl"
	Ammo2x2x1.weight = 20
	Ammo2x2x1.Lenght = 22.960443
	Ammo2x2x1.Width = 8.500000
	Ammo2x2x1.Height = 20.889492
	Ammo2x2x1.volume = 3200
AmmoTable["Ammo2x2x1"] = Ammo2x2x1

local Ammo2x2x2 = {}
	Ammo2x2x2.id = "Ammo2x2x2"
	Ammo2x2x2.ent = "acf_ammo"
	Ammo2x2x2.type = "Ammo"
	Ammo2x2x2.name = "Modular Ammo Crate"
	Ammo2x2x2.desc = "Modular Ammo Crate 2x2x2 Size\n"
	Ammo2x2x2.model = "models/ammocrates/ammocrate_2x2x2.mdl"
	Ammo2x2x2.weight = 40
	Ammo2x2x2.Lenght = 20.500000
	Ammo2x2x2.Width = 24.781265
	Ammo2x2x2.Height = 21.528004
	Ammo2x2x2.volume = 8000
AmmoTable["Ammo2x2x2"] = Ammo2x2x2

local Ammo2x2x4 = {}
	Ammo2x2x4.id = "Ammo2x2x4"
	Ammo2x2x4.ent = "acf_ammo"
	Ammo2x2x4.type = "Ammo"
	Ammo2x2x4.name = "Modular Ammo Crate"
	Ammo2x2x4.desc = "Modular Ammo Crate 2x2x4 Size\n"
	Ammo2x2x4.model = "models/ammocrates/ammocrate_2x2x4.mdl"
	Ammo2x2x4.weight = 80
	Ammo2x2x4.Lenght = 23.381264
	Ammo2x2x4.Width = 45.500000
	Ammo2x2x4.Height = 20.861338
	Ammo2x2x4.volume = 18000
AmmoTable["Ammo2x2x4"] = Ammo2x2x4

local Ammo2x2x6 = {}
	Ammo2x2x6.id = "Ammo2x2x6"
	Ammo2x2x6.ent = "acf_ammo"
	Ammo2x2x6.type = "Ammo"
	Ammo2x2x6.name = "Modular Ammo Crate"
	Ammo2x2x6.desc = "Modular Ammo Crate 2x2x6 Size\n"
	Ammo2x2x6.model = "models/ammocrates/ammo_2x2x6.mdl"
	Ammo2x2x6.weight = 120
	Ammo2x2x6.Lenght = 25.906490
	Ammo2x2x6.Width = 68.293823
	Ammo2x2x6.Height = 22.772511
	Ammo2x2x6.volume = 33179
AmmoTable["Ammo2x2x6"] = Ammo2x2x6

local Ammo2x2x8 = {}
	Ammo2x2x8.id = "Ammo2x2x8"
	Ammo2x2x8.ent = "acf_ammo"
	Ammo2x2x8.type = "Ammo"
	Ammo2x2x8.name = "Modular Ammo Crate"
	Ammo2x2x8.desc = "Modular Ammo Crate 2x2x8 Size\n"
	Ammo2x2x8.model = "models/ammocrates/ammo_2x2x8.mdl"
	Ammo2x2x8.weight = 160
	Ammo2x2x8.Lenght = 25.906490
	Ammo2x2x8.Width = 91.321205
	Ammo2x2x8.Height = 22.898911
	Ammo2x2x8.volume = 45902
AmmoTable["Ammo2x2x8"] = Ammo2x2x8
------------------------------
--Ammocrate 2x3x1 -> 2x3x8
------------------------------
local Ammo2x3x1 = {}
	Ammo2x3x1.id = "Ammo2x3x1"
	Ammo2x3x1.ent = "acf_ammo"
	Ammo2x3x1.type = "Ammo"
	Ammo2x3x1.name = "Modular Ammo Crate"
	Ammo2x3x1.desc = "Modular Ammo Crate 2x3x1 Size\n"
	Ammo2x3x1.model = "models/ammocrates/ammocrate_2x3x1.mdl"
	Ammo2x3x1.weight = 30
	Ammo2x3x1.Lenght = 34.883530
	Ammo2x3x1.Width = 8.500000
	Ammo2x3x1.Height = 20.889492
	Ammo2x3x1.volume = 5119
AmmoTable["Ammo2x3x1"] = Ammo2x3x1

local Ammo2x3x2 = {}
	Ammo2x3x2.id = "Ammo2x3x2"
	Ammo2x3x2.ent = "acf_ammo"
	Ammo2x3x2.type = "Ammo"
	Ammo2x3x2.name = "Modular Ammo Crate"
	Ammo2x3x2.desc = "Modular Ammo Crate 2x3x2 Size\n"
	Ammo2x3x2.model = "models/ammocrates/ammocrate_2x3x2.mdl"
	Ammo2x3x2.weight = 60
	Ammo2x3x2.Lenght = 34.883530
	Ammo2x3x2.Width = 20.500000
	Ammo2x3x2.Height = 20.889492
	Ammo2x3x2.volume = 12799
AmmoTable["Ammo2x3x2"] = Ammo2x3x2

local Ammo2x3x4 = {}
	Ammo2x3x4.id = "Ammo2x3x4"
	Ammo2x3x4.ent = "acf_ammo"
	Ammo2x3x4.type = "Ammo"
	Ammo2x3x4.name = "Modular Ammo Crate"
	Ammo2x3x4.desc = "Modular Ammo Crate 2x3x4 Size\n"
	Ammo2x3x4.model = "models/ammocrates/ammocrate_2x3x4.mdl"
	Ammo2x3x4.weight = 120
	Ammo2x3x4.Lenght = 35.227417
	Ammo2x3x4.Width = 46.708878
	Ammo2x3x4.Height = 20.500000
	Ammo2x3x4.volume = 28800
AmmoTable["Ammo2x3x4"] = Ammo2x3x4

local Ammo2x3x6 = {}
	Ammo2x3x6.id = "Ammo2x3x6"
	Ammo2x3x6.ent = "acf_ammo"
	Ammo2x3x6.type = "Ammo"
	Ammo2x3x6.name = "Modular Ammo Crate"
	Ammo2x3x6.desc = "Modular Ammo Crate 2x3x6 Size\n"
	Ammo2x3x6.model = "models/ammocrates/ammocrate_2x3x6.mdl"
	Ammo2x3x6.weight = 180
	Ammo2x3x6.Lenght = 35.227402
	Ammo2x3x6.Width = 69.478600
	Ammo2x3x6.Height = 20.535498
	Ammo2x3x6.volume = 43421
AmmoTable["Ammo2x3x6"] = Ammo2x3x6

local Ammo2x3x8 = {}
	Ammo2x3x8.id = "Ammo2x3x8"
	Ammo2x3x8.ent = "acf_ammo"
	Ammo2x3x8.type = "Ammo"
	Ammo2x3x8.name = "Modular Ammo Crate"
	Ammo2x3x8.desc = "Modular Ammo Crate 2x3x8 Size\n"
	Ammo2x3x8.model = "models/ammocrates/ammocrate_2x3x8.mdl"
	Ammo2x3x8.weight = 240
	Ammo2x3x8.Lenght = 35.227402
	Ammo2x3x8.Width = 91.384796
	Ammo2x3x8.Height = 20.535498
	Ammo2x3x8.volume = 57509
AmmoTable["Ammo2x3x8"] = Ammo2x3x8
------------------------------
--Ammocrate 2x4x1 -> 2x4x8
------------------------------
local Ammo2x4x1 = {}
	Ammo2x4x1.id = "Ammo2x4x1"
	Ammo2x4x1.ent = "acf_ammo"
	Ammo2x4x1.type = "Ammo"
	Ammo2x4x1.name = "Modular Ammo Crate"
	Ammo2x4x1.desc = "Modular Ammo Crate 2x4x1 Size\n"
	Ammo2x4x1.model = "models/ammocrates/ammocrate_2x4x1.mdl"
	Ammo2x4x1.weight = 40
	Ammo2x4x1.Lenght = 47.994637
	Ammo2x4x1.Width = 8.500000
	Ammo2x4x1.Height = 20.889492
	Ammo2x4x1.volume = 7200
AmmoTable["Ammo2x4x1"] = Ammo2x4x1

local Ammo2x4x2 = {}
	Ammo2x4x2.id = "Ammo2x4x2"
	Ammo2x4x2.ent = "acf_ammo"
	Ammo2x4x2.type = "Ammo"
	Ammo2x4x2.name = "Modular Ammo Crate"
	Ammo2x4x2.desc = "Modular Ammo Crate 2x4x2 Size\n"
	Ammo2x4x2.model = "models/ammocrates/ammocrate_2x4x2.mdl"
	Ammo2x4x2.weight = 80
	Ammo2x4x2.Lenght = 45.500000
	Ammo2x4x2.Width = 23.381268
	Ammo2x4x2.Height = 20.861338
	Ammo2x4x2.volume = 18000
AmmoTable["Ammo2x4x2"] = Ammo2x4x2

local Ammo2x4x4 = {}
	Ammo2x4x4.id = "Ammo2x4x4"
	Ammo2x4x4.ent = "acf_ammo"
	Ammo2x4x4.type = "Ammo"
	Ammo2x4x4.name = "Modular Ammo Crate"
	Ammo2x4x4.desc = "Modular Ammo Crate 2x4x4 Size\n"
	Ammo2x4x4.model = "models/ammocrates/ammocrate_2x4x4.mdl"
	Ammo2x4x4.weight = 160
	Ammo2x4x4.Lenght = 48.338524
	Ammo2x4x4.Width = 46.708878
	Ammo2x4x4.Height = 20.500000
	Ammo2x4x4.volume = 40500
AmmoTable["Ammo2x4x4"] = Ammo2x4x4

local Ammo2x4x6 = {}
	Ammo2x4x6.id = "Ammo2x4x6"
	Ammo2x4x6.ent = "acf_ammo"
	Ammo2x4x6.type = "Ammo"
	Ammo2x4x6.name = "Modular Ammo Crate"
	Ammo2x4x6.desc = "Modular Ammo Crate 2x4x6 Size\n"
	Ammo2x4x6.model = "models/ammocrates/ammocrate_2x4x6.mdl"
	Ammo2x4x6.weight = 240
	Ammo2x4x6.Lenght = 48.338524
	Ammo2x4x6.Width = 69.375534
	Ammo2x4x6.Height = 20.500000
	Ammo2x4x6.volume = 61200
AmmoTable["Ammo2x4x6"] = Ammo2x4x6

local Ammo2x4x8 = {}
	Ammo2x4x8.id = "Ammo2x4x8"
	Ammo2x4x8.ent = "acf_ammo"
	Ammo2x4x8.type = "Ammo"
	Ammo2x4x8.name = "Modular Ammo Crate"
	Ammo2x4x8.desc = "Modular Ammo Crate 2x4x8 Size\n"
	Ammo2x4x8.model = "models/ammocrates/ammocrate_2x4x8.mdl"
	Ammo2x4x8.weight = 320
	Ammo2x4x8.Lenght = 48.338524
	Ammo2x4x8.Width = 91.375534
	Ammo2x4x8.Height = 20.500000
	Ammo2x4x8.volume = 80999
AmmoTable["Ammo2x4x8"] = Ammo2x4x8
------------------------------
--Ammocrate 3x4x1 -> 3x4x8
------------------------------
local Ammo3x4x1 = {}
	Ammo3x4x1.id = "Ammo3x4x1"
	Ammo3x4x1.ent = "acf_ammo"
	Ammo3x4x1.type = "Ammo"
	Ammo3x4x1.name = "Modular Ammo Crate"
	Ammo3x4x1.desc = "Modular Ammo Crate 3x4x1 Size\n"
	Ammo3x4x1.model = "models/ammocrates/ammocrate_3x4x1.mdl"
	Ammo3x4x1.weight = 60
	Ammo3x4x1.Lenght = 47.994637
	Ammo3x4x1.Width = 8.500000
	Ammo3x4x1.Height = 33.000607
	Ammo3x4x1.volume = 11520
AmmoTable["Ammo3x4x1"] = Ammo3x4x1

local Ammo3x4x2 = {}
	Ammo3x4x2.id = "Ammo3x4x2"
	Ammo3x4x2.ent = "acf_ammo"
	Ammo3x4x2.type = "Ammo"
	Ammo3x4x2.name = "Modular Ammo Crate"
	Ammo3x4x2.desc = "Modular Ammo Crate 3x4x2 Size\n"
	Ammo3x4x2.model = "models/ammocrates/ammocrate_3x4x2.mdl"
	Ammo3x4x2.weight = 120
	Ammo3x4x2.Lenght = 45.500000
	Ammo3x4x2.Width = 23.381268
	Ammo3x4x2.Height = 33.013718
	Ammo3x4x2.volume = 28800
AmmoTable["Ammo3x4x2"] = Ammo3x4x2

local Ammo3x4x4 = {}
	Ammo3x4x4.id = "Ammo3x4x4"
	Ammo3x4x4.ent = "acf_ammo"
	Ammo3x4x4.type = "Ammo"
	Ammo3x4x4.name = "Modular Ammo Crate"
	Ammo3x4x4.desc = "Modular Ammo Crate 3x4x4 Size\n"
	Ammo3x4x4.model = "models/ammocrates/ammocrate_3x4x4.mdl"
	Ammo3x4x4.weight = 240
	Ammo3x4x4.Lenght = 48.338524
	Ammo3x4x4.Width = 46.708878
	Ammo3x4x4.Height = 32.500000
	Ammo3x4x4.volume = 64800
AmmoTable["Ammo3x4x4"] = Ammo3x4x4

local Ammo3x4x6 = {}
	Ammo3x4x6.id = "Ammo3x4x6"
	Ammo3x4x6.ent = "acf_ammo"
	Ammo3x4x6.type = "Ammo"
	Ammo3x4x6.name = "Modular Ammo Crate"
	Ammo3x4x6.desc = "Modular Ammo Crate 3x4x6 Size\n"
	Ammo3x4x6.model = "models/ammocrates/ammocrate_3x4x6.mdl"
	Ammo3x4x6.weight = 360
	Ammo3x4x6.Lenght = 48.338524
	Ammo3x4x6.Width = 69.375534
	Ammo3x4x6.Height = 32.500000
	Ammo3x4x6.volume = 97920
AmmoTable["Ammo3x4x6"] = Ammo3x4x6

local Ammo3x4x8 = {}
	Ammo3x4x8.id = "Ammo3x4x8"
	Ammo3x4x8.ent = "acf_ammo"
	Ammo3x4x8.type = "Ammo"
	Ammo3x4x8.name = "Modular Ammo Crate"
	Ammo3x4x8.desc = "Modular Ammo Crate 3x4x8 Size\n"
	Ammo3x4x8.model = "models/ammocrates/ammocrate_3x4x8.mdl"
	Ammo3x4x8.weight = 480
	Ammo3x4x8.Lenght = 50.202568
	Ammo3x4x8.Width = 91.375534
	Ammo3x4x8.Height = 32.500000
	Ammo3x4x8.volume = 129599
AmmoTable["Ammo3x4x8"] = Ammo3x4x8
------------------------------
--Ammocrate 4x4x1 -> 4x4x8
------------------------------
local Ammo4x4x1 = {}
	Ammo4x4x1.id = "Ammo4x4x1"
	Ammo4x4x1.ent = "acf_ammo"
	Ammo4x4x1.type = "Ammo"
	Ammo4x4x1.name = "Modular Ammo Crate"
	Ammo4x4x1.desc = "Modular Ammo Crate 4x4x1 Size\n"
	Ammo4x4x1.model = "models/ammocrates/ammo_4x4x1.mdl"
	Ammo4x4x1.weight = 80
	Ammo4x4x1.Lenght = 48.334381
	Ammo4x4x1.Width = 46.244804
	Ammo4x4x1.Height = 11.950006
	Ammo4x4x1.volume = 23186
AmmoTable["Ammo4x4x1"] = Ammo4x4x1

local Ammo4x4x2 = {}
	Ammo4x4x2.id = "Ammo4x4x2"
	Ammo4x4x2.ent = "acf_ammo"
	Ammo4x4x2.type = "Ammo"
	Ammo4x4x2.name = "Modular Ammo Crate"
	Ammo4x4x2.desc = "Modular Ammo Crate 4x4x2 Size\n"
	Ammo4x4x2.model = "models/ammocrates/ammocrate_4x4x2.mdl"
	Ammo4x4x2.weight = 160
	Ammo4x4x2.Lenght = 46.298180
	Ammo4x4x2.Width = 23.381268
	Ammo4x4x2.Height = 45.500000
	Ammo4x4x2.volume = 40500
AmmoTable["Ammo4x4x2"] = Ammo4x4x2

local Ammo4x4x4 = {}
	Ammo4x4x4.id = "Ammo4x4x4"
	Ammo4x4x4.ent = "acf_ammo"
	Ammo4x4x4.type = "Ammo"
	Ammo4x4x4.name = "Modular Ammo Crate"
	Ammo4x4x4.desc = "Modular Ammo Crate 4x4x4 Size\n"
	Ammo4x4x4.model = "models/ammocrates/ammocrate_4x4x4.mdl"
	Ammo4x4x4.weight = 320
	Ammo4x4x4.Lenght = 50.202568
	Ammo4x4x4.Width = 46.708878
	Ammo4x4x4.Height = 45.500000
	Ammo4x4x4.volume = 91125
AmmoTable["Ammo4x4x4"] = Ammo4x4x4

local Ammo4x4x6 = {}
	Ammo4x4x6.id = "Ammo4x4x6"
	Ammo4x4x6.ent = "acf_ammo"
	Ammo4x4x6.type = "Ammo"
	Ammo4x4x6.name = "Modular Ammo Crate"
	Ammo4x4x6.desc = "Modular Ammo Crate 4x4x6 Size\n"
	Ammo4x4x6.model = "models/ammocrates/ammocrate_4x4x6.mdl"
	Ammo4x4x6.weight = 480
	Ammo4x4x6.Lenght = 50.202568
	Ammo4x4x6.Width = 69.486656
	Ammo4x4x6.Height = 45.500000
	Ammo4x4x6.volume = 137700
AmmoTable["Ammo4x4x6"] = Ammo4x4x6

local Ammo4x4x8 = {}
	Ammo4x4x8.id = "Ammo4x4x8"
	Ammo4x4x8.ent = "acf_ammo"
	Ammo4x4x8.type = "Ammo"
	Ammo4x4x8.name = "Modular Ammo Crate"
	Ammo4x4x8.desc = "Modular Ammo Crate 4x4x8 Size\n"
	Ammo4x4x8.model = "models/ammocrates/ammocrate_4x4x8.mdl"
	Ammo4x4x8.weight = 640
	Ammo4x4x8.Lenght = 50.202568
	Ammo4x4x8.Width = 91.361649
	Ammo4x4x8.Height = 45.500000
	Ammo4x4x8.volume = 182249
AmmoTable["Ammo4x4x8"] = Ammo4x4x8
------------------------------
--Ammocrate 4x6x8 -> 4x6x6
------------------------------
local Ammo4x6x8 = {}
	Ammo4x6x8.id = "Ammo4x6x8"
	Ammo4x6x8.ent = "acf_ammo"
	Ammo4x6x8.type = "Ammo"
	Ammo4x6x8.name = "Modular Ammo Crate"
	Ammo4x6x8.desc = "Modular Ammo Crate 4x6x8 Size\n"
	Ammo4x6x8.model = "models/ammocrates/ammo_4x6x8.mdl"
	Ammo4x6x8.weight = 800
	Ammo4x6x8.Lenght = 73.274414
	Ammo4x6x8.Width = 91.361649
	Ammo4x6x8.Height = 45.424000
	Ammo4x6x8.volume = 272664
AmmoTable["Ammo4x6x8"] = Ammo4x6x8

local Ammo4x6x6 = {}
	Ammo4x6x6.id = "Ammo4x6x6"
	Ammo4x6x6.ent = "acf_ammo"
	Ammo4x6x6.type = "Ammo"
	Ammo4x6x6.name = "Modular Ammo Crate"
	Ammo4x6x6.desc = "Modular Ammo Crate 4x6x6 Size\n"
	Ammo4x6x6.model = "models/ammocrates/ammo_4x6x6.mdl"
	Ammo4x6x6.weight = 720
	Ammo4x6x6.Lenght = 73.274414
	Ammo4x6x6.Width = 69.360962
	Ammo4x6x6.Height = 45.440872
	Ammo4x6x6.volume = 204106
AmmoTable["Ammo4x6x6"] = Ammo4x6x6
------------------------------
--Ammocrate 4x8x8 -> 4x8x8
------------------------------
local Ammo4x8x8 = {}
	Ammo4x8x8.id = "Ammo4x8x8"
	Ammo4x8x8.ent = "acf_ammo"
	Ammo4x8x8.type = "Ammo"
	Ammo4x8x8.name = "Modular Ammo Crate"
	Ammo4x8x8.desc = "Modular Ammo Crate 4x8x8 Size\n"
	Ammo4x8x8.model = "models/ammocrates/ammo_4x8x8.mdl"
	Ammo4x8x8.weight = 960
	Ammo4x8x8.Lenght = 95.190125
	Ammo4x8x8.Width = 91.361649
	Ammo4x8x8.Height = 45.627903
	Ammo4x8x8.volume = 366397
AmmoTable["Ammo4x8x8"] = Ammo4x8x8
------------------------------
--Ammocrate Shells 75mm -> 170mm
------------------------------
local Shell75mm = {}
	Shell75mm.id = "Shell75mm"

	Shell75mm.ent = "acf_ammo"
	Shell75mm.type = "Ammo"
	Shell75mm.name = "Modular Ammo Crate"
	Shell75mm.desc = "A single 75mm Shell. As an alternative to the bulky ammocrates.\n"
	Shell75mm.model = "models/munitions/round_75mm.mdl"
	Shell75mm.weight = 5
	Shell75mm.Lenght = 3
	Shell75mm.Width = 3
	Shell75mm.Height = 31
	Shell75mm.volume = 613.313
AmmoTable["Shell75mm"] = Shell75mm

local Shell100mm = {}
	Shell100mm.id = "Shell100mm"
	Shell100mm.ent = "acf_ammo"
	Shell100mm.type = "Ammo"
	Shell100mm.name = "Modular Ammo Crate"
	Shell100mm.desc = "A single 100mm Shell. As an alternative to the bulky ammocrates.\n"
	Shell100mm.model = "models/munitions/round_100mm.mdl"
	Shell100mm.weight = 10
	Shell100mm.Lenght = 4
	Shell100mm.Width = 4
	Shell100mm.Height = 36.7
	Shell100mm.volume = 1453.780
AmmoTable["Shell100mm"] = Shell100mm

local Shell120mm = {}
	Shell120mm.id = "Shell120mm"
	Shell120mm.ent = "acf_ammo"
	Shell120mm.type = "Ammo"
	Shell120mm.name = "Modular Ammo Crate"
	Shell120mm.desc = "A single 120mm Shell. As an alternative to the bulky ammocrates.\n"
	Shell120mm.model = "models/munitions/round_120mm.mdl"
	Shell120mm.weight = 15
	Shell120mm.Lenght = 4.73
	Shell120mm.Width = 4.73
	Shell120mm.Height = 44
	Shell120mm.volume = 2512.131
AmmoTable["Shell120mm"] = Shell120mm

local Shell120mmAP = {}
	Shell120mmAP.id = "Shell120mmAP"
	Shell120mmAP.ent = "acf_ammo"
	Shell120mmAP.type = "Ammo"
	Shell120mmAP.name = "Modular Ammo Crate"
	Shell120mmAP.desc = "A single 120mm AP Shell. As an alternative to the bulky ammocrates.\n"
	Shell120mmAP.model = "models/munitions/round_120mm_ap.mdl"
	Shell120mmAP.weight = 15
	Shell120mmAP.Lenght = 4.73
	Shell120mmAP.Width = 4.73
	Shell120mmAP.Height = 44
	Shell120mmAP.volume = 2512.131
AmmoTable["Shell120mmAP"] = Shell120mmAP

local Shell140mm = {}
	Shell140mm.id = "Shell140mm"
	Shell140mm.ent = "acf_ammo"
	Shell140mm.type = "Ammo"
	Shell140mm.name = "Modular Ammo Crate"
	Shell140mm.desc = "A single 140mm Shell. As an alternative to the bulky ammocrates.\n"
	Shell140mm.model = "models/munitions/round_130mm.mdl"
	Shell140mm.weight = 35
	Shell140mm.Lenght = 5.52
	Shell140mm.Width = 5.52
	Shell140mm.Height = 50
	Shell140mm.volume = 6238.189
AmmoTable["Shell140mm"] = Shell140mm

local Shell170mm = {}
	Shell170mm.id = "Shell170mm"
	Shell170mm.ent = "acf_ammo"
	Shell170mm.type = "Ammo"
	Shell170mm.name = "Modular Ammo Crate"
	Shell170mm.desc = "A single 170mm Shell. As an alternative to the bulky ammocrates.\n"
	Shell170mm.model = "models/munitions/round_200mm.mdl"
	Shell170mm.weight = 65
	Shell170mm.Lenght = 6.7
	Shell170mm.Width = 6.7
	Shell170mm.Height = 60.7
	Shell170mm.volume = 11630.235
AmmoTable["Shell170mm"] = Shell170mm

ACE.Weapons.Ammo = AmmoTable --end ammo containers listing

--Cube
ACE_DefineModelData("Box",{

	Shape = "Box",
	Model = "models/holograms/rcube_thin.mdl", --Note: The model can be used as ID if needed.
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(6, 6, 6),
			Vector(6, -6, 6),
			Vector(-6, 6, 6),
			Vector(-6, -6, 6),
			Vector(6, 6, -6),
			Vector(6, -6, -6),
			Vector(-6, 6, -6),
			Vector(-6, -6, -6)
		},
	},
	volumefunction = function( L, W, H )
		local volume = L * W * H
		return volume
	end
})

--Triangle / Wedge
ACE_DefineModelData("Wedge",{

	Shape = "Wedge",
	Model = "models/holograms/right_prism.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(-6, 6, 6),
			Vector(-6, -6, 6),
			Vector(6, 6, -6),
			Vector(6, -6, -6),
			Vector(-6, 6, -6),
			Vector(-6, -6, -6)
		},
	},
	volumefunction = function( L, W, H )
		local volume = (L * W * H) / 2
		return volume
	end
})

--Another type of wedge.
ACE_DefineModelData("Prism",{

	Shape = "Prism",
	Model = "models/holograms/prism.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(0, 6, 6),
			Vector(0, -6, 6),
			Vector(6, 6, -6),
			Vector(6, -6, -6),
			Vector(-6, 6, -6),
			Vector(-6, -6, -6)
		},
	},
	volumefunction = function( L, W, H )
		local volume = (( L * H  ) / 2 ) * W
		return volume
	end
})

local PI = math.pi

--Cylinder
ACE_DefineModelData("Cylinder",{

	Shape = "Cylinder",
	Model = "models/holograms/hq_rcylinder_thin.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = {
		{
			Vector(6, 0, -6),
			Vector(0, -6, -6),
			Vector(-6, 0, -6),
			Vector(0, 6, -6),

			Vector(4.24, -4.24, -6),
			Vector(-4.24, -4.24, -6),
			Vector(-4.24, 4.24, -6),
			Vector(4.24, 4.24, -6),

			Vector(6, 0, 6),
			Vector(0, -6, 6),
			Vector(-6, 0, 6),
			Vector(0, 6, 6),

			Vector(4.24, -4.24, 6),
			Vector(-4.24, -4.24, 6),
			Vector(-4.24, 4.24, 6),
			Vector(4.24, 4.24, 6),
		}
	},
	volumefunction = function( L, W, H )
		local volume = PI * (L / 2) * (W / 2) * H
		return volume
	end
})

-- The sphere. Dont ask how i got its vertex.
ACE_DefineModelData("Sphere",{

	Shape = "Sphere",
	Model = "models/holograms/hq_sphere.mdl", --Note: The model can be used as ID if needed.
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = { --Its a box anyways
		{
			Vector(4.242640, -4.242640, 0.000000),
			Vector(3.919689, -3.919689, 2.296101),
			Vector(6.000000, 0.000000, -0.000000),
			Vector(5.543278, 0.000000, 2.296100),
			Vector(5.543278, 0.000000, -2.296100),
			Vector(3.919689, -3.919689, -2.296101),
			Vector(0.000000, -6.000000, -0.000000),
			Vector(0.000000, -5.543278, 2.296100),
			Vector(-0.000000, -5.543278, -2.296100),
			Vector(3.000000, 3.000000, -4.242640),
			Vector(0.000000, 2.296101, -5.543277),
			Vector(1.623588, 1.623588, -5.543277),
			Vector(0.000000, 4.242641, -4.242640),
			Vector(0.000000, 0.000000, -6.000000),
			Vector(-1.623588, 1.623588, -5.543277),
			Vector(-3.000000, 3.000000, -4.242640),
			Vector(0.000000, 4.242641, 4.242640),
			Vector(-3.919689, 3.919689, 2.296101),
			Vector(0.000000, 5.543278, 2.296100),
			Vector(-0.000000, 6.000000, 0.000000),
			Vector(3.919689, 3.919689, 2.296101),
			Vector(4.242640, 4.242640, -0.000000),
			Vector(3.919689, 3.919689, -2.296101),
			Vector(0.000000, -2.296101, -5.543277),
			Vector(1.623588, -1.623588, -5.543277),
			Vector(2.296101, -0.000000, -5.543277),
			Vector(0.000000, -4.242641, -4.242640),
			Vector(3.000000, -3.000000, -4.242640),
			Vector(4.242641, 0.000000, -4.242640),
			Vector(-3.919689, -3.919689, -2.296101),
			Vector(-4.242641, 0.000000, 4.242640),
			Vector(-3.000000, 3.000000, 4.242640),
			Vector(-2.296101, 0.000000, 5.543277),
			Vector(-1.623588, -1.623588, 5.543277),
			Vector(0.000000, 0.000000, 6.000000),
			Vector(-1.623588, 1.623588, 5.543277),
			Vector(-3.000000, -3.000000, 4.242640),
			Vector(-0.000000, 5.543278, -2.296100),
			Vector(-3.919689, 3.919689, -2.296101),
			Vector(1.623588, -1.623588, 5.543277),
			Vector(3.000000, -3.000000, 4.242640),
			Vector(0.000000, -2.296101, 5.543277),
			Vector(0.000000, -4.242641, 4.242640),
			Vector(2.296101, -0.000000, 5.543277),
			Vector(4.242641, -0.000000, 4.242640),
			Vector(-3.919689, -3.919689, 2.296101),
			Vector(-4.242640, -4.242640, 0.000000),
			Vector(-5.543278, 0.000000, 2.296100),
			Vector(-2.296101, 0.000000, -5.543277),
			Vector(3.000000, 3.000000, 4.242640),
			Vector(-4.242641, -0.000000, -4.242640),
			Vector(-5.543278, 0.000000, -2.296100),
			Vector(-3.000000, -3.000000, -4.242640),
			Vector(-1.623588, -1.623588, -5.543277),
			Vector(0.000000, 2.296101, 5.543277),
			Vector(1.623588, 1.623588, 5.543277),
			Vector(-6.000000, 0.000000, -0.000000),
			Vector(-4.242640, 4.242640, 0.000000)
		},
	},
	volumefunction = function( L, W, H )
		local volume = ( 4 / 3 ) * PI * (L / 2) * (W / 2) * (H / 2)
		return volume
	end
})

--Cone
ACE_DefineModelData("Cone",{

	Shape = "Cone",
	Model = "models/holograms/hq_cone.mdl",
	physMaterial = "metal",
	DefaultSize = 12,
	CustomMesh = {
		{
			Vector(6, 0, -6),
			Vector(0, -6, -6),
			Vector(-6, 0, -6),
			Vector(0, 6, -6),

			Vector(4.24, -4.24, -6),
			Vector(-4.24, -4.24, -6),
			Vector(-4.24, 4.24, -6),
			Vector(4.24, 4.24, -6),

			Vector(0, 0, 6),
		}
	},
	volumefunction = function( L, W, H )
		local volume = (1 / 3) * PI * (L / 2) * (W / 2) * H
		return volume
	end
})
