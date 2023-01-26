function love.load()
    WINDOW_WIDTH = 1664
    WINDOW_HEIGHT = 1280
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    math.randomseed(os.time())

    anim8 = require "libraries/anim8/anim8"
    sti = require "libraries/Simple-Tiled-Implementation/sti"

    sprites = {}
    sprites.enemies = {}
    sprites.enemies[1] = love.graphics.newImage('sprites/alien-2-sprite-sheet.png')
    sprites.enemies[2] = love.graphics.newImage('sprites/alien-1-sprite-sheet.png')
    sprites.enemies[3] = love.graphics.newImage('sprites/alien-3-sprite-sheet.png')
    sprites.redship = love.graphics.newImage('sprites/redship.png')
    sprites.player = love.graphics.newImage('sprites/cannon.png')
    sprites.bullet = love.graphics.newImage('sprites/bullet-sprite-sheet.png')
    sprites.brick = love.graphics.newImage('sprites/brick.png')
    
    animations = {}
    animations.enemies = {}
    gameFont = love.graphics.newFont("font/press_start/PrStart.ttf", 32)
    bannerFontBig = love.graphics.newFont("font/press_start/PrStart.ttf", 124)
    bannerFontSub = love.graphics.newFont("font/press_start/PrStart.ttf", 72)

    sounds = {}
    sounds.playerBullet = love.audio.newSource("audio/player-bullet.wav", "static")
    sounds.enemyHit = love.audio.newSource("audio/enemyhit.wav", "static")
    sounds.playerHit = love.audio.newSource("audio/playerhit.wav", "static")
    sounds.redship = love.audio.newSource("audio/redship.wav", "static")
    sounds.redship:setLooping(true)
    sounds.redship:setVolume(0.2)

    enemy = {}
    enemy.x = 100
    enemy.y = 200
    enemy.animation = animations.enemies[1]
    enemyDirection = 1

    -- this is to avoid ocassional jitter when changing enemy direction
    enemyDeltaX = 1

    enemies = {}
    redships = {}
    bullets = {}
    enemyBullets = {}

    player = {}
    player.x = 0
    player.y = 0
    player.speed = 500
    bulletJitter = 0.5
    nextBulletIn = -1

    MAX_TIME_ENEMY_BULLET = 2
    maxTimeEnemyBullet = MAX_TIME_ENEMY_BULLET
    enemyBulletTimer = maxTimeEnemyBullet
    maxTimeRedship = 40
    redshipTimer = maxTimeRedship
    score = 0
    bonusScore = 300
    lives = 3

    alientTypes = 3
    enemyScores = {[1] = 40, [2] = 20, [3] = 10}

    bricks = {}

    lowestShelterLine = 1072 + sprites.brick:getWidth() / 2
    maxPlayerLives = 3
    playerStartX = 0
    playerStartY = 0
    enemyOffset = 64
    waveNumber = 1

    gameState = 1
    loadMap()
end

