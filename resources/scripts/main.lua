-- Disunity Studio
-- by Carl Hewett

local Disunity = {} -- Disunity modules
Disunity.Database = require("lib.Disunity.Database") -- '.' syntax required (like Java modules)
Disunity.TextDrawer = require("lib.Disunity.TextDrawer")

local game = getGame()

local database = nil -- Disunity database
local textDrawer = nil

local resourceManager = game:getResourceManager()
local inputManager = game:getInputManager()
local entityManager = game:getEntityManager()

local gameCamera = entityManager:getGameCamera()

local playerHeight = 1.65 -- In meters

local basicShader = nil
local texturedShader = nil
local shadedShader = nil
local textShader = nil

local hiSpeed = 0.005
local currentHiDirection = Vec3(hiSpeed, hiSpeed*0.7, 25) -- 25 to test ignoring z coord

local spookTime = 0

local colorGoingUpR = true
local colorGoingUpG = true
local colorGoingUpB = true
local colorValue = Vec3(0.2, 0.7, 0.5)

local growing = true

local DEBUG = false
local DEBUG_HEIGHT = 10

function gameInit()
    Utils.logprint("Starting Disunity Studio...")
    
    game:setName("Disunity Studio")
    game:setSize(IVec2(800, 600))
    game:setMaxFramesPerSecond(60)
    game:reCenterMainWindow()
    game:setGraphicsBackgroundColor(Vec3(0, 0.3, 1))
    
    local camera = entityManager:getGameCamera()
    local cameraPhysicsBody = camera:getPhysicsBody()
    camera:setNearClippingDistance(0.05)
    camera:setFarClippingDistance(10000)
    camera:setFieldOfView(90)
    
    cameraPhysicsBody:calculateShapesFromRadius(0.5)
    cameraPhysicsBody:setWorldFriction(9)
    cameraPhysicsBody:setPosition(Vec3(-1, 5, -3))

    local cameraDirection = getDirectionVector(cameraPhysicsBody:getPosition(), Vec3(0,5,-3))
    camera:setDirection(Vec4(cameraDirection.x, cameraDirection.y, cameraDirection.z, 0))

    basicShader = resourceManager:addShader("basic.v.glsl", "basic.f.glsl")
    texturedShader = resourceManager:addShader("textured.v.glsl", "textured.f.glsl")
    shadedShader = resourceManager:addShader("shaded.v.glsl", "shaded.f.glsl")
    text2DShader = resourceManager:addShader("text2D.v.glsl", "text2D.f.glsl")
    text3DShader = resourceManager:addShader("text3D.v.glsl", "text3D.f.glsl")
    
    inputManager:registerKeys({KeyCode.UP, KeyCode.DOWN, KeyCode.LEFT, KeyCode.RIGHT,
        KeyCode.w, KeyCode.a, KeyCode.s, KeyCode.d, KeyCode.SPACE, KeyCode.LSHIFT, KeyCode.LCTRL, KeyCode.e})

    -- Create Disunity database
    database = Disunity.Database.new()

    database.readFromDisk("data.db")
    database.addObjectGeometryGroup("suzanne.obj")
    database.writeToDisk("data.db")

    -- Create text drawer
    resourceManager:addTexture("fonts/DejaVu.dds", TextureType.DDS)
    resourceManager:addTexture("fonts/DejaVuBold.dds", TextureType.DDS)
    resourceManager:addTexture("fonts/DejaVuItalic.dds", TextureType.DDS)
    resourceManager:addTexture("fonts/Purisa.dds", TextureType.DDS)
    resourceManager:addTexture("fonts/RachanaRegular.dds", TextureType.DDS)

    textDrawer = Disunity.TextDrawer.new(text2DShader, resourceManager:findTexture("DejaVu"))

    textDrawer.setAlignment(Disunity.TextDrawer.LeftAligned)
    textDrawer.setColor(Vec3(1.0, 1.0, 1.0))
    textDrawer.setSize(0.07)
    textDrawer.setColor(Vec3(1.0, 0.5, 0.2))
    textDrawer.drawText("Hi there my name is Carl", Vec3(-0.95, 1, 0), Vec3(0, 0, 0), false)

    textDrawer.setSize(0.07)
    textDrawer.setColor(Vec3(1.0, 1.0, 1.0))
    textDrawer.setAlignment(Disunity.TextDrawer.LeftAligned)
    textDrawer.drawText("hi", Vec3(0, 0, 0), Vec3(0, 0, 0), false)

        textDrawer.setColor(Vec3(1.0, 1.0, 1.0))
    textDrawer.setAlignment(Disunity.TextDrawer.RightAligned)
    textDrawer.setSize(1)
    textDrawer.setShader(text3DShader)
    for i=1,3 do
        textDrawer.drawText("Allo! Je m'appel CARLLLLL", Vec3(i*0.5, 0, 0), Vec3(-i*0.2, -90, 0), true)
    end

    textDrawer.setAlignment(Disunity.TextDrawer.CenterAligned)
    textDrawer.setSize(2)
    textDrawer.drawText("spinn", Vec3(1, 2, -2), Vec3(0, -90, 0), true)

    textDrawer.setSize(20)
    textDrawer.setColors(
        Vec3(1, 0, 0),    -- Top left
        Vec3(0, 0, 0),    -- Bottom left
        Vec3(0, 0, 0),    -- Bottom right
        Vec3(1, 0, 0)     -- Top right
    )

    textDrawer.drawText("COLORCOLOR", Vec3(-5, 8, 3), Vec3(0, 180, 0), true)
    textDrawer.setColor(Vec3(1, 1, 1))

    textDrawer.setSize(10)
    textDrawer.drawText("SPOOK", Vec3(-5, 1, 1), Vec3(0, 180, 0), true) -- Will be moved later

    textDrawer.setSize(20)
    textDrawer.drawText("1234", Vec3(2, 8, -3), Vec3(0, -90, 0), true)
    textDrawer.drawText("bounce", Vec3(3, 5, -3), Vec3(0, -90, 0), true)
