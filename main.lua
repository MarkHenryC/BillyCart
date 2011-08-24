-----------------------------------------------------------------------
-- main.lua
-----------------------------------------------------------------------

--[[

	 Mark H Carolan 2010
	
	 Demo of rudimentary cart object with powered wheels
	   responding to physics-based terrain.
	
	 Intended for Corona beginners. Demonstrates a few
	 basic ways of handling sidescrolling with physics.
	
	 Illustrates:
	
	   Tracking moving object with "camera".
	   Re-using side-scrolling surfaces.
	   Using piston and motorised pivot joints.
	   Creating physics objects using shape tables.
	   Using Corona's vector lines to illustrate shapes.
	   Creating modular game components in functions.
	   Using timer to call function at a later date.
	   Using Lua closures to pass parameter data to a listener.
	   Handling collisions with specific objects.
	  
	  Also serves as a general introduction to using Lua 
	  	tables and Corona group display objects.
	  
	  NOTE: This doesn't represent best-practice in Lua
	    programming or using the Corona SDK. Hopefully it
	    simply offers some insights into getting started
	    with Corona from my perspective as a relative
	    newcomer to both Lua and Corona. If any of my comments
	    etc. are incorrect, please let me know.
	
--]]

require "physics"
physics.start()

-----------------------------------------------------------------------
-- There appears to be an odd side effect with
-- the (debug) drawing of joints. You can't add
-- joints to a display group, so they appear to break away
-- from the visual object that contains
-- the physics bodies they're attached to.
-- Not a big deal, as it only affects the debug and hybrid
-- drawing of the joints, but a little disconcerting at first.

-- physics.setDrawMode("hybrid")
-----------------------------------------------------------------------

local JUMP_POWER = 7
local CAMERA_OFFSET = 100

local function offset(x, y)
	return x, y - display.contentHeight
end

-----------------------------------------------------------------------
-- Utility function:
-- Create ground shapes and display as lines
-----------------------------------------------------------------------

local function newContour(params)
	local physicsShape = {}
	
	local coords = params.coords
	local bodyType = params.bodyType
	
	local contour = display.newLine(coords[1], coords[2], coords[3], coords[4])
	
	physicsShape[1], physicsShape[2] = offset(coords[1], coords[2])
	physicsShape[3], physicsShape[4] = offset(coords[3], coords[4])
	
	if params.color then
		contour:setColor(params.color[1], params.color[2], params.color[3])
	else
		contour:setColor(255, 0, 0, 255)
	end
	contour.width = 8
	
	for i = 5, #coords, 2 do
		contour:append(coords[i], coords[i+1])
		physicsShape[i], physicsShape[i+1] = offset(coords[i], coords[i+1])
	end

	-----------------------------------------------------
	-- Visuals must be closed by repeating startpoint
	-- but not physics shapes, which will crash simulator.
	-----------------------------------------------------
	
	contour:append(coords[1], coords[2])
	
	physics.addBody(contour, bodyType or "static", 
		{ friction = 1, bounce = 0.0, shape=physicsShape}	)
	
	return contour
end

----------------------------------------------------------------------- 
-- Simple slider for speed control
-----------------------------------------------------------------------

