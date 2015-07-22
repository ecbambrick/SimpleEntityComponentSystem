Simple Entity Component System
================================================================================
Simple Entity Component System is a framework for developing games based on entities, components and systems. The concept behind this framework is to separate data (entities, components) from logic (systems) by using generic, composable game objects that only contain data.

For more information on entity component systems, see the following:

* [Understanding Entity Component Systems](http://www.gamedev.net/page/resources/_/technical/game-programming/understanding-component-entity-systems-r3013)
* [Entity Systems are the Future of MMORPG Development](http://t-machine.org/index.php/2007/09/03/entity-systems-are-the-future-of-mmog-development-part-1/)

_note: the following examples use, but are not limited to, [LÖVE](http://www.love2d.org/)._

Importing
--------------------------------------------------------------------------------
The first thing you need to do is import Simple Entity Component System and create a new instance of the game world.

```lua
local Secs = require('secs')
local world = Secs.new() -- or Secs()
```

Components
--------------------------------------------------------------------------------
Components represent the data of your game objects (entities) and do not contain any logic within themselves. An entity is nothing but a table of components and a component is nothing but a table of data. For example, a `position` component could contain the (x,y) co-ordinates of a game object while a `hasInput` component could serve as a flag to signal that the entity is controllable.

Components can be added and removed from entities at any time to modify their behaviour. For example, if the player entity becomes stunned and unable to move, a `stunned` component can be temporarily added to prevent it from being processed by the input system. Similaly, if there was an `enemyAI` component, it could be added to a chest to suddently transform it into an enemy.

Components are added using the `addComponent` function. Each component is comprised of two things:

0. The name (i.e. position, hasInput, keyMapping, etc.)
0. A table of default values.

```lua
world:addComponent("position",  { x = 0, y = 0 })
world:addComponent("rectangle", { width = 10, height = 10 })
world:addComponent("hasInput")
```

Using `position` as an example, if you attach this component to an entity, the entity will get a default (x,y) co-ordinate of (0,0). You can override these defaults when creating an entity, however. 

You may have noticed that `hasInput` does not actually contain any data; that is because it acts as a simple flag.

Entities
--------------------------------------------------------------------------------
Entites act as the game objects. Everything from players to loot to UI elements can be represented as entities. Each entity is simply a table of components.

```lua
local entity = world:addEntity({ 
    -- set a custom width, but keep the default height
    rectangle = { width = 20 }, 
    
    -- keep all the default values
    position = {}               
})
```

Component properties can be accessed directly through the entity.

```lua
-- modify the position component of the entity
entity.position.x = 10
```

Attaching components to an existing entity is done just like attaching components to a newly created entity. Detaching components can be done via the components' names.

```lua
-- attach the rectangle component to the entity
world:attach(entity, { rectangle = { width = 100, height = 100 } })

-- detach the rectangle and position components from the entity
world:detach(entity, "rectange", "position")
```

Systems
--------------------------------------------------------------------------------
Systems are the final and most important piece of the game world. Systems represent individual modules of game logic that query, create, update, and delete entities.

There are two types of systems:

0. Update systems
0. Draw systems

Update systems are in charge of updating the state of the game world and define a callback function `update(dt)`. Likewise, draw systems handle rendering and define a callback function `draw()`. Otherwise, they are normal Lua tables. In addition, each system can optionally define a field called `isActive`. If this field is set to false, the system is not run during the game loop.

Systems are run in the order in which they are added. The one exception to this is that draw systems are always run after all update systems have run.

```lua
-- create a new system
inputSystem = {}

-- set some system-specific values
inputSystem.speed = 100

-- define the update callback
function inputSystem:update(dt)
	for entity in pairs(world:query("hasInput position")) do
        local pos = entity.position
    
        if love.keyboard.isDown("up") then 
            pos.y = pos.y - self.speed * dt
        end
        
        if love.keyboard.isDown("down") then
            pos.y = pos.y + self.speed * dt
        end
        
        if love.keyboard.isDown("left") then
            pos.x = pos.x - self.speed * dt
        end
        
        if love.keyboard.isDown("right") then
            pos.x = pos.x + self.speed * dt
        end
        
        if love.keyboard.isDown("escape") then
            love.event.quit()
        end
	end
end
```

```lua
-- create a new system
renderSystem = {}

-- de-activate the system
renderSystem.isActive = false

-- define the draw callback
function renderSystem:draw()
	for entity in pairs(world:query("position rectangle")) do
		love.graphics.rectangle(
       		"fill",
       		entity.position.x,
       		entity.position.y,
       		entity.rectangle.width,
       		entity.rectangle.height
     	)
   	end
 end
```

Querying
--------------------------------------------------------------------------------
Before a system can modify entities, it needs a way to access them. Systems can query for entities based on the components they have attached.

The syntax for queries is very simple; it's just a space-separated list of component names. For example, the query "position rectangle" will return all entities in the game world that contain both a `position` component and a `rectangle` component. A null query will return all entities.

Each system should query based on the components that it needs to read/write. For example, a rendering system should only query for entities with components related to rendering such as `position`, `colour`, or `sprite`.

```lua
for entity in pairs(world:query("position rectangle")) do
	-- render rectangles
end
```

Queries are cached, so there's no problem querying many times every frame. Cached queries are updated whenever:

* A component is attached/detached
* A new entity is created
* An entity is deleted

Full Example
--------------------------------------------------------------------------------
Here is a complete example of a simple game that allows you to move a small rectangle.

```lua
local Secs = require('secs')
local world = Secs.new()

function love.load()

    -- create the components
    world:addComponent("position",  { x = 0, y = 0 })
    world:addComponent("rectangle", { width = 10, height = 10 })
    world:addComponent("hasInput",  {  })

    -- add an "input" system with an update callback
    -- this system will handle processing user input
    world:addSystem("input", { 
        speed = 100, 
        update = function(self, dt)
            for entity in pairs(world:query("hasInput position")) do
                local pos = entity.position
            
                if love.keyboard.isDown("up") then 
                    pos.y = pos.y - self.speed * dt
                end
                
                if love.keyboard.isDown("down") then
                    pos.y = pos.y + self.speed * dt
                end
                
                if love.keyboard.isDown("left") then
                    pos.x = pos.x - self.speed * dt
                end
                
                if love.keyboard.isDown("right") then
                    pos.x = pos.x + self.speed * dt
                end
                
                if love.keyboard.isDown("escape") then
                    love.event.quit()
                end
            end
        end
    })
    
    -- add a "render" system with a draw callback
    -- this system will handle rendering rectangles
    world:addSystem("render", { 
        draw = function(self)
            for entity in pairs(world:query("position rectangle")) do
                love.graphics.rectangle(
                    "fill",
                    entity.position.x,
                    entity.position.y,
                    entity.rectangle.width,
                    entity.rectangle.height
                )
            end
        end
    })
    
    -- create a player entity at position (100,100)
    local player = world:addEntity({
        position = { x = 100, y = 100 },
        rectangle = {},
        hasInput = {}
    })
    
    -- create a large, generic rectangle entity at position (200,0)
    world:addEntity({
        position = { x = 200 },
        rectangle = { width = 20, height = 30 }
    })
end

function love.update(dt)
    world:update(dt)
end

function love.draw()
    world:draw()
end
```
