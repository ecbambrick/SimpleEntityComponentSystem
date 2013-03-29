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

--]]----------------------------------------------------------------------------

local Core = {
    updateSystems = {},
    renderSystems = {},
    components = {},
    entityFactories = {},
    entities = {
        all = {},
    },
}

local debug = {
    messageLog = {},
    messageLogSize = 25,
    active = false,
    flags = {},
}

---------------------------------------------------------------------- ENTITIES

--[[
Create a new entity; if a list of components is provided then attach each one
--]]
function Core:newEntity(components)
    local newEntity = {}
    table.insert(self.entities.all, newEntity)
    if components ~= nil and type(components) == "table" then
        for i,c in pairs(components) do
            Core:attachComponent(newEntity, c[1], c[2])
        end
    end
    return newEntity
end

--[[
Delete an entity and all of its components
--]]
function Core:deleteEntity(e)
	-- delete components
	for i in pairs(e) do e[i] = nil end
	
	-- remove entity from global entity list
	local allEntities = self.entities.all
	for i,entity in ipairs(allEntities) do 
		if entity == e then table.remove(allEntities, i) end
	end
	
	self:updateEntityTypes(e)
	e = nil
end

-------------------------------------------------------------- ENTITY FACTORIES

--[[
Create an entity factory
--]]
function Core:newFactory(name, generateFunction)
    self.entityFactories[name] = generateFunction
end

--[[
Create an entity from a factory
--]]
function Core:newFactoryEntity(name, args)
    return self.entityFactories[name](args)
end

------------------------------------------------------------------ ENTITY TYPES

--[[
Create a new entity type
--]]
function Core:newEntityType(name, components) 
    self.entities[name] = { components = components }
end

--[[
delete an entity type
--]]
function Core:deleteEntityType(name)
	local eType = self.entities[name]
	for i,v in ipairs(eType) do table.remove(eType, i) end
	for i,v in pairs(eType) do eType[i] = nil end
	eType = nil
end

--[[
return a pointer to the list of entities based on the type
--]]
function Core:getEntityList(name)
    if name == nil then return self.entities.all
    else return self.entities[name] end
end

--[[
Check the requirements for each entity type and if the entity meets those
requirements, then add it to that type's entity list
--]]
function Core:updateEntityTypes(e)
    for i1, entityType in pairs(self.entities) do
		if i1 ~= "all" then
	
			local exists = false
			local meetsRequirements = true
			local index = 0
			
			-- check if the entity meets the component requirements
			for i2, component in ipairs(entityType.components) do
				if e[component] == nil then meetsRequirements = false break end
			end
			
			-- check if the entity doesn't already exist in the list
			for i3, typeEntity in ipairs(entityType) do
				if typeEntity == e then exists = true index = i3 end
			end
			
			-- add/remove the entity to/from the type
			if meetsRequirements and not exists then
				table.insert(self.entities[i1], e)
			elseif not meetsRequirements and exists then
				table.remove(self.entities[i1], index)
			end
			
        end
    end
end

-------------------------------------------------------------------- COMPONENTS

--[[
Create a new component with a set of default values
_init function is used to populate an entity's component values
--]]
function Core:newComponent(name, initVals)
    local newComponent = {
        _default = initVals or {},
        _init = function(self, e, name, args)
            e[name] = {}
            for i,v in pairs(self._default) do e[name][i] = v end
            for i,v in pairs(args) do e[name][i] = v end
        end,
    }
    self.components[name] = newComponent
end

--[[
Attach a component to an entity; update entity types
--]]
function Core:attachComponent(e, component, args)
	if args == nil then args = {} end
    self.components[component]:_init(e, component, args)
    self:updateEntityTypes(e)
end

--[[
Remove a component from an entity; update entity types
--]]
function Core:removeComponent(e, component)
    e[component] = nil
    self:updateEntityTypes(e)
end


----------------------------------------------------------------------- SYSTEMS

--[[
Create a new update system for LOVE's update step
--]]
function Core:newUpdateSystem()
    newSystem = self:newSystem()
    table.insert(self.updateSystems, newSystem)
    return newSystem
end

--[[
Create a new render system for LOVE's draw step
--]]
function Core:newRenderSystem()
    newSystem = self:newSystem()
    table.insert(self.renderSystems, newSystem)
    return newSystem
end

--[[
Initialize a new system
--]]
function Core:newSystem()
    local newSystem = {
        entityTypes = {},
        entities = {},
        update = function() end,
    }
    return newSystem
end

--[[
Run the update systems
--]]
function Core:update(dt)
    for i,system in pairs(self.updateSystems) do
        system:update(dt)
    end
end

--[[
Run the render systems
--]]
function Core:draw()
    for i,system in pairs(self.renderSystems) do
        system:update()
    end
end

--------------------------------------------------------------------- DEBUGGING

--[[
Return the debugger
--]]
function Core:debugger() return debug end

--[[
Adds the provided message to the message log
If there are more messages than the log size, the oldest message is removed
--]]
function debug:log(message)
    table.insert(self.messageLog, message .. "\n")
    if table.getn(self.messageLog) > self.messageLogSize then
        table.remove(self.messageLog, 1)
    end
end

--[[
Prints the message log to the top left of the screen
--]]
function debug:print()
    love.graphics.print("DEBUG LOG: ("..debug.fps.."FPS)", 10, 10)
    for i,v in pairs(self.messageLog) do
        love.graphics.print(v, 10, 10 + (i)*12 )
    end
end

--[[
Checks whether a flag is true and also if the debugger is on
--]]
function debug:flagged(flag)
    if self.flags[flag] ~= nil then return true
    else return false end
end

--[[
Turn debugger on and off
--]]
function debug:activate() self.active = true end
function debug:deactivate() self.active = false end
function debug:toggle() self.active = not self.active end

return Core
