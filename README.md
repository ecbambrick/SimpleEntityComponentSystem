Simple Entity Component System
--------------------------------------------------------------------------------
Simple Entity Component System is a framework for developing games based on entities, components and systems. The concept behind this framework is to separate data (entities, components) from logic (systems) by using generic, composable game objects that only contain data.

For full documentation, see the [wiki](https://github.com/ecbambrick/SimpleEntityComponentSystem/wiki).

Hello World
--------------------------------------------------------------------------------
_note: note: the following example uses, but is not limited to, [LÖVE](http://www.love2d.org/)._

```lua
-- main.lua

function love.load()

	-- Initialize a new instance of the framework.
    local Secs = require("secs")
	local secs = Secs()
    
    -- Define components, each with a default set of values. The position
	-- component contains x-y coordinates while the text component contains
	-- a string of text.
    secs:Component("position", { x = 0, y = 0 })
    secs:Component("text",     { text = "" })
   
    -- Define an entity type which can be used for querying. Any entity that
	-- has a position and text component will automatically be part of the
	-- textEntities entity type.
    secs:EntityType("textEntities", "position", "text")
	
	-- Define a new rendering system. System functions are where game logic
	-- is applied on each entity. This systems gets each text entity and draws
	-- its text to the screen at its position.
	secs:RenderSystem("textRendering", function()
        for e in pairs(secs:query("textEntities")) do
            love.graphics.print(e.text.text, e.position.x, e.position.y)
        end 
    end)

    -- Create a new entity (or game object). It will be automatically processed
	-- by any systems that query for its type.
    secs:Entity(
        {"position", { x = 100, y = 100 }},
        {"text",     { text = "Hello World" }}
    )
end

function love.update(dt)
    secs:update(dt)
end

function love.draw()
    secs:draw()
end
```