end

-- Normalized
function getDirectionVector(initialPoint, destinationPoint)
    return Vec3.normalize(Vec3.sub(destinationPoint, initialPoint)) -- I am cool at math
end

-- Uses table.insert()
function addElementsToArray(array, elements)
    for i,v in ipairs(elements) do
        table.insert(array, v)
    end
end

-- Frees ram and vram
function resetWorld()
    skybox = nil
    roomTableObject = nil
    
    for i,v in ipairs(entityManager:getObjects()) do
        entityManager:removeObject(v)
    end

    resourceManager:clearSounds()
    resourceManager:clearObjectGeometryGroups()
    resourceManager:clearTextures()
end

-- Returns the added objects (references)
-- If textureName is false, it will create a basic object
-- isCircular is optional
-- position is optional
function addObjectGeometries(objectGeometryGroupName, isShaded, textureName, physicsBodyType, isCircular, position)
    local objectGeometryGroup = resourceManager:findObjectGeometryGroup(objectGeometryGroupName)
    local newObjects = {}
    
    for i,v in ipairs(objectGeometryGroup:getObjectGeometries()) do
        local object = nil
        local objectIsCircular = false
        
        if(isCircular == true) then
            objectIsCircular = true
        end
        
        if(textureName ~= false) then
            if(isShaded) then
                object = ShadedObject(v, shadedShader, resourceManager:findTexture(textureName), objectIsCircular, physicsBodyType)
            else
                object = TexturedObject(v, texturedShader, resourceManager:findTexture(textureName), objectIsCircular, physicsBodyType)
            end
        else
            object = Object(v, basicShader, objectIsCircular, physicsBodyType)
        end
        
        if(position ~= nil) then
            object:getPhysicsBody():setPosition(position)
        end
        
        entityManager:addObject(object)
        table.insert(newObjects, object)
    end
    
    return newObjects
end

