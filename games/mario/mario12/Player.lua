--[[
    Represents our player in the game, with its own sprite.
]]

Player = Class{}

local WALKING_SPEED = 140
local JUMP_VELOCITY = 400

function Player:init(map)
    
    self.score = 0
    self.x = 0
    self.y = 0
    self.width = 16
    self.height = 20

    -- offset from top left to center to support sprite flipping
    self.xOffset = 8
    self.yOffset = 10

    -- reference to map for checking tiles
    self.map = map
    self.texture = love.graphics.newImage('graphics/blue_alien.png')

    -- sound effects
    self.sounds = {
        ['jump']    = love.audio.newSource('sounds/jump.wav', 'static'),
        ['hit']     = love.audio.newSource('sounds/hit.wav', 'static'),
        ['coin']    = love.audio.newSource('sounds/coin.wav', 'static'),
        ['death']   = love.audio.newSource('sounds/death.wav', 'static'),
        ['kill']    = love.audio.newSource('sounds/kill.wav', 'static'),
        ['kill2']    = love.audio.newSource('sounds/kill2.wav', 'static')
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
    self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
    self.x = map.tileWidth * 10

    -- initialize all player animations
    self.animations = {
        ['idle'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(0, 0, 16, 20, self.texture:getDimensions())
            }
        }),
        ['walking'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(128, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(144, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(160, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(144, 0, 16, 20, self.texture:getDimensions()),
            },
            interval = 0.15
        }),
        ['jumping'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(32, 0, 16, 20, self.texture:getDimensions())
            }
        }),
        ['winning'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(0, 0, 16, 20, self.texture:getDimensions())
            }
        })
    }

    -- initialize animation and current frame we should render
    self.animation = self.animations['idle']
    self.currentFrame = self.animation:getCurrentFrame()

    -- behavior map we can call based on player state
    self.behaviors = {
        ['idle'] = function(dt)
            
            -- add spacebar functionality to trigger jump state
            if love.keyboard.wasPressed('space') then
                self.dy = -JUMP_VELOCITY
                self.state = 'jumping'
                self.animation = self.animations['jumping']
                self.sounds['jump']:play()
            elseif love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
                self.state = 'walking'
                self.animations['walking']:restart()
                self.animation = self.animations['walking']
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
                self.state = 'walking'
                self.animations['walking']:restart()
                self.animation = self.animations['walking']
            else
                self.dx = 0
            end

            -- if snail walks into you
            for i = 1, table.getn(self.map.snails) do
                if self.x + self.width + self.dx * dt > self.map.snails[i].x and self.x + self.dx * dt < self.map.snails[i].x + self.map.snails[i].width 
                    and self.y + self.height + self.dy * dt > self.map.snails[i].y and self.y + self.dy * dt < self.map.snails[i].y + self.map.snails[i].height 
                        and not (self.map.snails[i].state == 'death' or self.map.snails[i].state == 'away') then
                        -- position on top of map tiles
                        self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
                        self.x = map.tileWidth * 10
                        self.sounds['death']:play()
                end
            end
        end,
        ['walking'] = function(dt)
            
            -- keep track of input to switch movement while walking, or reset
            -- to idle if we're not moving
            if love.keyboard.wasPressed('space') then
                self.dy = -JUMP_VELOCITY
                self.state = 'jumping'
                self.animation = self.animations['jumping']
                self.sounds['jump']:play()
            elseif love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
            else
                self.dx = 0
                self.state = 'idle'
                self.animation = self.animations['idle']
            end

            -- check for collisions moving left and right
            self:checkRightCollision()
            self:checkLeftCollision()

            -- check for slime collision
            for i = 1, table.getn(self.map.slimes) do
                if self.x + self.width + self.dx * dt > self.map.slimes[i].x and self.x + self.dx * dt < self.map.slimes[i].x + self.map.slimes[i].width 
                    and self.y + self.height + self.dy * dt > self.map.slimes[i].y and self.y + self.dy * dt < self.map.slimes[i].y + self.map.slimes[i].height then
                        -- position on top of map tiles
                        self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
                        self.x = map.tileWidth * 10
                        self.sounds['death']:play()
                end
            end

            -- check for snail collision
            for i = 1, table.getn(self.map.snails) do
                if self.x + self.width + self.dx * dt > self.map.snails[i].x and self.x + self.dx * dt < self.map.snails[i].x + self.map.snails[i].width 
                    and self.y + self.height + self.dy * dt > self.map.snails[i].y and self.y + self.dy * dt < self.map.snails[i].y + self.map.snails[i].height 
                        and not (self.map.snails[i].state == 'death' or self.map.snails[i].state == 'away') then
                        -- position on top of map tiles
                        self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
                        self.x = map.tileWidth * 10
                        self.sounds['death']:play()
                end
            end
            

            -- check if there's a tile directly beneath us
            if not self.map:collides(self.map:tileAt(self.x, self.y + self.height)) and
                not self.map:collides(self.map:tileAt(self.x + self.width - 1, self.y + self.height)) then
                
                -- if so, reset velocity and position and change state
                self.state = 'jumping'
                self.animation = self.animations['jumping']
            end
        end,
        ['jumping'] = function(dt)
            -- break if we go below the surface
            if self.y > 300 then
                return
            end

            if love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
            end

            -- apply map's gravity before y velocity
            self.dy = self.dy + self.map.gravity

            -- check if colliding with slime enemy
            for i = 1, table.getn(self.map.slimes) do
                if self.x + self.width + self.dx * dt > self.map.slimes[i].x and self.x + self.dx * dt < self.map.slimes[i].x + self.map.slimes[i].width 
                    and self.y + self.height + self.dy * dt > self.map.slimes[i].y and self.y + self.dy * dt < self.map.slimes[i].y + self.map.slimes[i].height then
                        -- self.map.slime.y = self.map.mapHeight * self.map.tileHeight
                        self.dy = -JUMP_VELOCITY / 3
                        self.sounds['kill']:play()
                        self.map.slimes[i].state = 'death'
                        self.score = self.score + 1000
                end
            end

            -- check if colliding with snail enemy
            for i = 1, table.getn(self.map.snails) do
                if self.x + self.width + self.dx * dt > self.map.snails[i].x and self.x + self.dx * dt < self.map.snails[i].x + self.map.snails[i].width 
                    and self.y + self.height + self.dy * dt > self.map.snails[i].y and self.y + self.dy * dt < self.map.snails[i].y + self.map.snails[i].height 
                        and not (self.map.snails[i].state == 'death' or self.map.snails[i].state == 'away') then
                        -- self.map.snail.y = self.map.mapHeight * self.map.tileHeight
                        self.dy = -JUMP_VELOCITY / 3
                        self.sounds['kill2']:play()
                        self.map.snails[i].state = 'death'
                        self.score = self.score + 1000
                end
            end

            -- check if there's a tile directly beneath us
            if (self.map:collides(self.map:tileAt(self.x, self.y + self.height)) or
                self.map:collides(self.map:tileAt(self.x + self.width - 1, self.y + self.height))) and self.dy >= 0 then
                
                -- if so, reset velocity and position and change state
                self.dy = 0
                self.state = 'idle'
                self.animation = self.animations['idle']
                self.y = (self.map:tileAt(self.x, self.y + self.height).y - 1) * self.map.tileHeight - self.height
            end

            -- check for collisions moving left and right
            self:checkRightCollision()
            self:checkLeftCollision()
        end,
        ['winning'] = function(dt)
            self.dx = 0
            self.score = self.score + 20000
            -- check if there's a tile directly beneath us
            if (self.map:collides(self.map:tileAt(self.x, self.y + self.height)) or
                self.map:collides(self.map:tileAt(self.x + self.width - 1, self.y + self.height))) and self.dy >= 0 then
                
                -- if so, reset velocity
                self.dy = 0
                self.y = (self.map:tileAt(self.x, self.y + self.height).y - 1) * self.map.tileHeight - self.height
            end
            self.animation = self.animations['winning']

            if self.dy == 0 then
                self.animation = self.animations['walking']
                self.dx = WALKING_SPEED
            end

            if self.x > self.map.mapWidth * self.map.tileWidth then
                self.x = map.tileWidth * 10
                -- generate new map to restart the game
                math.randomseed(os.time())
                self.map:newMap()
                self.state = 'idle'
                self.animation = self.animations['idle']
                self.map.music:play()
            end
        end
    }
