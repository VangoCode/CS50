--[[
    Contains tile data and necessary code for rendering a tile map to the
    screen.
]]

require 'Util'

Map = Class{}

TILE_BRICK = 1
TILE_EMPTY = -1

-- cloud tiles
CLOUD_LEFT = 6
CLOUD_RIGHT = 7

-- bush tiles
BUSH_LEFT = 2
BUSH_RIGHT = 3

-- mushroom tiles
MUSHROOM_TOP = 10
MUSHROOM_BOTTOM = 11

-- jump block
JUMP_BLOCK = 5
JUMP_BLOCK_HIT = 9

-- a speed to multiply delta time to scroll map; smooth value
local SCROLL_SPEED = 62

-- a flag for when you finish the map
local finished = false

-- larger font for drawing the score on the screen
scoreFont = love.graphics.newFont('graphics/font.ttf', 16)
titleFont = love.graphics.newFont('graphics/font.ttf', 32)
instructFont = love.graphics.newFont('graphics/font.ttf', 18)

-- constructor for our map object
function Map:init()

    self.spritesheet = love.graphics.newImage('graphics/spritesheet.png')
    self.flagsheet   = love.graphics.newImage('graphics/flags.png')
    self.sprites = generateQuads(self.spritesheet, 16, 16)
    self.flags   = generateQuads(self.flagsheet, 16, 16)
    self.music = love.audio.newSource('sounds/music.wav', 'static')
    self.victory = love.audio.newSource('sounds/victory.wav', 'static')

    self.tileWidth = 16
    self.tileHeight = 16
    self.mapWidth = 500
    self.mapHeight = 28
    self.tiles = {}

    -- applies positive Y influence on anything affected
    self.gravity = 15

    -- associate player with map
    self.player = Player(self)
    self.slimes = {}
    self.snails = {}

    -- camera offsets
    self.camX = 0
    self.camY = -3

    -- cache width and height of map in pixels
    self.mapWidthPixels = self.mapWidth * self.tileWidth
    self.mapHeightPixels = self.mapHeight * self.tileHeight

    -- first, fill map with empty tiles
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            
            -- support for multiple sheets per tile; storing tiles as tables 
            self:setTile(x, y, TILE_EMPTY)
        end
    end

    -- begin generating the terrain using vertical scan lines
    local slimeCount = 1
    local snailCount = 1
    local x = 1
    -- so you don't spawn on a hole
    while x < 12 do
        for y = self.mapHeight / 2, self.mapHeight do
            self:setTile(x, y, TILE_BRICK)
        end
        x = x + 1
    end
    while x < self.mapWidth - 25 do
        
        -- 2% chance to generate a cloud
        -- make sure we're 2 tiles from edge at least
        if x < self.mapWidth - 2 - 25 then
            if math.random(20) == 1 then
                
                -- choose a random vertical spot above where blocks/pipes generate
                local cloudStart = math.random(self.mapHeight / 2 - 6)

                self:setTile(x, cloudStart, CLOUD_LEFT)
                self:setTile(x + 1, cloudStart, CLOUD_RIGHT)
            end
        end

        -- 5% chance to generate a mushroom
        if math.random(20) == 1 then
            -- left side of pipe
            self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
            self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)

            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- next vertical scan line
            x = x + 1
        
        -- 2% chance to generate a snail area
        -- make sure you have at least 7 blocks space
        elseif math.random(20) == 1 then
            if x < self.mapWidth - 10 - 25 then
                self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
                self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)
                self.snails[snailCount] = Snail(self, (x + 1) * self.tileWidth)
                snailCount = snailCount + 1
                for z = x, x + 9 do
                    for y = self.mapHeight / 2, self.mapHeight do
                        self:setTile(z, y, TILE_BRICK)
                    end
                end
                x = x + 9
                self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
                self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)
                x = x + 1
            end

        -- 10% chance to generate bush, being sure to generate away from edge
        elseif math.random(10) == 1 and x < self.mapWidth - 3 - 25 then
            local bushLevel = self.mapHeight / 2 - 1

            -- place bush component and then column of bricks
            self:setTile(x, bushLevel, BUSH_LEFT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

            self:setTile(x, bushLevel, BUSH_RIGHT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

        -- 10% chance to not generate anything, creating a gap
        elseif math.random(10) ~= 1 then
            
            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- 5% chance to make a enemy
            if math.random(20) == 1 then
                self.slimes[slimeCount] = Slime(self, x * self.tileWidth - self.tileWidth)
                slimeCount = slimeCount + 1
            end

            -- chance to create a block for Mario to hit
            if math.random(15) == 1 then
                self:setTile(x, self.mapHeight / 2 - 4, JUMP_BLOCK)
            end

            -- next vertical scan line
            x = x + 1
        else
            -- increment X so we skip two scanlines, creating a 2-tile gap
            x = x + 2
        end
    end


    -- extra space at the end for finale
    z = x
    while x <= self.mapWidth do
        -- creates a column of tiles going to bottom of map
        for y = self.mapHeight / 2, self.mapHeight do
            self:setTile(x, y, TILE_BRICK)
        end
        x = x + 1
    end
    x = z
    -- 5 pixels of buffer space
    x = x + 5
    -- draw the pyramid
    counter = 0
    while x < z + 12 do
        for y = 1, counter do
            self:setTile(x, self.mapHeight / 2 - y, TILE_BRICK)
        end
        counter = counter + 1
        x = x + 1
    end

    -- start the background music
    self.music:setLooping(true)
    self.music:setVolume(0.25)
    self.music:play()
end

-- return whether a given tile is collidable
function Map:collides(tile)
    -- define our collidable tiles
    local collidables = {
        TILE_BRICK, JUMP_BLOCK, JUMP_BLOCK_HIT,
        MUSHROOM_TOP, MUSHROOM_BOTTOM
    }

    -- iterate and return true if our tile type matches
    for _, v in ipairs(collidables) do
        if tile.id == v then
            return true
        end
    end

    return false
end

-- function to update camera offset with delta time
function Map:update(dt)
    self.player:update(dt)

    -- the if statements so it only tries to draw them if there are actual slimes/snails
    if table.getn(self.slimes) >= 1 then 
        for i = 1, table.getn(self.slimes) do
                self.slimes[i]:update(dt)
        end
    end

    if table.getn(self.snails) >= 1 then
        for i = 1, table.getn(self.snails) do
            self.snails[i]:update(dt)
        end
    end
    
    -- keep camera's X coordinate following the player, preventing camera from
    -- scrolling past 0 to the left and the map's width
    self.camX = math.max(0, math.min(self.player.x - VIRTUAL_WIDTH / 2,
        math.min(self.mapWidthPixels - VIRTUAL_WIDTH, self.player.x)))
end

-- gets the tile type at a given pixel coordinate
function Map:tileAt(x, y)
    return {
        x = math.floor(x / self.tileWidth) + 1,
        y = math.floor(y / self.tileHeight) + 1,
        id = self:getTile(math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1)
    }
end

-- returns an integer value for the tile at a given x-y coordinate
function Map:getTile(x, y)
    return self.tiles[(y - 1) * self.mapWidth + x]
end

-- sets a tile at a given x-y coordinate to an integer value
function Map:setTile(x, y, id)
    self.tiles[(y - 1) * self.mapWidth + x] = id
end


-- renders our map to the screen, to be called by main's render
function Map:render()
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self:getTile(x, y)
            if tile ~= TILE_EMPTY then
                love.graphics.draw(self.spritesheet, self.sprites[tile],
                    (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
            end
        end
    end

    -- x and y coords for the flagpost
    x = self.mapWidth * self.tileWidth - 7 * self.tileWidth
    y = self.mapHeight * self.tileHeight / 2 - 10 * self.tileHeight

    
    -- flag to see when you get to the flag (no pun intended)
    if self.player.x > x - self.player.width / 2 and not finished then
        self.player.state = 'winning'
        finished = true
        self.player.dy = 75
        self.player.x = x - self.player.width / 2
        self.music:stop()
        self.victory:play()
    end


    self:drawEndFlag()

    self.player:render()
    -- self.slime:render()
    -- self.slime2:render()
    for i = 1, table.getn(self.slimes) do
        self.slimes[i]:render()
    end

    for i = 1, table.getn(self.snails) do
        self.snails[i]:render()
    end

    love.graphics.setFont(titleFont)
    love.graphics.printf("Welcome to Mario!", 0, 20, VIRTUAL_WIDTH, 'center')
    love.graphics.setFont(instructFont)
    love.graphics.printf("Use the arrow keys to move, and space to jump", 0, 70, VIRTUAL_WIDTH, 'center')
    love.graphics.printf("There are an infinite number of levels, though you can finish each one", 0, 110, VIRTUAL_WIDTH, 'center')


    love.graphics.setFont(scoreFont)

    love.graphics.print("Score: " .. tostring(self.player.score), self.camX + 6, 6)
end


function Map:drawEndFlag()
    -- draw flags
    while y <= (self.mapHeight * self.tileHeight) / 2 - (3 * self.tileHeight) do
        love.graphics.draw(self.flagsheet, self.flags[12], 
            x, y)
        y = y + self.tileHeight
    end

    -- draw top of flag
    love.graphics.draw(self.flagsheet, self.flags[3], 
            x, self.mapHeight * self.tileHeight / 2 - 11 * self.tileHeight)

    -- draw bottom of flag
    love.graphics.draw(self.flagsheet, self.flags[21], 
            x, self.mapHeight * self.tileHeight / 2 - (2 * self.tileHeight))

    
    x = self.mapWidth * self.tileWidth - 6.3 * self.tileWidth
    -- draw the flag flying
    love.graphics.draw(self.flagsheet, self.flags[7], 
            x, self.mapHeight * self.tileHeight / 2 - 11 * self.tileHeight)
end

function Map:newMap()
    finished = false
    -- first, fill map with empty tiles
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            
            -- support for multiple sheets per tile; storing tiles as tables 
            self:setTile(x, y, TILE_EMPTY)
        end
    end

    -- begin generating the terrain using vertical scan lines
    local slimeCount = 1
    local snailCount = 1
    local x = 1
    -- so you don't spawn on a hole
    while x < 12 do
        for y = self.mapHeight / 2, self.mapHeight do
            self:setTile(x, y, TILE_BRICK)
        end
        x = x + 1
    end
    while x < self.mapWidth - 25 do
        
        -- 2% chance to generate a cloud
        -- make sure we're 2 tiles from edge at least
        if x < self.mapWidth - 2 - 25 then
            if math.random(20) == 1 then
                
                -- choose a random vertical spot above where blocks/pipes generate
                local cloudStart = math.random(self.mapHeight / 2 - 6)

                self:setTile(x, cloudStart, CLOUD_LEFT)
                self:setTile(x + 1, cloudStart, CLOUD_RIGHT)
            end
        end

        -- 5% chance to generate a mushroom
        if math.random(20) == 1 then
            -- left side of pipe
            self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
            self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)

            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- next vertical scan line
            x = x + 1

        -- 2% chance to generate a snail area
        -- make sure you have at least 7 blocks space
        elseif math.random(50) == 1 then
            if x < self.mapWidth - 10 - 25 then
                self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
                self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)
                self.snails[snailCount] = Snail(self, (x + 1) * self.tileWidth)
                snailCount = snailCount + 1
                for z = x, x + 9 do
                    for y = self.mapHeight / 2, self.mapHeight do
                        self:setTile(z, y, TILE_BRICK)
                    end
                end
                x = x + 9
                self:setTile(x, self.mapHeight / 2 - 2, MUSHROOM_TOP)
                self:setTile(x, self.mapHeight / 2 - 1, MUSHROOM_BOTTOM)
            end

        -- 10% chance to generate bush, being sure to generate away from edge
        elseif math.random(10) == 1 and x < self.mapWidth - 3 - 25 then
            local bushLevel = self.mapHeight / 2 - 1

            -- place bush component and then column of bricks
            self:setTile(x, bushLevel, BUSH_LEFT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

            self:setTile(x, bushLevel, BUSH_RIGHT)
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

        -- 10% chance to not generate anything, creating a gap
        elseif math.random(10) ~= 1 then
            
            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- 5% chance to make a enemy
            if math.random(20) == 1 then
                self.slimes[slimeCount] = Slime(self, x * self.tileWidth - self.tileWidth)
                slimeCount = slimeCount + 1
            end

            -- chance to create a block for Mario to hit
            if math.random(15) == 1 then
                self:setTile(x, self.mapHeight / 2 - 4, JUMP_BLOCK)
            end

            -- next vertical scan line
            x = x + 1
        else
            -- increment X so we skip two scanlines, creating a 2-tile gap
            x = x + 2
        end
    end


    -- extra space at the end for finale
    z = x
    while x <= self.mapWidth do
        -- creates a column of tiles going to bottom of map
        for y = self.mapHeight / 2, self.mapHeight do
            self:setTile(x, y, TILE_BRICK)
        end
        x = x + 1
    end
    x = z
    -- 5 pixels of buffer space
    x = x + 5
    -- draw the pyramid
    counter = 0
    while x < z + 12 do
        for y = 1, counter do
            self:setTile(x, self.mapHeight / 2 - y, TILE_BRICK)
        end
        counter = counter + 1
        x = x + 1
    end

    -- start the background music
    self.music:setLooping(true)
    self.music:play()
end