function gameStep()
    local game = getGame()
    
    local camera = entityManager:getGameCamera()
    local objects = entityManager:getObjects()
    
    doControls();
    
    -- HI
    local hiIndex = 2
    local textWidth = #textDrawer.getText(hiIndex) * textDrawer.getTextSize(hiIndex) -
        #textDrawer.getText(hiIndex) * 0.035 -- Adjustment for real texture width
    local textHeight = textDrawer.getTextSize(hiIndex) / Disunity.TextDrawer.TextureCellAspectRatio -
        0.095-- Adjustment for real texture width

    local currentPosition = textDrawer.getTextPosition(hiIndex)
    if(currentPosition.x+textWidth > 1 or currentPosition.x < -1) then
        currentHiDirection = Vec3(
            -currentHiDirection.x,
            currentHiDirection.y,
            currentHiDirection.z)
    end
    if(currentPosition.y > 1 or currentPosition.y-textHeight < -1) then
        currentHiDirection = Vec3(
            currentHiDirection.x,
            -currentHiDirection.y,
            currentHiDirection.z)
    end
    -- Move hi
    textDrawer.setTextPosition(hiIndex, Vec3.add(currentPosition, currentHiDirection))
    -- Rotate hi
    local hiRotation = textDrawer.getTextRotation(hiIndex)
    -- 20 and 10 to test ignoring x and y:
    textDrawer.setTextRotation(hiIndex, Vec3.add(hiRotation, Vec3(20, 10, 0.85)))

    -- Rotate texts
    local rotSpeed = 0.1
    for i=3,textDrawer.getNumberOfTexts()-5 do
        local rotation = textDrawer.getTextRotation(i)
        local multiplier = (i / textDrawer.getNumberOfTexts()) * 1.4 + 0.8
        local ourSpeed = rotSpeed*multiplier

        textDrawer.setTextRotation(i, Vec3(rotation.x+ourSpeed, rotation.y, rotation.z))
    end

    local fastSpinTextIndex = textDrawer.getNumberOfTexts()-4
    local fastSpinRotation = textDrawer.getTextRotation(fastSpinTextIndex)
    textDrawer.setTextRotation(fastSpinTextIndex,
        Vec3(fastSpinRotation.x+10, fastSpinRotation.y, fastSpinRotation.z))

    local font = math.floor(textDrawer.getTextRotation(3).x) % 4

    local newFont = ""
    if(font == 0) then newFont = "DejaVuBold" end
    if(font == 1) then newFont = "DejaVuItalic" end
    if(font == 2) then newFont = "Purisa" end
    if(font == 3) then newFont = "RachanaRegular" end
    if(font == 4) then newFont = "DejaVu" end
    
    -- Fans and shit fonts
    for i=3,textDrawer.getNumberOfTexts()-4 do
        textDrawer.setTextFont(i, resourceManager:findTexture(newFont))
    end

    -- Spook font
    textDrawer.setTextFont(textDrawer.getNumberOfTexts()-2, resourceManager:findTexture(newFont))

    -- Spook move
    -- Original position: -5, 1, 1
    spookTime = spookTime + 0.3
    local movementSize = 0.5
    local spookMoveSpeed = 7
    textDrawer.setTextPosition(textDrawer.getNumberOfTexts()-2, Vec3(
        -5 + movementSize*math.sin(spookTime/100 * spookMoveSpeed * 1.532 + 17),
        1 + movementSize*math.sin(spookTime/100 * spookMoveSpeed * 1.3),
        1 + movementSize*math.sin(spookTime/100 * spookMoveSpeed * 1.9 + 5)
    ))

    -- Big bounce
    local bounceRate = 0.1
    local changeSizeDetector = 0--math.floor(textDrawer.getTextRotation(3).x) % 10
    if(changeSizeDetector == 0) then
        -- Hi size
        textDrawer.changeTextSize(hiIndex, (1+math.abs(math.sin(spookTime/100)))/10)

        -- Top counter
        textDrawer.changeTextString(textDrawer.getNumberOfTexts()-1,
            tostring( math.floor(textDrawer.getTextRotation(3).x) ))
        if(colorValue.r > 1) then colorGoingUpR = false end
        if(colorValue.r < 0) then colorGoingUpR = true end
        if(colorValue.g > 1) then colorGoingUpG = false end
        if(colorValue.g < 0) then colorGoingUpG = true end
        if(colorValue.b > 1) then colorGoingUpB = false end
        if(colorValue.b < 0) then colorGoingUpB = true end
        if(colorGoingUpR) then
            colorValue.r = colorValue.r + 0.002
        else
            colorValue.r = colorValue.r - 0.002
        end
        if(colorGoingUpG) then
            colorValue.g = colorValue.g + 0.011
        else
            colorValue.g = colorValue.g - 0.011
        end
        if(colorGoingUpB) then
            colorValue.b = colorValue.g + 0.007
        else
            colorValue.b = colorValue.b - 0.007
        end
        textDrawer.changeTextColors( textDrawer.getNumberOfTexts()-1,
            colorValue,
            Vec3(1.0, 1.0, 1.0),
            Vec3(1.0, 1.0, 1.0),
            Vec3(1.0, 1.0, 1.0)
        )

        -- BOUNCE
        local index = textDrawer.getNumberOfTexts()
        local text = textDrawer.getText(index)
        local nextSize = 0

        if(text.attribs.size < 0.5) then
            growing = true
        end

        if(text.attribs.size > 20) then
            growing = false
        end

        if(growing) then
            nextSize = text.attribs.size+bounceRate
        else
            nextSize = text.attribs.size-bounceRate
        end

        textDrawer.changeTextSize(index, nextSize)
    end

    -- Debug shapes
    if(DEBUG) then
        camera:getPhysicsBody():renderDebugShapeWithCoord(resourceManager:findShader("basic"), camera, DEBUG_HEIGHT)
        for i,v in ipairs(objects) do
            local physicsBody = v:getPhysicsBody()

            if(physicsBody:getType() ~= PhysicsBodyType.Ignored) then
                physicsBody:renderDebugShapeWithCoord(basicShader, camera, DEBUG_HEIGHT)
            end
        end
    end
