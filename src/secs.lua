--[[----------------------------------------------------------------------------

    Copyright (c) 2013, 2014 Cole Bambrick

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
       claim that you wrote the original software. If you use this software
       in a product, an acknowledgment in the product documentation would be
       appreciated but is not required.
    2. Altered source versions must be plainly marked as such, and must not be
       misrepresented as being the original software.
    3. This notice may not be removed or altered from any source distribution.
    
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
registers or unregisters an entity with an entity type;
if it meets the requirements and is not already registered, it is registered,
otherwise the entity is unregistered
--]]
local function registerEntity(entity, entityType)
    local meetsRequirements = entityMeetsRequirements(entity, entityType)
    if meetsRequirements then
        entityType.entities[entity] = true
    else
        entityType.entities[entity] = nil
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
    for entity in pairs(scene.all) do
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
        scene[typeName] = { components = componentList, entities = {} }
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
        scenes[currentscene].all[entity] = true
        return entity
    end 
}
setmetatable(secs.entity, { __call = secs.entity.new })

--[[
delete an entity from the current scene
--]]
function secs.delete(entity)
    for i in pairs(entity) do entity[i] = nil end
    updateEntityType(entity)
    scenes[currentscene].all[entity] = nil
end

--[[
delete all entities from the current scene
TODO: would it work to just set every scene type to {}?
      alternatively, would setting each type as a weak table work?
--]]
function secs.clear()
    -- remove all components, thus deregistering the entity from each type
    for entity in pairs(scenes[currentscene].all) do
        secs.delete(entity)
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
function secs.detach(entity, ...)
    local components = {}
    for i,v in ipairs(arg) do
        table.insert(components, entity[v])
        entity[v] = nil
    end
    updateEntityType(entity)
    return components
end

--[[
Return the list of entities of the provided type for the current scene
--]]
function secs.query(entityType)
    if not entityType then
        return scenes[currentscene].all
    else
        return scenes[currentscene][entityType].entities
    end
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
