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
    entities = {},
    entityFactories = {},
}

local debug = {
    messageLog = {},
    messageLogSize = 25,
    active = false,
	flags = {},
}

---------------------------------------------------------------------- ENTITIES

--[[
Creates an entity factory
--]]
function Core:newFactory(name, generateFunction)
    self.entityFactories[name] = generateFunction
end

--[[
Creates an entity
--]]
function Core:newEntity(components)
    local newEntity = {}
    if components ~= nil and type(components) == "table" then
        for i,c in pairs(components) do
            Core:attachComponent(newEntity, c[1], c[2])
        end
    end
    table.insert(self.entities, newEntity)
    return newEntity
end

--[[
Creates and initializes an entity from a factory
--]]
function Core:newFactoryEntity(name, args)
    return self.entityFactories[name](args)
end

--[[
Delete the entity
--]]
function Core:deleteEntity(e)
    for i,v in pairs(self.updateSystems) do v:unregister(e) end
    for i,v in pairs(self.renderSystems) do v:unregister(e) end
    for i,v in pairs(self.entities) do
        if v == e then self.entities[i] = nil end
    end
    e = nil
end

-------------------------------------------------------------------- COMPONENTS

--[[
Creates a component and registers it with the core system
--]]
function Core:newComponent(name, initVals)
    local newComponent = {
        _default = initVals,
        _init = function(self, e, name, args)
            e[name] = {}
            for i,v in pairs(self._default) do e[name][i] = v end
            for i,v in pairs(args) do e[name][i] = v end
        end,
    }
    self.components[name] = newComponent
end

--[[
Attach single component to entity
--]]
function Core:attachComponent(e, component, args)
    self.components[component]:_init(e, component, args)
    for i,v in pairs(self.updateSystems) do v:register(e) end
    for i,v in pairs(self.renderSystems) do v:register(e) end
end

--[[
Remove a component from the entity
--]]
function Core:removeComponent(e, component)
    for i,v in pairs(self.updateSystems) do v:unregister(e) end
    for i,v in pairs(self.renderSystems) do v:unregister(e) end
    e[component] = nil
end

----------------------------------------------------------------------- SYSTEMS

--[[
Creates a new update system and registers it with the core system
--]]
function Core:newUpdateSystem()
    newSystem = self:newSystem()
    table.insert(self.updateSystems, newSystem)
    return newSystem
end

--[[
Creates a new render system and registers it with the core system
--]]
function Core:newRenderSystem(system)
    newSystem = self:newSystem()
    table.insert(self.renderSystems, newSystem)
    return newSystem
end

function Core:newSystem(system)
    local newSystem = {
    
        -- keeps track of system-related entities
        entityTypes = {},
        entities = {},
        
        -- main update function
        update = function(self, dt) end,
        
        -- automatically register entities with the system based on components
        registerEntityType = function (self, name, components)
            self.entityTypes[name] = components
            self.entities[name] = {}
        end,
        
        -- determine if an entity should be registered based on its type
        register = function(self, e)
            for i1,v1 in pairs(self.entityTypes) do
                local success = true
                for i2,v2 in pairs(v1) do
                    if e[v2] == nil then success = false break end
                end
                if success then table.insert(self.entities[i1], e) end
            end
        end,
        
        -- unregister an entity
        unregister = function(self, e)
            for i1,v1 in pairs(self.entities) do
                for i2,v2 in pairs(v1) do
                    if v2 == e then
                        table.remove(v1, i)
                    end
                end
            end
        end,
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