end

-- http://www.scs.ryerson.ca/~danziger/mth141/Handouts/Slides/projections.pdf
function projectVec2OnVec2(vector, projectionVector)
    local projected = Vec2.scalarMul(projectionVector, (  Vec2.dot(vector, projectionVector) / Vec2.length(projectionVector)  ))
    return projected
end

function doControls()
    local speed = 3.5
    local angleIncrementation = 0.02
    
    local camera = entityManager:getGameCamera()
    local cameraPhysicsBody = camera:getPhysicsBody()

    -- Movement
    if(inputManager:isKeyPressed(KeyCode.LSHIFT)) then
        speed = speed / 3
    end
    
	if(inputManager:isKeyPressed(KeyCode.UP)) then
		local cameraDirection = camera:getDirection()
		
		 -- Normalize to guarantee that it is the same everywhere
		local velocity = Vec3.scalarMul(Vec3.normalize(Vec3(cameraDirection.x, 0, cameraDirection.z)), speed)
		cameraPhysicsBody:setVelocity(velocity)
	elseif(inputManager:isKeyPressed(KeyCode.DOWN)) then
		local cameraDirection = camera:getDirection()
	
		local velocity = Vec3.scalarMul(Vec3.normalize(Vec3(-cameraDirection.x, 0, -cameraDirection.z)), speed)
		cameraPhysicsBody:setVelocity(velocity)
	end

    if(inputManager:isKeyPressed(KeyCode.LEFT) or inputManager:isKeyPressed(KeyCode.RIGHT)) then
        local sidewaysVelocityAngle = 1.5708
        local sidewaysSpeed = speed
        
        if(forestRunStarted == true) then
            sidewaysSpeed = forestSpeed
        end
        
        if(inputManager:isKeyPressed(KeyCode.LEFT)) then
            sidewaysVelocityAngle = -sidewaysVelocityAngle
        end
        
        local normalizedCameraDirection = Vec4.normalize(camera:getDirection())
        local cameraVelocity = cameraPhysicsBody:getVelocity()
        
        local otherX = (normalizedCameraDirection.x * math.cos(sidewaysVelocityAngle) - normalizedCameraDirection.z * math.sin(sidewaysVelocityAngle)) * sidewaysSpeed
        local otherZ = (normalizedCameraDirection.x * math.sin(sidewaysVelocityAngle) + normalizedCameraDirection.z * math.cos(sidewaysVelocityAngle)) * sidewaysSpeed
        
        -- Get the velocity projection on the camera direction (this lets us keep vertical speed)
        local cameraVelocity2D = Vec2(cameraVelocity.x, cameraVelocity.z)
        local cameraDirection2D = Vec2(normalizedCameraDirection.x, normalizedCameraDirection.z)
        local projected = projectVec2OnVec2(cameraVelocity2D, cameraDirection2D)
        
        local currentVelocity = cameraPhysicsBody:getVelocity()
        
        -- Make sure we don't indefinitely add velocity, so normalize to our speed (only keep direction)
        local newVelocity = Vec3(otherX + projected.x,
                                currentVelocity.y,
                                otherZ + projected.y)
        
        cameraPhysicsBody:setVelocity(newVelocity)
    end
    
    -- View controls
    if(inputManager:isKeyPressed(KeyCode.w)) then
        local cameraDirection = camera:getDirection() -- Here we make sure we have the latest direction
        
        -- Base of the triangle
        local base = math.sqrt((cameraDirection.x * cameraDirection.x) + (cameraDirection.z * cameraDirection.z))
    
        -- http://stackoverflow.com/questions/22818531/how-to-rotate-2d-vector
        local newBase = base * math.cos(angleIncrementation) - cameraDirection.y * math.sin(angleIncrementation)
        local newY = base * math.sin(angleIncrementation) + cameraDirection.y * math.cos(angleIncrementation)
        
        local ratio = newBase / base
        
        camera:setDirection(Vec4(cameraDirection.x * ratio, newY, cameraDirection.z * ratio, 0)) -- 0 for vector
    elseif(inputManager:isKeyPressed(KeyCode.s)) then
        local cameraDirection = camera:getDirection()
        
        -- Base of the triangle
        local base = math.sqrt((cameraDirection.x * cameraDirection.x) + (cameraDirection.z * cameraDirection.z))
    
        local newBase = base * math.cos(-angleIncrementation) - cameraDirection.y * math.sin(-angleIncrementation)
        local newY = base * math.sin(-angleIncrementation) + cameraDirection.y * math.cos(-angleIncrementation)
        
        local ratio = newBase / base
        
        camera:setDirection(Vec4(cameraDirection.x * ratio, newY, cameraDirection.z * ratio, 0)) -- 0 for vector
    end
    
    -- These are weird when we are pointing completely downwards and are far away?
    if(inputManager:isKeyPressed(KeyCode.a)) then
        local cameraDirection = camera:getDirection()
        
        local newX = cameraDirection.x * math.cos(-angleIncrementation) - cameraDirection.z * math.sin(-angleIncrementation)
        local newZ = cameraDirection.x * math.sin(-angleIncrementation) + cameraDirection.z * math.cos(-angleIncrementation)
        
        if(forestRunStarted == true) then
            -- Make the x/z on the right plane (-z in our case)
            local angleInRadians = (math.pi*-45)/180 -- Cause Lua cos/sin
            local weirdX = newX * math.cos(angleInRadians) - newZ * math.sin(angleInRadians)
            local weirdZ = newX * math.sin(angleInRadians) + newZ * math.cos(angleInRadians)
            
            if(weirdZ~=0 and (weirdX/weirdZ) >0.01) then -- Ignore if X too close to Y, too small of an angle
                camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
            end
        else
            camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
        end
    elseif(inputManager:isKeyPressed(KeyCode.d)) then
        local cameraDirection = Vec3.fromVec4(camera:getDirection())
        
        local newX = cameraDirection.x * math.cos(angleIncrementation) - cameraDirection.z * math.sin(angleIncrementation)
        local newZ = cameraDirection.x * math.sin(angleIncrementation) + cameraDirection.z * math.cos(angleIncrementation)
        
        if(forestRunStarted == true) then
            -- Make the x/z on the right plane (-z in our case)
            local angleInRadians = (math.pi*-45)/180 -- Cause Lua cos/sin
            local weirdX = newX * math.cos(angleInRadians) - newZ * math.sin(angleInRadians)
            local weirdZ = newX * math.sin(angleInRadians) + newZ * math.cos(angleInRadians)
            
            if(weirdZ~=0 and (weirdX/weirdZ) >0.01) then -- Ignore if X too close to Y, too small of an angle
                camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
            end
        else
            camera:setDirection(Vec4(newX, cameraDirection.y, newZ, 0)) -- 0 for vector
        end
    end
    
    -- Up/down controls
    if(inputManager:isKeyPressed(KeyCode.SPACE)) then
        cameraPhysicsBody:setPosition( Vec3.add(cameraPhysicsBody:getPosition(), Vec3(0, speed/30, 0)) )
    elseif(inputManager:isKeyPressed(KeyCode.LCTRL)) then
        cameraPhysicsBody:setPosition( Vec3.add(cameraPhysicsBody:getPosition(), Vec3(0, -speed/30, 0)) )
    end
end

-- 3D
function distanceBetweenPoints(p1, p2)
    return math.pow(distanceSquaredBetweenPoints(p1, p2), 1/3)
end

function distanceSquaredBetweenPoints(p1, p2)
    local deltaX = p2.x - p1.x
    local deltaY = p2.y - p1.y
    local deltaZ = p2.z - p1.z
    
    return (deltaX * deltaX) + (deltaY * deltaY) + (deltaZ * deltaZ)
end

-- Returns the index of the first instance of element, or false if nothing was found
function findInArray(array, element)
    for i,v in ipairs(array) do
        if(v == element) then
            return i
        end
    end
    
    return false
end