function love.update(dt)

    -- we do not update game elements game state is 1. Game state 1 is the intro screen
    if gameState ~= 2 then
        return
    end

    -- we need to update the game map every frame
    gameMap:update(dt)

    -- here we take care of player movement making sure the player does not move beyond the screen boundaries
    -- For any movement we multuply the object speed with delta time to account for differences in frame rate across
    -- machines. Its pretty much like the basic kinematics formula: speed * delta_time = distance. Here distance is
    -- in pixels.
    if love.keyboard.isDown("left") and player.x - sprites.player:getWidth() / 2 > 0 then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("right") and player.x + sprites.player:getWidth() / 2 < love.graphics.getWidth() then
        player.x = player.x + player.speed * dt
    end

    -- Our aliens travel in a group. Whenever atleast one alien touches the screen boundary, we reverse the direction of movement.
    updateDirection(dt)

    -- Here we take care of the aline movement, taking into consideration the enemyDirection as well which can be one of 1 or -1.
    for i, enemy in pairs(enemies) do
        enemy.animation:update(dt)
        enemy.x = enemy.x + enemy.xspeed * dt * enemyDirection
    end

    for i, redship in pairs(redships) do
        redship.x = redship.x + redship.xspeed * dt
        if redship.x - sprites.redship:getWidth()  / 2 > love.graphics.getWidth() then
            redship.alive = false
        end
        for i, bullet in pairs(bullets) do
            if distanceBetween(bullet.x, bullet.y, redship.x, redship.y) < 40 then
                bullet.destroyed = true
                redship.alive = false
                score = score + bonusScore
                sounds.enemyHit:play()
            end
        end
    end

    for i, eBullet in pairs(enemyBullets) do
        if eBullet then
            eBullet.animation:update(dt)
            eBullet.y = eBullet.y + eBullet.speed * dt

            -- mark bullet for removal if off screen
            if eBullet.y - 16 >= love.graphics.getHeight() then
                eBullet.destroyed = true
            end

            -- check for collision between player and bullet If collision detected then
            -- mark the bullet for removal and kill the player
            if distanceBetween(eBullet.x, eBullet.y, player.x, player.y) < 40 then
                sounds.playerHit:play()
                eBullet.destroyed = true
                killPlayer()
            end
        end
    end

    for i, bullet in pairs(bullets) do
        bullet.animation:update(dt)
        bullet.y = bullet.y - bullet.speed * dt

        -- remove player bullet if off screen
        if bullet.y + 16 <= 0 then
            bullet.destroyed = true
        end
    end

    -- check for enemy killed by player bullen using distance. Same approach as above.
    for i, enemy in pairs(enemies) do
        for j, bullet in pairs(bullets) do
            if distanceBetween(enemy.x, enemy.y, bullet.x, bullet.y) < 40 then
                enemy.alive = false
                bullet.destroyed = true
                score = score + enemyScores[enemy.type]
                sounds.enemyHit:play()
            end
        end

        -- this is a defeat case. If atleast one alien reaches below the baseline of the shelters,
        -- then its game over.
        if enemy.y + 32 > lowestShelterLine then
            sounds.playerHit:play()
            restartGame()
        end
    end

    -- check if bullet collided with any shelter brick, mark both bullet and brick for destruction
    -- if thats the case.
    for i, brick in ipairs(bricks) do
        for i, bullet in ipairs(bullets) do
            if distanceBetween(brick.x, brick.y, bullet.x, bullet.y) < 24 then
                brick.broken = true
                bullet.destroyed = true
            end
        end

        for i, eBullet in ipairs(enemyBullets) do
            if distanceBetween(brick.x, brick.y, eBullet.x, eBullet.y) < 24 then
                brick.broken = true
                eBullet.destroyed = true
            end
        end
    end

    -- remove any enemy that is marked as dead from the table.
    -- Other stale objects are dealt with in the same way.
    for i=#enemies, 1, -1 do
        local enemy = enemies[i]
        if enemy.alive == false then
            table.remove(enemies, i)
        end
    end

    for i=#redships, 1, -1 do
        local redship = redships[i]
        if redship.alive == false then
            table.remove(redships, i)
        end
    end

    if #enemies == 0 then
        newWave()
    end

    for i=#bricks, 1, -1 do
        local brick = bricks[i]
        if brick.broken then
            table.remove(bricks, i)
        end
    end

    for i=#bullets, 1, -1 do
        local bullet = bullets[i]
        if bullet.destroyed then
            table.remove(bullets, i)
        end
    end

    for i=#enemyBullets, 1, -1 do
        local eBullet = enemyBullets[i]
        if eBullet.destroyed == true then
            table.remove(enemyBullets, i)
        end
    end

    -- the aliens fire periodically. The interval starts at 2s then we keep reducing
    -- the interval keeping a lower cap at 1.5s
    enemyBulletTimer = enemyBulletTimer - dt
    if enemyBulletTimer < 0 and gameState == 2 then
        spawnEnemyBullet()
        if maxTimeEnemyBullet > 1.5 then
            maxTimeEnemyBullet = 0.98 * maxTimeEnemyBullet
        else
            maxTimeEnemyBullet = 1.5
        end
        enemyBulletTimer = maxTimeEnemyBullet
    end

    -- this is the timer for bonus redship
    redshipTimer = redshipTimer - dt
    if redshipTimer < 0 and gameState == 2 then
        spawnRedship()
        redshipTimer = maxTimeRedship
    end

    -- we dont want the player to be able to fire a bullet at every keypress. Thats just too
    -- many bullets and it kills the fun. So we have a breathing time between every bullet fire.
    -- If a player presses spacebar rapidly, every hit wont fire a bullet.
    if nextBulletIn >= 0 and gameState == 2 then
        nextBulletIn = nextBulletIn - dt
    end

    -- if there is a redship then we play its signature music.
    if #redships > 0 then
        sounds.redship:play()
    else
        sounds.redship:stop()
    end
