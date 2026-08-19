-- shared.lua

DEFINE_BASECLASS( "base_wire_entity" )

ENT.PrintName = "ACF Engine"
ENT.WireDebugName = "ACF Engine"


ACF_DefineCustomEngine( "Custom_Engine", {
	name = "Custom_Engine",
	desc = "Custom Designed Engine"
} )


--Break into table. Define model, height behavior, base engine properties
ACE.CustomEngineList = {}

local EData = {}--
local function ACE_Define_CustomEngine(Data)
    local Type = Data.Type
    ACE.CustomEngineList[Type] = Data

end












--These are to be added to each engine type.

EData.Type = "I2"
EData.Mdl = "models/engines/inline2b.mdl"
--DetermineModelSize
--BaseCharacteristicsTable


ACE_Define_CustomEngine(EData)



EData.Type = "I3"
EData.Mdl = "models/engines/inline2b.mdl"
ACE_Define_CustomEngine(EData)


EData.Type = "I4"
EData.Mdl = "models/engines/inline2b.mdl"
ACE_Define_CustomEngine(EData)

EData.Type = "I5"
EData.Mdl = "models/engines/inline2b.mdl"
ACE_Define_CustomEngine(EData)

EData.Type = "I6"
EData.Mdl = "models/engines/inline2b.mdl"
ACE_Define_CustomEngine(EData)

--PrintTable(ACE.CustomEngineList)