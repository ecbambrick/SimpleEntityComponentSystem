--[[----------------------------------------------------------------------------

    Copyright (C) 2013 by Cole Bambrick
    cole.bambrick@gmail.com

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/.
    
    For documentation, see
    https://github.com/ecbambrick/SimpleEntityComponentSystem/wiki

--]]----------------------------------------------------------------------------

local secs = {}                         -- main container
local updateSystems = {}                -- functions that deal with update logic
local renderSystems = {}                -- functions that deal with render logic
local components = {}                   -- groupings of simple data
local types = {}                        -- catagories based on components
local scenes = { main = { all = {} } }  -- storage for game objects
local currentscene = "main"             -- TODO: implement multiple scenes

--------------------------------------------------- TYPE REGISTRATION (PRIVATE)

--[[
check if an entity meets the component requirements for a type
--]]
local function entityMeetsRequirements(entity, entityType)
    local result = true
    for i,component in ipairs(entityType.components) do
        if entity[component] == nil then
            result = false
            break
        end
    end
    return result
end

--[[
check if the entity doesn't already exist in the list
--]]
local function entityExistsInType(entity, entityType)
    local result = false
    local index = 0
    for i,typeEntity in ipairs(entityType) do
        if typeEntity == entity then
            result = true
            index = k
            break
        end
    end
    return result, index
end

--[[
registers or unregisters an entity with an entity type;
if it meets the requirements and is not already registered, 
the entity is registered, otherwise the entity is unregistered
--]]
local function registerEntity(entity, entityType)
    local meetsRequirements = entityMeetsRequirements(entity, entityType)
    local exists, index = entityExistsInType(entity, entityType)
    
    -- add/remove the entity to/from the type
    if meetsRequirements and not exists then
        table.insert(entityType, entity)
    elseif not meetsRequirements and exists then
        table.remove(entityType, index)
    end
end

--[[
register/unregister an entity for all entity types
--]]
local function updateEntityType(entity)
    for i,entityType in pairs(scenes[currentscene]) do
        if i ~= "all" then
            registerEntity(entity, entityType)
        end
    end
end

--[[
register/unregister all entities for a specific type
--]]
local function updateEntityTypeList(sceneName, entityTypeName)
    local scene = scenes[sceneName]
    local entityType = scene[entityTypeName]
    for i,entity in ipairs(scene.all) do
        registerEntity(entity, entityType)
    end
end

----------------------------------------------------------------------- SYSTEMS

--[[
define a new update system
--]]
function secs.updatesystem(name, priority, callback)
    table.insert(
        updateSystems, 
        { name = name, priority = priority, active = true, update = callback }
    )
    table.sort(
        updateSystems, 
        function(a,b) return a.priority < b.priority end
    )
end

--[[
define a new render system
--]]
function secs.rendersystem(name, priority, callback)
    table.insert(
        renderSystems, 
        { name = name, priority = priority, active = true, update = callback }
    )
    table.sort(
        renderSystems, 
        function(a,b) return a.priority < b.priority end
    )
end

-------------------------------------------------------------------- COMPONENTS

--[[
define a new component constructor
--]]
function secs.component(componentName, componentValues)
	componentValues = componentValues or {}
    components[componentName] = componentValues
end

-------------------------------------------------------------- ENTITY FACTORIES

--[[
define a new entity factory
--]]
function secs.factory(name, callback)
    secs.entity[name] = callback
end

------------------------------------------------------------------ ENTITY TYPES

--[[
define a new entity type
--]]
function secs.type(typeName, ...)
    -- create a type object
    local componentList = {}
    for i,component in ipairs(arg) do
        table.insert(componentList, component)
    end
    
    types[typeName] = componentList
    
    -- register entities for that type in each scene
    for sceneName,scene in pairs(scenes) do
        scene[typeName] = { components = componentList }
        updateEntityTypeList(sceneName, typeName)
    end
end

---------------------------------------------------------------------- ENTITIES

--[[
the table of entity factories;
if the table is called as a function, an empty entity will be created
--]]
secs.entity = { 
    new = function(self, ...)
        local entity = {}
        for i,v in ipairs(arg) do secs.attach(entity, v[1], v[2]) end
        table.insert(scenes[currentscene].all, entity)
        return entity
    end 
}
setmetatable(secs.entity, { __call = secs.entity.new })

--[[
delete an entity from the current scene
--]]
function secs.delete(entity)
    for i in pairs(entity) do secs.detach(entity, i) end
    for i,v in ipairs(scenes[currentscene].all) do
        if v == entity then
            table.remove(scenes[currentscene].all, i)
        end
    end
end

--[[
delete all entities from the current scene
TODO: would it work to just set every scene type to {}?
      alternatively, would setting each type as a weak table work?
--]]
function secs.clear()
    -- remove all components, thus deregistering the entity from each type
    for i,entity in ipairs(scenes[currentscene].all) do
        for componentName in pairs(entity) do 
            secs.detach(entity, componentName)
        end
    end
    scenes[currentscene].all = {}
end

--[[
attach a component to an entity and override the default properties
--]]
function secs.attach(entity, componentName, args)
    entity[componentName] = {}
    if not args then args = {} end
    local defaults = components[componentName]
    local component = entity[componentName]
    for i,v in pairs(defaults) do component[i] = v end
    for i,v in pairs(args)     do component[i] = v end
    updateEntityType(entity)
end

--[[
detach (pop) a component from an entity
--]]
function secs.detach(entity, componentName)
    local component = entity[componentName]
    entity[componentName] = nil
    updateEntityType(entity)
    return component
end

--[[
Return the list of entities of the provided type for the current scene
--]]
function secs.query(entityType)
    if not entityType then entityType = "all" end
    return scenes[currentscene][entityType]
end

------------------------------------------------------------------------ UPDATE

--[[
update all active updateSystems
--]]
function secs.update(dt)
    for i,system in pairs(updateSystems) do
        if system.active then
            system.update(dt)
        end
    end
end

--[[
update all active renderSystems
--]]
function secs.draw()
    for i,system in pairs(renderSystems) do
        if system.active then
            system.update()
        end
    end
end

------------------------------------------------------------------------ RETURN

return secs
