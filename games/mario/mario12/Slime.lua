--[[
    Represents our Slime in the game, with its own sprite.
]]

Slime = Class{}

local WALKING_SPEED = 140
local JUMP_VELOCITY = 400

function Slime:init(map, x)
    
    self.x = 0
    self.y = 0
    self.width = 16
    self.height = 20

    -- offset from top left to center to support sprite flipping
    self.xOffset = 8
    self.yOffset = 10

    -- reference to map for checking tiles
    self.map = map
    self.texture = love.graphics.newImage('graphics/creatures.png')

    -- sound effects
    self.sounds = {
        ['jump']    = love.audio.newSource('sounds/jump.wav', 'static'),
        ['hit']     = love.audio.newSource('sounds/hit.wav', 'static'),
        ['coin']    = love.audio.newSource('sounds/coin.wav', 'static'),
        ['death']   = love.audio.newSource('sounds/death.wav', 'static')
    }

    -- animation frames
    self.frames = {}

    -- current animation frame
    self.currentFrame = nil

    -- used to determine behavior and animations
    self.state = 'idle'

    -- determines sprite flipping
    self.direction = 'left'

    -- x and y velocity
    self.dx = 0
    self.dy = 0

    -- position on top of map tiles
    self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height + 4
    self.x = x --map.tileWidth * math.random(5, 12)

    -- initialize all Slime animations
    self.animations = {
        ['idle'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(0, 16, 16, 20, self.texture:getDimensions())
            }
        }),
        ['death'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(0, 16, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(16, 16, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(32, 16, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(160, 16, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(0, 16, 16, 20, self.texture:getDimensions())
            },
            interval = 0.05
        })
    }

    -- initialize animation and current frame we should render
    self.animation = self.animations['idle']
    self.currentFrame = self.animation:getCurrentFrame()

    -- behavior map we can call based on Slime state
    self.behaviors = {
        ['idle'] = function(dt)
            
        end,
        ['death'] = function(dt)
            self.animation = self.animations['death']
            if self.animation.currentFrame == 3 then
                self.y = self.map.mapHeight * self.map.tileHeight
            end
        end
    }
end

function Slime:update(dt)
    self.behaviors[self.state](dt)
    self.animation:update(dt)
    self.currentFrame = self.animation:getCurrentFrame()
    self.x = self.x + self.dx * dt

    -- apply velocity
    self.y = self.y + self.dy * dt
end


-- checks two tiles to our left to see if a collision occurred
function Slime:checkLeftCollision()
    if self.dx < 0 then
        -- check if there's a tile directly beneath us
        if self.map:collides(self.map:tileAt(self.x - 1, self.y)) or
            self.map:collides(self.map:tileAt(self.x - 1, self.y + self.height - 1)) then
            
            -- if so, reset velocity and position and change state
            self.dx = 0
            self.x = self.map:tileAt(self.x - 1, self.y).x * self.map.tileWidth
        end
    end
end

-- checks two tiles to our right to see if a collision occurred
function Slime:checkRightCollision()
    if self.dx > 0 then
        -- check if there's a tile directly beneath us
        if self.map:collides(self.map:tileAt(self.x + self.width, self.y)) or
            self.map:collides(self.map:tileAt(self.x + self.width, self.y + self.height - 1)) then
            
            -- if so, reset velocity and position and change state
            self.dx = 0
            self.x = (self.map:tileAt(self.x + self.width, self.y).x - 1) * self.map.tileWidth - self.width
        end
    end
end

function Slime:render()
    local scaleX

    -- set negative x scale factor if facing left, which will flip the sprite
    -- when applied
    if self.direction == 'right' then
        scaleX = -1
    else
        scaleX = 1
    end

    -- draw sprite with scale factor and offsets
    love.graphics.draw(self.texture, self.currentFrame, math.floor(self.x + self.xOffset),
        math.floor(self.y + self.yOffset), 0, scaleX, 1, self.xOffset, self.yOffset)
end