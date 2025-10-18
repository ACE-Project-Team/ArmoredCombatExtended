include("shared.lua")

function ENT:Initialize()

	local ply = LocalPlayer()

	if ply.CanReceiveNet then
		net.Start("ACE_Scalable_Network")
			net.WriteEntity( self )
		net.SendToServer()
	end
end

--Brought from ACF3. Fixes the physgun grabbing beam glitch
function ENT:CalcAbsolutePosition() -- Faking sync
	local PhysObj  = self:GetPhysicsObject()
	local Position = self:GetPos()
	local Angles	= self:GetAngles()

	if IsValid(PhysObj) then
		PhysObj:SetPos(Position)
		PhysObj:SetAngles(Angles)
		PhysObj:EnableMotion(false) -- Disable prediction
		PhysObj:Sleep()
	end

	return Position, Angles
end

--Creates a temporal physic object for the real build.
local function BuildFakePhysics( entity )

	entity:PhysicsInit(SOLID_VPHYSICS)
	entity:SetMoveType( MOVETYPE_VPHYSICS )
	entity:SetSolid( SOLID_VPHYSICS )

	local PhysObj = entity:GetPhysicsObject()

	if IsValid(PhysObj) then
		entity.PhysicsObj = PhysObj
		PhysObj:EnableMotion(false)
		PhysObj:Sleep()
	end
end

local ModelData = ACE.ModelData

--Creates the real physic object for the scalable.
local function BuildRealPhysics( entity, Scale )

	local Model		= entity:GetModel()

	if ModelData[Model] then

		local PhysObj = entity.PhysicsObj

		local Mesh			= ModelData[Model].CustomMesh or PhysObj:GetMeshConvexes()




		local PhysMaterial  = ModelData[Model].physMaterial or ""


		if entity.ConvertMeshToScale then
			Mesh = entity:ConvertMeshToScale(Mesh, Scale)
		end

		local SafetyCatch = true --If the mesh would generate a crash bypass it. Only time will tell what this will unleash. Likely client only desync of the hitbox.

		for k, tab in pairs( Mesh ) do
			for c, v in pairs( tab ) do
				if v != vector_origin then
					SafetyCatch = false
				end
			end
		end

		if SafetyCatch then --Eject Eject Eject. Table only contains 0,0,0 entries leading to a crash.
			return
		end

		entity:PhysicsInitMultiConvex(Mesh)
		entity:EnableCustomCollisions(true)
		entity:SetRenderBounds(entity:GetCollisionBounds())
		entity:DrawShadow(false)

		PhysObj = entity:GetPhysicsObject()

		if IsValid(PhysObj) then
			entity.PhysicsObj = PhysObj
			PhysObj:SetMaterial( PhysMaterial )
			PhysObj:EnableMotion(false)
			PhysObj:Sleep()
		end
	end
end

local function CreatePropVisualScale( entity, Scale )

	BuildFakePhysics( entity )

	--If no scale is provided, we will assume the matrix already has it.
	if not Scale then
		Scale = entity.Matrix:GetScale()
	end

	entity.Matrix = Matrix()
	entity.Matrix:Scale(Scale)
	entity:EnableMatrix("RenderMultiply", entity.Matrix)

	BuildRealPhysics( entity, Scale )

end

net.Receive("ACE_Scalable_Network", function()

	local x = net.ReadFloat()
	local y = net.ReadFloat()
	local z = net.ReadFloat()

	local entity = net.ReadEntity()

	if IsValid(entity) then
		local Scale = Vector(x,y,z)
		CreatePropVisualScale( entity, Scale )
	end
end)

--This workaround fixes the issue with scale rendering not loading properly for clients who have joined after the entity creation.
--The client will request the scale renders of ALL existing entities to the server, then they will be sent to the client at tick speed (1 entity per tick), to avoid overflowing the net with alot of ents.
hook.Remove( "InitPostEntity", "ACE_RefreshScalables" )
hook.Add( "InitPostEntity", "ACE_RefreshScalables", function()

	local ply = LocalPlayer()
	ply.CanReceiveNet = true

	net.Start("ACE_Scalable_Network")
	net.SendToServer()

end)


do -- Dealing with visual clip's bullshit
	local EntMeta = FindMetaTable("Entity")

	function ENT:EnableMatrix(Type, Value, ...)

		if Type == "RenderMultiply" and self.Matrix then
			local Current = self.Matrix:GetScale()
			local Scale	= Value:GetScale()

			-- Visual clip provides a scale of 0, 0, 0
			-- So we just update it with our actual scale
			if Current ~= Scale then
				Value:SetScale(Current)
			end
		end

		return EntMeta.EnableMatrix(self, Type, Value, ...)
	end

	function ENT:DisableMatrix(Type, ...)
		if Type == "RenderMultiply" and self.Matrix then
			-- Visual clip will attempt to disable the matrix
			-- We don't want that to happen with scalable entities
			self:EnableMatrix(Type, self.Matrix)

			return
		end

		return EntMeta.DisableMatrix(self, Type, ...)
	end
end

--This workaround fixes the issue with scales being reseted after several lag or someone requesting a fullupdate.
--Unlike the initial spawn, the scale matrix is already networked at this point. So we will just request the rebuild.
hook.Remove( "NetworkEntityCreated", "ACE_RefreshScalables_FullUpdate" )
hook.Add( "NetworkEntityCreated", "ACE_RefreshScalables_FullUpdate", function( entity )

	if entity.Matrix then
		CreatePropVisualScale( entity, nil )
	end

end )