local function newSlider(params)
	local p = params or {}
	local g = display.newGroup()
	
	local back = display.newRect(0, 0, p.width or 120, p.height or 32)
	g:insert(back)
	
	back:setFillColor(0, 0, 200)
	back.strokeWidth = 3
	back:setStrokeColor(128, 128, 128)
	
	local button = display.newRect(0, 0, p.buttonWidth or 32, p.buttonHeight or 34)	
	g:insert(button)
	
	button:setFillColor(0, 200, 0)
	button.strokeWidth = 3	
	button:setStrokeColor(200, 200, 200)
	
	local leftLimit = back.x-back.width/2
	local rightLimit = back.x+back.width/2
	
	button.x = leftLimit
	
	g.x = params.x or 160
	g.y = p.y or 280
	
	button.y = button.y-1
	local currentXReading = leftLimit
	
	local callbackFunc = p.callbackFunc
	local callbackObject = p.callbackObject
	
	button:addEventListener("touch", g)
	
	------------------------------------------------
	-- Nothing much to see here. Just a slider made
	-- with a backing strip and a square button.
	-- the slider is passed an object and a function
	-- to call on that object when the button is moved.
	-- for simplicity, output values are 0.0 to 1.0
	------------------------------------------------
	
	function g:touch(event)
		if event.phase == "began" then
			display.getCurrentStage():setFocus(button)
		elseif event.phase == "moved" then
			local movementX = event.x - event.xStart
			local posX = currentXReading + movementX
			event.target.x = posX 
			if event.target.x < leftLimit then
				event.target.x = leftLimit
			elseif event.target.x > rightLimit then
				event.target.x = rightLimit
			end
			
			local val = event.target.x
		
			-----------------------------
			-- Output value 0.0 .. 1.0
			-----------------------------
			
			callbackFunc(callbackObject, val / back.width) 
		elseif event.phase == "ended" then
			currentXReading = button.x
			display.getCurrentStage():setFocus(nil)
		end
		return true
	end
	
	function g:set(f) -- 0.0 .. 1.0
		button.x = f * button.width
		currentXReading = leftLimit + f * back.width
	end
	
	return g
end

-----------------------------------------------------------------------
-- Utility function:
-- Create a circular polygon
-----------------------------------------------------------------------

