--------------------------------------------------------------------------------
-- Copyright (c) 2013, 2014 Cole Bambrick
--
-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.
-- 
-- For full documentation, see
-- https://github.com/ecbambrick/SimpleEntityComponentSystem/wiki
--------------------------------------------------------------------------------
local EntityComponentSystem = {}

--------------------------------------------------------------------------------
-- Registers or unregisters an entity to or from a group. If the requirements 
-- of the group's type are met, it is registered; otherwise, it is unregistered.
-- @param entity        The entity.
-- @param group         The group.
--------------------------------------------------------------------------------
local function registerEntityWithGroup(entity, group)
    local meetsRequirements = true

    for _, component in ipairs(group.entityType.components) do
        if not entity[component] then
            meetsRequirements = false
            break
        end
    end
    
	if meetsRequirements then
		group.entities[entity] = true
	else
		group.entities[entity] = nil
	end
end

--------------------------------------------------------------------------------
-- Registers or unregisters an entity to or from each group in the given table.
-- @param entity    The entity.
-- @param group     The table of groups.
--------------------------------------------------------------------------------
local function registerEntityWithGroups(entity, groups)
    for _, group in pairs(groups) do
        registerEntityWithGroup(entity, group)
    end
end

--------------------------------------------------------------------------------
-- Registers or unregisters all given entities to or from the given group.
-- @param scene         The scene.
-- @param group         The group.
--------------------------------------------------------------------------------
local function registerEntitiesWithGroup(entities, group)
    for entity in pairs(entities) do
        registerEntityWithGroup(entity, group)
    end
end

--------------------------------------------------------------------------------
-- Attaches a new instance of the component to the given entity using the given
-- data. Default values for the component will be used where necessary.
-- @param entity            The entity.
-- @param componentName     The name of the component.
-- @param newComponentData  The data to give to the component.
-- @return					The entity.
--------------------------------------------------------------------------------
function EntityComponentSystem:attach(entity, components)
	for name, newComponentData in pairs(components) do
		local defaultComponentData = self._components[name]
		local component = {}
		
		-- Copy the default data into the component.
		for k, v in pairs(defaultComponentData) do 
			component[k] = v
		end
		
		-- Copy the new data into the component.
		for k, v in pairs(newComponentData) do
			component[k] = v
		end
		
		-- Attach the component to the entity.
		entity[name] = component
		
	end
    
    -- Update the entity's groups.
    registerEntityWithGroups(entity, self._entityGroups)
end

--------------------------------------------------------------------------------
-- Delete and unregister all entities.
--------------------------------------------------------------------------------
function EntityComponentSystem:clear()
    for group in pairs(self._entityGroups) do
        group.entities = {}
    end
end 

--------------------------------------------------------------------------------
-- Create and register a new component constructor.
-- @param name  The name of the component.
-- @param data  The data for the component (i.e. { x = 0, y = 0 }).
--------------------------------------------------------------------------------
function EntityComponentSystem:Component(name, data)
    self._components[name] = data or {}
end

--------------------------------------------------------------------------------
-- Deletes and unregisters the given entity.
-- @param entity    The entity.
--------------------------------------------------------------------------------
function EntityComponentSystem:delete(entity)
    for component in pairs(entity) do
        -- This is faster than calling detach() on each component.
        entity[component] = nil
    end
    
    -- Unregister the entity from all entity types in the scene.
    registerEntityWithGroups(entity, self._entityGroups)
end

--------------------------------------------------------------------------------
-- Remove and unregsiter a component from an entity.
-- @param entity    The entity.
-- @param ...       The list of component names to remove.
-- @return          The table of components that were removed.
--------------------------------------------------------------------------------
function EntityComponentSystem:detach(entity, ...)
    local removedComponents = {}
    
    for _, component in ipairs({...}) do
        table.insert(removedComponents, entity[component])
        entity[component] = nil
    end
    
    registerEntityWithGroups(entity, self._entityGroups)
    
    return removedComponents
end

