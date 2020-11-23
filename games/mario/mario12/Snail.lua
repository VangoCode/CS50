--[[
    Represents our Snail in the game, with its own sprite.
]]

Snail = Class{}

local WALKING_SPEED = 60
local JUMP_VELOCITY = 400

function Snail:init(map, x)
    
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
    self.state = 'walking'

    -- determines sprite flipping
    self.direction = 'right'

    -- x and y velocity
    self.dx = 0
    self.dy = 0

    self.finished = false

    -- position on top of map tiles
    self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
    self.x = x --map.tileWidth * math.random(5, 12)

    -- initialize all Snail animations
    self.animations = {
        ['walking'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(64, 96, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(80, 96, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(0,  0,  0,  0,  self.texture:getDimensions())
            },
            interval = 0.4
        }),
        ['death'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(64, 96, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(80, 96, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(96, 96, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(112, 96, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(0, 16, 16, 20, self.texture:getDimensions())
            },
            interval = 0.1
        }),
        ['away'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(112, 96, 16, 20, self.texture:getDimensions())
            }
        })
    }

    -- initialize animation and current frame we should render
    self.animation = self.animations['walking']
    self.currentFrame = self.animation:getCurrentFrame()

    -- behavior map we can call based on Snail state
    self.behaviors = {
        ['walking'] = function(dt)

            if self.direction == 'left' then
                self.dx = -WALKING_SPEED
            elseif self.direction == 'right' then
                self.dx = WALKING_SPEED
            end
            -- check for collisions moving left and right
            self:checkRightCollision()
            self:checkLeftCollision()

            -- check if there's a tile directly beneath us
            if not self.map:collides(self.map:tileAt(self.x, self.y + self.height)) and
                not self.map:collides(self.map:tileAt(self.x + self.width - 1, self.y + self.height)) then
                
                -- if so, reset velocity and position and change state
                self.state = 'jumping'
                self.animation = self.animations['jumping']
            end
        end,
        ['death'] = function(dt)
            self.animation = self.animations['death']
            if self.animation.currentFrame == 4 then
              --  self.y = self.map.mapHeight * self.map.tileHeight
                self.state = 'away'
            end
        end,
        ['away'] = function(dt)
            self.animation = self.animations['away']
            if self.y < self.map.mapHeight * self.map.tileHeight then
                if not self.finished then
                    self.dy = -JUMP_VELOCITY / 2
                    self.finished = true
                end
                self.dy = self.dy + JUMP_VELOCITY / 8
            end
        end
    }
end

function Snail:update(dt)
    self.behaviors[self.state](dt)
    self.animation:update(dt)
    self.currentFrame = self.animation:getCurrentFrame()
    self.x = self.x + self.dx * dt

    -- apply velocity
    self.y = self.y + self.dy * dt
end

-- checks two tiles to our left to see if a collision occurred
function Snail:checkLeftCollision()
    if self.dx < 0 then
        -- check if there's a tile directly beneath us
        if self.map:collides(self.map:tileAt(self.x - 1, self.y)) or
            self.map:collides(self.map:tileAt(self.x - 1, self.y + self.height - 1)) then
            
            -- if so, reset velocity and position and change state
            self.dx = 0
            self.x = self.map:tileAt(self.x - 1, self.y).x * self.map.tileWidth
            self.direction = 'right'
        end
    end
end

-- checks two tiles to our right to see if a collision occurred
function Snail:checkRightCollision()
    if self.dx > 0 then
        -- check if there's a tile directly beneath us
        if self.map:collides(self.map:tileAt(self.x + self.width, self.y)) or
            self.map:collides(self.map:tileAt(self.x + self.width, self.y + self.height - 1)) then
            
            -- if so, reset velocity and position and change state
            self.dx = 0
            self.x = (self.map:tileAt(self.x + self.width, self.y).x - 1) * self.map.tileWidth - self.width
            self.direction = 'left'
        end
    end
end

function Snail:render()
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