local function createNGon(radius, sides)
	local points = {}
	local rad = math.rad(360/sides)
	
	------------------------------------------------
	-- Create anything up to an octagon (the max sides
	-- allowed by Corona in a vector line) based on
	-- radius of an enclosing circle.
	------------------------------------------------
	
	for i = 1, sides do
		local radAngle = rad*(i-1)
		
		local rSin = math.sin(radAngle)
		local rCos = math.cos(radAngle)
				
		points[#points+1] = rSin * radius
		points[#points+1] = rCos * radius
		
	end
	
	------------------------------------------------
	-- For poly lines, define the first and second xy
	-- coords, creating a single line, then add points
	-- from there to create poly line. For closed polygon
	-- simply repeat the first xy coord at the end.
	------------------------------------------------
	
	local poly = display.newLine(points[1], points[2], points[3], points[4])
	for i = 5, #points, 2 do
		poly:append(points[i], points[i+1])
	end 
	
	poly:append(points[1], points[2])
	
	poly:setColor(255, 255, 255)
	poly.width = 2
	
	local g = display.newGroup()
	g:insert(poly)
	display.setDefault("fillColor", 0, 255, 0, 200)
	g:insert(display.newCircle(0, 0, radius+2))
	
	--------------------------------------------
	-- It's necessary to put this into a group.
	-- It seems that the registration point, when
	-- a physics object is attached, is at the start
	-- point of the multi-segment line. Setting
	-- registration point doesn't fix this. Putting
	-- the line into a group does. Also, the wheel is 
	-- just for looks. The wheel could just as easily 
	-- be square, as it's only the physics body that
	-- determines the behaviour.
	----------------------------------------------
	
	return g
end

-----------------------------------------------------------------------
-- Utility function:
-- Create the Billy Cart with a box and 2 circles
-----------------------------------------------------------------------

local function newBillyCart(params)
	local cart = display.newGroup()

	local originX = params.originX or 0
	local originY = params.originY or 0
	
	local body = params.body or display.newRect(0, 0, 102, 20)	
	body:setFillColor(0, 0, 255)		

	-----------------------------------------
	-- Shaped vector wheel (to show rotation)
	-----------------------------------------
	
	display.setDefault("fillColor", 0, 255, 0, 200)
	
	local wheelLowerLeft = createNGon(16, 5)
	local wheelLowerRight = createNGon(16, 5)		
	
	-----------------------------------------
	-- Anchor for shock absorber
	-----------------------------------------
	
	display.setDefault("fillColor", 255, 0, 0, 200)
		
	local shockBaseLeft = display.newRect(0, 0, 14, 14)
	local shockBaseRight = display.newRect(0, 0, 14, 14)	
	
	-----------------------------------------
	-- Shock absorber bar
	-----------------------------------------
	
	display.setDefault("fillColor", 255, 255, 0, 200)
	
	local lowerShockLeft = display.newRect(0, 0, 8, 28)		
	local lowerShockRight = display.newRect(0, 0, 8, 28)	
	
	-----------------------------------------
	-- Get everything in the right place
	-----------------------------------------
	
	function cart:setOrigin(originX, originY)
		body.x = originX
		body.y = originY+10	
		wheelLowerLeft.x = originX-40
		wheelLowerLeft.y = originY+20	
		wheelLowerRight.x = originX+40
		wheelLowerRight.y = originY+20
		shockBaseLeft.x = originX-40
		shockBaseLeft.y = originY+16
		shockBaseRight.x = originX+40
		shockBaseRight.y = originY+16
		lowerShockLeft.x = originX-40
		lowerShockLeft.y = originY+24
		lowerShockRight.x = originX+40		
		lowerShockRight.y = originY+24	
	end
	
	cart:setOrigin(originX, originY)
	
	-----------------------------------------
	-- put all components into single group
	-----------------------------------------
	
	cart:insert(body)
	cart:insert(wheelLowerLeft)
	cart:insert(wheelLowerRight)
	cart:insert(shockBaseLeft)
	cart:insert(shockBaseRight)
	cart:insert(lowerShockLeft)
	cart:insert(lowerShockRight)
	
	-----------------------------------------
	-- Make into physics objects
	-----------------------------------------
	
	physics.addBody(body, {density=0.5, bounce = 0, friction = 0})
	physics.addBody(wheelLowerLeft, {density=0.9, bounce = 0.0, friction = 4.0, radius=16})
	physics.addBody(wheelLowerRight, {density=0.9, bounce = 0.0, friction = 4.0, radius=16})
	physics.addBody(shockBaseLeft, {density=0.05, bounce = 0, friction = 0})
	physics.addBody(shockBaseRight, {density=0.05, bounce = 0, friction = 0})
	physics.addBody(lowerShockLeft, {density=0.02, bounce = 0, friction = 0})
	physics.addBody(lowerShockRight, {density=0.02, bounce = 0, friction = 0})
	
	-----------------------------------------
	-- Create joints to define behaviour
	-----------------------------------------
	
	local shockBaseLeftJoint = physics.newJoint ("weld", body, 
		shockBaseLeft, shockBaseLeft.x, shockBaseLeft.y)
	
	local shockBaseRightJoint = physics.newJoint ("weld", body, 
		shockBaseRight, shockBaseRight.x, shockBaseRight.y)

	local lowerShockLeftJoint = physics.newJoint ("piston", 
		shockBaseLeft, lowerShockLeft, shockBaseLeft.x, shockBaseLeft.y, 0, 10)
		
	local lowerShockRightJoint = physics.newJoint ("piston", 
		shockBaseRight, lowerShockRight, shockBaseRight.x, shockBaseRight.y, 0, 10)
	
	local lowerConnectorLeftJoint = physics.newJoint ("weld", 
		shockBaseLeft, lowerShockLeft, shockBaseLeft.x, shockBaseLeft.y)
		
	local lowerConnectorRightJoint = physics.newJoint ("weld", 
		shockBaseRight, lowerShockRight, shockBaseRight.x, shockBaseRight.y)
				
	local wheelLowerLeftJoint = physics.newJoint ("pivot", 
		lowerShockLeft, wheelLowerLeft, wheelLowerLeft.x, wheelLowerLeft.y)
	
	local wheelLowerRightJoint = physics.newJoint ("pivot", 
		lowerShockRight, wheelLowerRight, wheelLowerRight.x, wheelLowerRight.y)
		
	local wheelConnectorJoint = physics.newJoint("distance", 
		wheelLowerLeft, wheelLowerRight, wheelLowerLeft.x, wheelLowerLeft.y, 
		wheelLowerRight.x, wheelLowerRight.y)
	
	------------------------------------------------
	-- Turn the pivot joints into motors.
	------------------------------------------------
	
	wheelLowerLeftJoint.isMotorEnabled = true
	wheelLowerLeftJoint.motorSpeed = 0
	wheelLowerLeftJoint.maxMotorTorque = 100000

	wheelLowerRightJoint.isMotorEnabled = true
	wheelLowerRightJoint.motorSpeed = 0
	wheelLowerRightJoint.maxMotorTorque = 100000

	------------------------------------------------
	-- Try to stop wild movements. These figures
	-- probably need a lot of tweaking.
	------------------------------------------------
	
	body.angularDamping = 50

	shockBaseLeft.linearDamping = 10
	shockBaseRight.linearDamping = 10
	
	lowerShockLeft.angularDamping = 50
	lowerShockRight.angularDamping = 50

	lowerShockLeft.linearDamping = 50
	lowerShockRight.linearDamping = 50
	
	-----------------------------------------
	-- Set spin of pivot joints to power cart
	-----------------------------------------
	
	function cart:setSpeed(s)
		wheelLowerLeftJoint.motorSpeed = s
		wheelLowerRightJoint.motorSpeed = s
	end

	-----------------------------------------
	-- Jump by puttin upward impulse on wheels
	-----------------------------------------
	
	function cart:lift()
		wheelLowerLeft:applyLinearImpulse(0, -JUMP_POWER, 
		wheelLowerLeft.x, wheelLowerLeft.y)
		wheelLowerRight:applyLinearImpulse(0, -JUMP_POWER, 
		wheelLowerRight.x, wheelLowerRight.y)
	end
	
	-----------------------------------------
	-- Reset after a prang, maintaining x position
	-----------------------------------------
	
	function cart:reset()
		body.rotation = 0
		self:setOrigin(body.x, body.y - 20)
		self:setSpeed(0)
	end

	-----------------------------------------
	-- Change back to normal color after
	-- embarrassed blush from hitting something.
	-- NOTE: 'self' is handled manually because this
	-- is a listener function (no implicit self, as
	-- it's not called by the timer routine with 
	-- the ':' syntax)
	-----------------------------------------
	
	function cart.revert(self)
		body:setFillColor(0, 0, 255)
	end
	
	-----------------------------------------
	-- Handle collision with other objects.
	-- If object is a known type 
	-- (like "b" for boulder) respond accordingly.
	-----------------------------------------
	
	function cart:collision(event)
		if event.phase == "ended" then
			if event.other.id and event.other.id == "b" then
				body:setFillColor(255, 0, 0)
	
				-----------------------------------------
				-- Use Lua closure to pass 'self' to listener.
				-----------------------------------------
				
				local doRevert = function() return self.revert(self) end
				
				-----------------------------------------
				-- Switch off hit status after 2 seconds
				-----------------------------------------
				
				timer.performWithDelay(2000, doRevert)
			end
		end
	end
	
	wheelLowerLeft:addEventListener("collision", cart)
	wheelLowerRight:addEventListener("collision", cart)
	
	-----------------------------------------
	-- Body needs to be accessible from outside
	-----------------------------------------
	
	cart.body = body
	
	return cart
end

-----------------------------------------------------------------------
-- Main game object
-----------------------------------------------------------------------

function newBillyCartGame(params)
	local camera = display.newGroup()
	
	local p = params or {}

	-----------------------------------------
	-- Our home-made, slightly ricketty 
	-- Billy Cart.
	-----------------------------------------
	
	local cart = newBillyCart
	{
		originX = 100,
		originY = 160,

	}		
	
	camera:insert(cart)
	
	-----------------------------------------
	-- Obstacle
	-----------------------------------------
	
	local boulder = display.newCircle(0, 0, 12)
	boulder:setFillColor(255, 255, 0)
	physics.addBody(boulder, {density=0.5, bounce = 0.1, friction = 1.0})
	camera:insert(boulder)
	boulder.x = -display.contentWidth -- drop behind
	boulder.y = 0
	boulder.id = "b" -- for collision detection
	
	-----------------------------------------
	-- Specify function for slider to call
	-----------------------------------------
	
	local function setSpeed(self, amt)
		local speed = amt * 2000
		cart:setSpeed(speed)	
	end

	-----------------------------------------
	-- Create slider control
	-----------------------------------------
	
	local slider = newSlider
	{
		callbackFunc = setSpeed,
		callbackObject = camera,
	}
	
	-----------------------------------------
	-- Slope definition with variable peak
	-----------------------------------------
	
	local function newSlope(peakY)
		local slope = 
		{
			0, 320,
			0, 260,
			200, peakY,
			280, peakY,
			480, 260, 
			480, 320
		}
		return slope
	end
	
	-----------------------------------------
	-- Generate landscape shapes
	-----------------------------------------
	
	local peaks = { 259, 150, 100, 50, 249, 239, 10, 219, 70, 239, 150, 50 }
		
	local lastXPos = 0
	local shapeStartIndex = camera.numChildren+1
	local lastIndex = shapeStartIndex
	local shapeEndIndex = shapeStartIndex + #peaks-1
	
	local panels = {}
	
	local colors = 
	{
		{ 255, 0, 0 },
		{ 0, 0, 255 },
		{ 0, 255, 255 },
		{ 255, 255, 0 },
		{ 0, 255, 0 }
	}
	
	for i = 1, #peaks do
		local ground = newContour
		{
			coords = newSlope(peaks[i]),
			color = colors[i % #colors]
		}
		ground.x = ground.x + (i-1) * 480
		ground.index = i
		lastXPos = ground.x
		camera:insert(ground)
		panels[#panels+1] = ground
	end
	
	-----------------------------------------
	-- Camera tracking.
	-- Offscreen landscape creation.
	-----------------------------------------
	
	function camera:enterFrame(event)	

		-----------------------------------------
		-- Reposition "camera"
		-----------------------------------------
		
		self.x = -cart.body.x + CAMERA_OFFSET
		self.y = -cart.body.y + CAMERA_OFFSET
		
		-----------------------------------------
		-- Reuse physics ground shapes
		-----------------------------------------
		
		if cart.body.x > lastXPos then		
			lastXPos = lastXPos + display.contentWidth
			
			local slope = self[lastIndex]
			slope.x = lastXPos
			lastIndex = lastIndex + 1
			if lastIndex > shapeEndIndex then
				lastIndex = shapeStartIndex
			end
			
		end
		
		-----------------------------------------
		-- Reset if tipped over
		-----------------------------------------
		
		if cart.body.rotation < -135 
			or cart.body.rotation > 135 then
			cart:reset()
			slider:set(0)
		end

		-----------------------------------------
		-- Drop boulder ahead of cart if it's 
		-- offscreen left
		-----------------------------------------
		
		if boulder.x < cart.body.x - display.contentWidth then	
			boulder.x = cart.body.x + display.contentWidth
			boulder.y = 0
		end
		
	end
	
	--------------------------------
	-- Jump
	--------------------------------
	function camera:touch(event)
		if event.phase == "began" then
			cart:lift()
		end
	end
	
	function camera:start()
		Runtime:addEventListener("enterFrame", self)
		Runtime:addEventListener("touch", self)
	end
	
	return camera
end

-----------------------------------------------------------------------
-- Here's where it starts:
-----------------------------------------------------------------------

local game = newBillyCartGame()

game:start()