--------------------------------------------------------------------------------
-- Call each active render system.
--------------------------------------------------------------------------------
function EntityComponentSystem:draw()
    for _, system in pairs(self._renderSystems) do
        if system.active then
            system.update()
        end
    end
end

--------------------------------------------------------------------------------
-- Creates and registers a new entity.
-- @param ...   The table of components where each component is a name and a
--              set of data (i.e. { "pos", { x = 1, y =1 } }, { "player" }).
-- @return      The newly created entity
--------------------------------------------------------------------------------
function EntityComponentSystem:Entity(...)
	local entity = {}

	if ... then
		self:attach(entity, ...)
	else
		registerEntityWithGroup(entity, self._entityGroups.all)
	end
	
	return entity
end

--------------------------------------------------------------------------------
-- Create and register a new entity type.
-- @param name  The name of the entity type.
-- @param ...   The list of component names for that type
--------------------------------------------------------------------------------
function EntityComponentSystem:EntityType(name, ...)
    local entityType = self._entityTypes[name]
    local groups = self._entityGroups
    entityType = { components = {...} }
    groups[name] = { entityType = entityType, entities = {} }
    registerEntitiesWithGroup(groups.all.entities, entityType)    
end

--------------------------------------------------------------------------------
-- Return the list of entities of the provided type, or the list of all entities
-- if no type is provided.
-- @param entityTypeName	The name of the entity type to query by.
-- @return              	The list of entities.
--------------------------------------------------------------------------------
function EntityComponentSystem:query(entityTypeName)
    local entityTypeName = entityTypeName or "all"
    return self._entityGroups[entityTypeName].entities
end

--------------------------------------------------------------------------------
-- Return the first entity of the provided type for the current scene.
-- @param entityTypeName    The name of the entity type to query by.
-- @return              	The first entity of the given type or nil if there 
-- 							is no entity.
--------------------------------------------------------------------------------
function EntityComponentSystem:queryFirst(entityTypeName)
    return next(self:query(entityTypeName))
end

--------------------------------------------------------------------------------
-- Create and register a new render system. Systems are called in the order in
-- which they are created.
-- @param name      The name of the system.
-- @param callback  The callback function for the system.
--------------------------------------------------------------------------------
function EntityComponentSystem:RenderSystem(name, callback)
    local system = {
        active = true,
        name = name,
        update = callback
    }
    table.insert(self._renderSystems, system)
end

--------------------------------------------------------------------------------
-- Call each active update system.
-- @param dt    The delta time of the game loop.
--------------------------------------------------------------------------------
function EntityComponentSystem:update(dt)
    for _, system in pairs(self._updateSystems) do
        if system.active then
            system.update(dt)
        end
    end
end

--------------------------------------------------------------------------------
-- Create and register a new update system. Systems are called in the order in
-- which they are created.
-- @param name      The name of the system.
-- @param callback  The callback function for the system.
--------------------------------------------------------------------------------
function EntityComponentSystem:UpdateSystem(name, callback)
    local system = {
        active = true,
        name = name,
        update = callback
    }
    table.insert(self._updateSystems, system)
end

--------------------------------------------------------------------------------
-- Constructs a new instance of the entity component system.
-- @return A new instance of the entity component system.
--------------------------------------------------------------------------------
return function()
    local self = {}
    
    -- The table of components. The key is the component name and each value
    -- contains a tables of default component properties.
    self._components = {}
    
    -- The table of entity groups. The key is the name of the entity group and
    -- each value contains a table of entities that belong to that group.
    -- Each group contains an entity type and a table of entities that are of
    -- that type. The group named "all" contains all entities.
    self._entityGroups = {}
    self._entityGroups.all = { entityType = { components = {} }, entities = {} }
    
    -- The table of entity types. The key is the entity type name and each 
    -- value contains a table of compatible component names.
    self._entityTypes = {}
    
    -- The table of render systems. The key is the system name and each value
    -- contains a tables of systems properties.
    self._renderSystems = {}
    
    -- The table of update systems. The key is the system name and each value
    -- contains a tables of systems properties.
    self._updateSystems = {}
    
    return setmetatable(self, { __index = EntityComponentSystem })
end