end

function spawnRedship()
    local redship = {}
    redship.x = -64
    redship.y = 100
    redship.xspeed = 300
    redship.alive = true
    table.insert(redships, redship)
end

function killPlayer()

    -- Our player is dead. We reduce its lives by 1. If it does not have any lives remaining
    -- then its gameover. If it has got lives then we simply respawn the player at initial location
    lives = lives - 1
    if lives == 0 then
        restartGame()
    else
        player.x = playerStartX
        player.y = playerStartY
    end
end

function restartGame()

    -- the player is defeated somehow, so restart the game which means we re-initialise
    -- all the variables to initial values.
    destroyAll()
    score = 0
    lives = maxPlayerLives
    waveNumber = 1
    loadMap()
    gameState = 1
    maxTimeEnemyBullet = MAX_TIME_ENEMY_BULLET
    enemyBulletTimer = maxTimeEnemyBullet
    redshipTimer = maxTimeRedship
    nextBulletIn = bulletJitter
end

function newWave()

    -- this function creates a new wave of aliens when the player is successful in killing all the aliens.
    -- We keep track of the wave number. Every new wave starts from a y position slightly more (downwards)
    -- than the previous wave.
    waveNumber = waveNumber + 1
    loadEnemies()
end

function love.draw()

    -- If game state is 1 then we paint the intro screen or else we draw the required sprites and
    -- animations on the screen.
    if gameState == 1 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(bannerFontBig)
        love.graphics.printf("SPACE", 0, 150, love.graphics.getWidth(), "center")
        love.graphics.setColor(0, 1, 0)
        love.graphics.setFont(bannerFontSub)
        love.graphics.printf("INVADERS", 0, 280, love.graphics.getWidth(), "center")
        love.graphics.setFont(gameFont)
        love.graphics.setColor(1, 1, 1)
        local baseOffsetY = 500
        alient1 = love.graphics.newQuad(0, 0, 64, 64, sprites.enemies[3]:getWidth(), sprites.enemies[3]:getHeight())
        love.graphics.draw(sprites.enemies[3], alient1, 650, baseOffsetY, nil)
        love.graphics.printf("= 10 PTS ", 80, baseOffsetY + 25, love.graphics.getWidth(), "center")
        alient2 = love.graphics.newQuad(0, 0, 64, 64, sprites.enemies[2]:getWidth(), sprites.enemies[2]:getHeight())
        love.graphics.draw(sprites.enemies[2], alient2, 650, baseOffsetY + 96, nil)
        love.graphics.printf("= 20 PTS ", 80, baseOffsetY + 121, love.graphics.getWidth(), "center")
        alient3 = love.graphics.newQuad(0, 0, 64, 64, sprites.enemies[1]:getWidth(), sprites.enemies[1]:getHeight())
        love.graphics.draw(sprites.enemies[2], alient3, 650, baseOffsetY + 192, nil)
        love.graphics.printf("= 40 PTS ", 80, baseOffsetY + 217, love.graphics.getWidth(), "center")
        love.graphics.printf("HIT SPACEBAR TO START GAME ", 0, baseOffsetY + 417, love.graphics.getWidth(), "center")
        return
    end
    love.graphics.setFont(gameFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SCORE ", 20, 20, love.graphics:getWidth(), "left")
    love.graphics.setColor(0, 1, 0)
    love.graphics.printf(score, 200, 20, love.graphics:getWidth(), "left")
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("LIVES ", 1000, 20, love.graphics:getWidth(), "left")
    love.graphics.setColor(0, 1, 0)
    for i=1, lives, 1 do
        love.graphics.draw(sprites.player, 1150 + i * (sprites.player:getWidth() + 50), 20, nil, nil, nil, sprites.player:getWidth()/2, sprites.player:getHeight()/2)
    end
    for i, brick in ipairs(bricks) do
        love.graphics.draw(sprites.brick, brick.x, brick.y, nil, nil, nil, sprites.brick:getWidth() / 2, sprites.player:getHeight() / 2)
    end
    love.graphics.setColor(1, 1, 1)
    for i, bullet in pairs(bullets) do
        bullet.animation:draw(sprites.bullet, bullet.x, bullet.y, nil, nil, nil, 4, 16)
    end
    for i, eBullet in pairs(enemyBullets) do
        eBullet.animation:draw(sprites.bullet, eBullet.x, eBullet.y, nil, nil, nil, 4, 16)
    end
    for i, enemy in pairs(enemies) do
        enemy.animation:draw(sprites.enemies[enemy.type], enemy.x, enemy.y, nil, nil, nil, 32, 32)
    end
    for i, redship in pairs(redships) do
        love.graphics.draw(sprites.redship, redship.x, redship.y, nil, nil, nil, sprites.redship:getWidth() / 2, sprites.redship:getHeight() / 2)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(sprites.player, player.x, player.y, nil, nil, nil, sprites.player:getWidth()/2, sprites.player:getHeight()/2)


end

function spawnEnemy(x, y, width, height, enemyType)

    -- function to spawn enemy
    if width > 0 and height > 0 then
        local enemy = {}
        enemy.x = x
        enemy.y = y
        enemy.alive = true
        enemy.xspeed = 100
        enemy.yspeed = 700
        enemy.type = enemyType
        local enemyGrid = anim8.newGrid(64, 64, sprites.enemies[enemyType]:getWidth(), sprites.enemies[1]:getHeight())
        enemy.animation = anim8.newAnimation(enemyGrid('1-3', 1), 0.4)
        table.insert(enemies, enemy)
    end
end

function spawnBullet()

    -- function to spawn bullet
    local bullet = {}
    bullet.x = player.x
    bullet.y = player.y
    bullet.speed = 800
    bullet.destroyed = false
    local bulletGrid = anim8.newGrid(8, 32, sprites.bullet:getWidth(), sprites.bullet:getHeight())
    bullet.animation = anim8.newAnimation(bulletGrid('1-3', 1), 0.05)
    table.insert(bullets, bullet)
end

function spawnEnemyBullet()

    -- this function generates an enemy bullet. We dont allow all enemies to fire
    -- bullet. Only the alients in the lower layer/row at any point of time are allowed
    -- to fire. For this we find out the aliens with the highers y position value
    -- for every column and the chose randomly one alien who will fire the bullet.
    if #enemies == 0 then
        return
    end
    local enemyPos = {}
    local enemyXs = {}
    for i, enemy in pairs(enemies) do
        enemyPos[enemy.x] = -1
    end
    for i, enemy in pairs(enemies) do
        if enemy.y > enemyPos[enemy.x] then
            enemyPos[enemy.x] = enemy.y
        end
    end
    for x,y in pairs(enemyPos) do
        table.insert(enemyXs, x)
    end

    local enemyBulletX = enemyXs[math.random(1, #enemyXs)]
    local enemyBulletY = enemyPos[enemyBulletX]

    local enemyBullet = {}
    enemyBullet.x = enemyBulletX
    enemyBullet.y = enemyBulletY
    enemyBullet.speed = 800
    enemyBullet.destroyed = false
    local bulletGrid = anim8.newGrid(8, 32, sprites.bullet:getWidth(), sprites.bullet:getHeight())
    enemyBullet.animation = anim8.newAnimation(bulletGrid('1-3', 1), 0.05)
    table.insert(enemyBullets, enemyBullet)

end


function love.keypressed(key)

    -- function to fire bullet or start the game. If we are on game state 1 and we press
    -- enter then the game is started or else a bullet is fired.
    if key == "space" and gameState == 2 then
        if nextBulletIn < 0 then
           spawnBullet()
           sounds.playerBullet:play()
           nextBulletIn = bulletJitter
        end
    elseif key == "space" and gameState == 1 then
        gameState = 2
    end
end

function loadMap()

    -- function to load our game map.
    gameMap = sti("maps/level1.lua")
    loadEnemies()
    for i, obj in pairs(gameMap.layers["shelters"].objects) do
        spawnBrick(obj.x, obj.y, obj.width, obj.height)
    end
    local playerObj = gameMap.layers["player"].objects[1]

    -- store and set initial position of player
    playerStartX = playerObj.x
    playerStartY = playerObj.y
    player.x = playerObj.x
    player.y = playerObj.y
end

function loadEnemies()
    for i=alientTypes, 1, -1 do
        for j, obj in pairs(gameMap.layers["aliens"..i].objects) do

            -- take into account the wave number to decide the y postition of the enemies. With every new
            -- wave, the starting y position of the aliens should shift a bit down.
            spawnEnemy(obj.x, obj.y + (waveNumber - 1) * enemyOffset, obj.width, obj.height, i)
        end
    end
end

function updateDirection(dt)
    local directionUpdated = false

    -- If atleast one alien hits the screen boundary, we chande the x direction of movement.
    -- The effect we want is the enemy should move as a grouo and change x direction collectively.
    for i, enemy in pairs(enemies) do
        if enemy.x - 32 <= 0 or enemy.x + 32 >= love.graphics.getWidth() then
            enemyDirection = enemyDirection * -1
            directionUpdated = true
            break
        end
    end
    if directionUpdated then
        for i, enemy in ipairs(enemies) do

            -- here we are trying to avoid jitter. When an alien slightly crosses
            -- the screen boundary, we move it slightly away from the boundary.
            if enemy.x - 32 <= 0 then
                enemy.x = 32 + enemyDeltaX
            end
            if enemy.x + 32 >= love.graphics.getWidth() then
                enemy.x = love.graphics.getWidth() - 32 - enemyDeltaX
            end

            -- with x direction change we also shift down the aliens
            enemy.y = enemy.y + enemy.yspeed * dt

            -- and increase the x speed.
            enemy.xspeed = enemy.xspeed * 1.02
        end
    end
end

function spawnBrick(x, y, width, height)
    if width > 0 and height > 0 then
        local brick = {}
        brick.x = x
        brick.y = y
        brick.broken = false
        table.insert(bricks, brick) 
    end
end

function distanceBetween(x1, y1, x2, y2)

    -- good old formula to calculate distance between two points
    -- on a cartesian plane
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2)
end

function destroyAll()

    -- function to clean up all the objects.
    for i=#enemies, 1, -1 do
        table.remove(enemies, i)
    end

    for i=#bullets, 1, -1 do
        table.remove(bullets, i)
    end

    for i=#enemyBullets, 1, -1 do
        table.remove(enemyBullets, i)
    end
    
    for i=#redships, 1, -1 do
        table.remove(redships, i)
    end
end
