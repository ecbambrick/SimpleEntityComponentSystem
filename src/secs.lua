--------------------------------------------------------------------------------
-- Copyright (c) 2013, 2014, 2015 Cole Bambrick
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
-- For full documentation, see README.md
--------------------------------------------------------------------------------
local module = {}
local class  = {}

setmetatable(module, { __call = function(_) return module.new() end })

--------------------------------------------------------------------------------
-- Parses the given query for a list of component names and returns a table of
-- those names. If a component name does not exist in the table of registered
-- components, then an error is thrown.
-- @param queryString          The query to parse.
-- @param registeredComponents The list of all registered components.
-- @return                     The table of component names.
--------------------------------------------------------------------------------
local function parseQuery(queryString, registeredComponents)
    local components = {}
    
    for componentName in queryString:gmatch("%S+") do
        if not registeredComponents[componentName] then
            error("Query Error: " .. componentName .. " could not be found.")
        end
        
        table.insert(components, componentName)
    end
    
    return components
end

--------------------------------------------------------------------------------
-- Registers or unregisters an entity to or from a group. If the requirements 
-- of the group's type are met, it is registered; otherwise, it is unregistered.
-- @param entity The entity.
-- @param group  The group.
--------------------------------------------------------------------------------
local function registerEntityWithGroup(entity, group)
    local meetsRequirements = true

    for _, component in ipairs(group.components) do
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
-- @param entity The entity.
-- @param group  The table of groups.
--------------------------------------------------------------------------------
local function registerEntityWithGroups(entity, groups)
    for _, group in pairs(groups) do
        registerEntityWithGroup(entity, group)
    end
end

--------------------------------------------------------------------------------
-- Registers or unregisters all given entities to or from the given group.
-- @param entities The entities.
-- @param group    The group.
--------------------------------------------------------------------------------
local function registerEntitiesWithGroup(entities, group)
    for entity in pairs(entities) do
        registerEntityWithGroup(entity, group)
    end
end

--------------------------------------------------------------------------------
-- Create and register a new component constructor.
-- @param name The name of the component.
-- @param data The data for the component (i.e. { x = 0, y = 0 }).
--------------------------------------------------------------------------------
function class:addComponent(name, data)
    self._components[name] = data or {}
end

--------------------------------------------------------------------------------
-- Creates and registers a new entity.
-- @param components The table of components where each component is a name and 
--                   a set of data (i.e. { pos = { x = 1 }, isPlayer = {} }).
-- @return           The newly created entity.
--------------------------------------------------------------------------------
function class:addEntity(components)
    local entity = {}

    if components then
        self:attach(entity, components)
    else
        registerEntityWithGroups(entity, self._entityGroups)
    end
    
    return entity
end

--------------------------------------------------------------------------------
-- Creates and registers a new render system. Systems are called in the order 
-- in which they are created.
-- @param name     The name of the system.
-- @param callback The callback function for the system.
--------------------------------------------------------------------------------
function class:addSystem(name, system)
    if system.isActive == nil then
        system.isActive = true
    end
    
    if system.update then
        table.insert(self._updateSystems, system)
    end
    
    if system.draw then 
        table.insert(self._renderSystems, system)
    end
end

--------------------------------------------------------------------------------
-- Attaches a new instance of the component to the given entity using the given
-- data. Default values for the component will be used where necessary. If the
-- component does not exist, an error is thrown.
-- @param entity     The entity.
-- @param components The components.
--------------------------------------------------------------------------------
function class:attach(entity, components)
    for name, newComponentData in pairs(components) do
        local defaultComponentData = self._components[name]
        local component = {}
        
        if defaultComponentData == nil then
            error("Attach error: " .. name .. " could not be found.")
        end
        
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
function class:clear()
    for group in pairs(self._entityGroups) do
        group.entities = {}
    end
end

--------------------------------------------------------------------------------
-- Deletes and unregisters the given entity.
-- @param entity The entity.
--------------------------------------------------------------------------------
function class:delete(entity)
    -- This is faster than calling detach() on each component. Since 
    -- detach() updates the entity's groups, you can skip this step until 
    -- after all components have been removed.
    for component in pairs(entity) do
        entity[component] = nil
    end
    
    -- Unregister the entity from all entity types in the scene.
    registerEntityWithGroups(entity, self._entityGroups)
end

--------------------------------------------------------------------------------
-- Remove and unregsiter a component from an entity.
-- @param entity The entity.
-- @param ...    The list of names of components to remove.
-- @return       The table of components that were removed.
--------------------------------------------------------------------------------
function class:detach(entity, ...)
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
function class:draw()
    for _, system in pairs(self._renderSystems) do
        if system.isActive then
            system:draw()
        end
    end
end

--------------------------------------------------------------------------------
-- Returns the list of entities that satisfy the given query, or a list of all
-- entities if no query is given.
-- @param queryString A whitespace-separated string of component names.
-- @return            The list of entities.
--------------------------------------------------------------------------------
function class:query(queryString)
    local queryString = queryString or "all"

    if not self._entityGroups[queryString] then
        local components = parseQuery(queryString, self._components)
        local groups = self._entityGroups
        groups[queryString] = { components = components, entities = {} }
        registerEntitiesWithGroup(groups.all.entities, groups[queryString])    
    end
    
    return self._entityGroups[queryString].entities
end

--------------------------------------------------------------------------------
-- Returns the first entity that satisfies the given query.
-- @param queryString A whitespace-separated string of component names.
-- @return            The first entity that satisfies the query or nil if no 
--                    entity is found.
--------------------------------------------------------------------------------
function class:queryFirst(queryString)
    return next(self:query(queryString))
end

--------------------------------------------------------------------------------
-- Call each active update system.
-- @param dt The delta time of the game loop.
--------------------------------------------------------------------------------
function class:update(dt)
    for _, system in pairs(self._updateSystems) do
        if system.isActive then
            system:update(dt)
        end
    end
end

--------------------------------------------------------------------------------
-- Constructs a new instance of the entity component system.
-- @return A new instance of the entity component system.
--------------------------------------------------------------------------------
function module.new()
    local self = {}
    
    -- The table of components. The key is the component name and each value
    -- contains a tables of default component properties.
    self._components = {}
    
    -- The table of entity groups. Each group is used as a cache for query 
    -- results. The key is the query that the group belongs to and each value
    -- contains a table of components from the query and a table entities that
    -- satisfy the query. The group named "all" contains all entities.
    self._entityGroups = { all = { components = {}, entities = {} } }
    
    -- The table of render systems. The key is the system name and each value
    -- contains a tables of systems properties.
    self._renderSystems = {}
    
    -- The table of update systems. The key is the system name and each value
    -- contains a tables of systems properties.
    self._updateSystems = {}
    
    return setmetatable(self, { __index = class })
end

return module