end

function Player:update(dt)
    self.behaviors[self.state](dt)
    self.animation:update(dt)
    self.currentFrame = self.animation:getCurrentFrame()
    self.x = self.x + self.dx * dt

    self:calculateJumps()
    self:checkDead()

    -- apply velocity
    self.y = self.y + self.dy * dt
end

-- jumping and block hitting logic
function Player:calculateJumps()
    
    -- if we have negative y velocity (jumping), check if we collide
    -- with any blocks above us
    if self.dy < 0 then

        if self.map:tileAt(self.x, self.y).id ~= TILE_EMPTY or
            self.map:tileAt(self.x + self.width - 1, self.y).id ~= TILE_EMPTY then
            -- reset y velocity
            self.dy = 0

            -- change block to different block
            local playCoin = false
            local playHit = false
            if self.map:tileAt(self.x, self.y).id == JUMP_BLOCK then
                self.map:setTile(math.floor(self.x / self.map.tileWidth) + 1,
                    math.floor(self.y / self.map.tileHeight) + 1, JUMP_BLOCK_HIT)
                playCoin = true
            else
                playHit = true
            end
            if self.map:tileAt(self.x + self.width - 1, self.y).id == JUMP_BLOCK then
                self.map:setTile(math.floor((self.x + self.width - 1) / self.map.tileWidth) + 1,
                    math.floor(self.y / self.map.tileHeight) + 1, JUMP_BLOCK_HIT)
                playCoin = true
            else
                playHit = true
            end

            if playCoin then
                self.score = self.score + 100
                self.sounds['coin']:play()
            elseif playHit then
                self.sounds['hit']:play()
            end
        end
    end
end

-- checks two tiles to our left to see if a collision occurred
function Player:checkLeftCollision()
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
function Player:checkRightCollision()
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

function Player:render()
    local scaleX

    -- set negative x scale factor if facing left, which will flip the sprite
    -- when applied
    if self.direction == 'right' then
        scaleX = 1
    else
        scaleX = -1
    end

    -- draw sprite with scale factor and offsets
    love.graphics.draw(self.texture, self.currentFrame, math.floor(self.x + self.xOffset),
        math.floor(self.y + self.yOffset), 0, scaleX, 1, self.xOffset, self.yOffset)

    
end


function Player:checkDead()
    if self.y > self.map.mapHeight * self.map.tileHeight then
        self.sounds['death']:play()
        -- position on top of map tiles
        self.y = map.tileHeight * ((map.mapHeight - 2) / 2) - self.height
        self.x = map.tileWidth * 10
    end
end