GhostRecord = {}
GhostRecord.__index = GhostRecord

enableRecording = true

addEvent"onClientMapStarting"
addEvent"onClientPlayerOutOfTime"
addEvent( "onClientPlayerPickUpRacePickup", true )
addEvent( "onClientPlayerRaceWasted", true )
addEvent( "onClientPlayerFinished", true )

local recordEnabled = true
addCommandHandler('recordghost', function()
	recordEnabled = not recordEnabled
end)

addEvent'recordghost'
addEventHandler('recordghost', root, function(b)
	recordEnabled = not not b
end)

function GhostRecord:create( resourceName )
	local result = {
		positionTimer = nil,
		recording = {},
		isRecording = false,
		currentMapName = nil,
		keyStates = {},
		lastPressed = {},
		vehicleType = nil,
		last = {},
		resourceName = resourceName,
	}
	return setmetatable( result, self )
end

function GhostRecord:init()
	self.checkForCountdownEnd_HANDLER = function() self:checkForCountdownEnd() end
	addEventHandler( "onClientRender", g_Root, self.checkForCountdownEnd_HANDLER )
	-- outputDebug( "Waiting for start..." )
end

function GhostRecord:destroy()
	self:stopRecording()
	if self.checkForCountdownEnd_HANDLER then removeEventHandler( "onClientRender", g_Root, self.checkForCountdownEnd_HANDLER ) self.checkForCountdownEnd_HANDLER = nil end
	if self.waitForNewVehicle_HANDLER then removeEventHandler( "onClientRender", g_Root, self.waitForNewVehicle_HANDLER ) self.waitForNewVehicle_HANDLER = nil end
	if self.checkStateChanges_HANDLER then removeEventHandler( "onClientRender", g_Root, self.checkStateChanges_HANDLER ) self.checkStateChanges_HANDLER = nil end
	if self.playerRaceWasted_HANDLER then removeEventHandler( "onClientPlayerRaceWasted", getLocalPlayer(), self.playerRaceWasted_HANDLER ) self.playerRaceWasted_HANDLER = nil end
	if self.playerFinished_HANDLER then removeEventHandler( "onClientPlayerFinished", getLocalPlayer(), self.playerFinished_HANDLER ) self.playerFinished_HANDLER = nil end
	if self.playerPickUpRacePickup_HANDLER then removeEventHandler( "onClientPlayerPickUpRacePickup", getLocalPlayer(), self.playerPickUpRacePickup_HANDLER ) self.playerPickUpRacePickup_HANDLER = nil end
	if self.playerOutOfTime_HANDLER then removeEventHandler( "onClientPlayerOutOfTime", getLocalPlayer(), self.playerOutOfTime_HANDLER ) self.playerOutOfTime_HANDLER = nil end
	if isTimer( self.positionTimer ) then
		killTimer( self.positionTimer )
		self.positionTimer = nil
		self.updateExactPosition_HANDLER = nil
	end
	self = nil
end

function GhostRecord:checkForCountdownEnd()
	local vehicle = getPedOccupiedVehicle( getLocalPlayer() )
	if vehicle then
		local frozen = isElementFrozen( vehicle )
		if not frozen then
			self.currentVehicleType = getElementModel( vehicle )
			local pedModel = getElementModel( getLocalPlayer() )
			local x, y, z = getElementPosition( vehicle )
			local rX, rY, rZ = getElementRotation( vehicle )
			table.insert( self.recording, { ty = "st", m = self.currentVehicleType, p = pedModel, x = x, y = y, z = z, rX = rX, rY = rY, rZ = rZ, t = 0 } )
			if self.checkForCountdownEnd_HANDLER then removeEventHandler( "onClientRender", g_Root, self.checkForCountdownEnd_HANDLER ) self.checkForCountdownEnd_HANDLER = nil end
			self:startRecording()
		end
	end
end

function GhostRecord:waitForNewVehicle()
	local vehicle = getPedOccupiedVehicle( getLocalPlayer() )
	if vehicle then
		local vHealth = getElementHealth( vehicle )
		local pHealth = getElementHealth( getLocalPlayer() )
		local frozen = isElementFrozen( vehicle )
		if vHealth > 99 and pHealth > 99 and not frozen then
			local ticks = getTickCount() - self.startTick
			table.insert( self.recording, { ty = "sp", t = ticks } )
			if self.waitForNewVehicle_HANDLER then removeEventHandler( "onClientRender", g_Root, self.waitForNewVehicle_HANDLER ) self.waitForNewVehicle_HANDLER = nil end
			self:resumeRecording()
		end
	end
end

function GhostRecord:startRecording()
	if not self.isRecording then
		-- outputDebug( "Recording started." )
		self.startTick = getTickCount()
		self:resetKeyStates()
		self.isRecording = true
		self.checkStateChanges_HANDLER = function() self:checkStateChanges() end
		addEventHandler( "onClientRender", g_Root, self.checkStateChanges_HANDLER )
		self.playerRaceWasted_HANDLER = function( ... ) self:playerRaceWasted( ... ) end
		addEventHandler( "onClientPlayerRaceWasted", getLocalPlayer(), self.playerRaceWasted_HANDLER )
		self.playerFinished_HANDLER = function( ... ) self:playerFinished( ... ) end
		addEventHandler( "onClientPlayerFinished", getLocalPlayer(), self.playerFinished_HANDLER )
		self.playerPickUpRacePickup_HANDLER = function( ... ) self:playerPickUpRacePickup( ... ) end
		addEventHandler( "onClientPlayerPickUpRacePickup", getLocalPlayer(), self.playerPickUpRacePickup_HANDLER )
		self.playerOutOfTime_HANDLER = function() self:playerOutOfTime() end
		addEventHandler( "onClientPlayerOutOfTime", getLocalPlayer(), self.playerOutOfTime_HANDLER )
		self.updateExactPosition_HANDLER = function() self:updateExactPosition() end
		self.positionTimer = setTimer( self.updateExactPosition_HANDLER, POSITION_PULSE, 0 )
	end
end

function GhostRecord:pauseRecording()
	if self.isRecording then
		-- outputDebug( "Recording paused." )
		self.isRecording = false
		if self.checkStateChanges_HANDLER then removeEventHandler( "onClientRender", g_Root, self.checkStateChanges_HANDLER ) self.checkStateChanges_HANDLER = nil end
		if isTimer( self.positionTimer ) then
			killTimer( self.positionTimer )
			self.positionTimer = nil
			self.updateExactPosition_HANDLER = nil
		end
		self.waitForNewVehicle_HANDLER = function() self:waitForNewVehicle() end
		addEventHandler( "onClientRender", g_Root, self.waitForNewVehicle_HANDLER )
	end
end

function GhostRecord:resumeRecording()
	if not self.isRecording then
		-- outputDebug( "Recording resumed." )
		self.isRecording = true
		self:resetKeyStates()
		self.checkStateChanges_HANDLER = function() self:checkStateChanges() end
		addEventHandler( "onClientRender", g_Root, self.checkStateChanges_HANDLER )
		self.updateExactPosition_HANDLER = function() self:updateExactPosition() end
		self.positionTimer = setTimer( self.updateExactPosition_HANDLER, POSITION_PULSE, 0 )
	end
end

function GhostRecord:stopRecording()
	if self.isRecording then
		-- outputDebug( "Recording finished." )
		self.isRecording = false
		if self.checkForCountdownEnd_HANDLER then removeEventHandler( "onClientRender", g_Root, self.checkForCountdownEnd_HANDLER ) self.checkForCountdownEnd_HANDLER = nil end
		if self.waitForNewVehicle_HANDLER then removeEventHandler( "onClientRender", g_Root, self.waitForNewVehicle_HANDLER ) self.waitForNewVehicle_HANDLER = nil end
		if self.checkStateChanges_HANDLER then removeEventHandler( "onClientRender", g_Root, self.checkStateChanges_HANDLER ) self.checkStateChanges_HANDLER = nil end
		if self.playerRaceWasted_HANDLER then removeEventHandler( "onClientPlayerRaceWasted", getLocalPlayer(), self.playerRaceWasted_HANDLER ) self.playerRaceWasted_HANDLER = nil end
		if self.playerFinished_HANDLER then removeEventHandler( "onClientPlayerFinished", getLocalPlayer(), self.playerFinished_HANDLER ) self.playerFinished_HANDLER = nil end
		if self.playerPickUpRacePickup_HANDLER then removeEventHandler( "onClientPlayerPickUpRacePickup", getLocalPlayer(), self.playerPickUpRacePickup_HANDLER ) self.playerPickUpRacePickup_HANDLER = nil end
		if self.playerOutOfTime_HANDLER then removeEventHandler( "onClientPlayerOutOfTime", getLocalPlayer(), self.playerOutOfTime_HANDLER ) self.playerOutOfTime_HANDLER = nil end
		if isTimer( self.positionTimer ) then
			killTimer( self.positionTimer )
			self.positionTimer = nil
			self.updateExactPosition_HANDLER = nil
		end
	end
end

function GhostRecord:saveGhost( rank, time )
	if time < globalInfo.bestTime and rank == 1 then
		outputDebug( "Improved ghost time." )
		triggerLatentServerEvent( "onGhostDataReceive", getLocalPlayer(), self.recording, time, getPlayerName( getLocalPlayer() ), self.resourceName )
	end
	
	if time < globalInfo.bestLocalTime then
		local ghost = xmlCreateFile( "ghosts/" .. self.resourceName .. ".ghost", "ghost" )
		if ghost then
			local info = xmlCreateChild( ghost, "i" )
			if info then
				xmlNodeSetAttribute( info, "r", tostring( getPlayerName( getLocalPlayer() ) ) )
				xmlNodeSetAttribute( info, "t", tostring( time ) )
				xmlNodeSetAttribute( info, "timestamp", tostring( getRealTime().timestamp ) )
			end
		
			for _, info in ipairs( self.recording ) do
				local node = xmlCreateChild( ghost, "n" )
				for k, v in pairs( info ) do
					xmlNodeSetAttribute( node, tostring( k ), tostring( v ) )
				end
			end
			xmlSaveFile( ghost )
			xmlUnloadFile( ghost )
			outputDebug( "Improved local ghost time." )
		else
			outputDebug( "Failed to create a ghost file!" )
		end
	end
end

function GhostRecord:checkStateChanges()
	-- Keys
	for _, v in ipairs( keyNames ) do
		local state = getPedControlState(getLocalPlayer(), v)
		if not state and analogNames[v] then
			-- Not a really good implementation, but didn't think if anything else
			state = getAnalogControlState( v ) >= 0.5
		end
		if state ~= self.keyStates[v] then
			local ticks = getTickCount() - self.startTick
			if (state and ticks - (self.lastPressed[v] or 0) >= KEYSPAM_LIMIT) or not state then
				-- Don't record shooting for hydra/hunter/seasparrow/rhino
				local vehicle = getPedOccupiedVehicle( getLocalPlayer() )
				local donotrecord = false
				if isElement( vehicle ) then
					local model = getElementModel( vehicle )
					if (model == 520 or model == 425 or model == 447 or model == 432) and (v == "vehicle_fire" or v == "vehicle_secondary_fire") and state then
						donotrecord = true
					end
				end
			
				if not donotrecord then
					table.insert( self.recording, { ty = "k", k = v, s = state, t = ticks } )
					self.keyStates[v] = state
					-- outputDebug( "Key state change: " .. v .. " = " .. tostring( state ) )
					if state then
						self.lastPressed[v] = ticks
					end
				end
			end
		end
	end
	
	-- Vehicle change
	local vehicle = getPedOccupiedVehicle( getLocalPlayer() )
	if vehicle then
		local vehicleType = getElementModel( vehicle )
		if self.currentVehicleType ~= vehicleType then
			local ticks = getTickCount() - self.startTick
			table.insert( self.recording, { ty = "v", m = vehicleType, t = ticks } )
			-- outputDebug( "Vehicle change: " .. self.currentVehicleType .. " -> " .. vehicleType )
			self.currentVehicleType = vehicleType
		end
	end
end

function GhostRecord:updateExactPosition()
	local vehicle = getPedOccupiedVehicle( getLocalPlayer() )
	if isElement( vehicle ) then
		local x, y, z = getElementPosition( vehicle )
		if self.last.x then
			if math.abs( self.last.x - x ) < 0.1 and math.abs( self.last.y - y ) < 0.1 and math.abs( self.last.z - z ) < 0.1 then
				return
			end
		end
		local rX, rY, rZ = getElementRotation( vehicle )
		local vX, vY, vZ = getElementVelocity( vehicle )
		local lg = getVehicleLandingGearDown( vehicle )
		local health = getElementHealth( vehicle )
		local ticks = getTickCount() - self.startTick
		table.insert( self.recording, { ty = "po", x = x, y = y, z = z, rX = rX, rY = rY, rZ = rZ, vX = vX, vY = vY, vZ = vZ, lg = lg, h = health, t = ticks } )
		self.last = { x = x, y = y, z = z }
		-- outputDebug( "Pos update." )
	end
end

function GhostRecord:playerFinished( rank, time )
	self:saveGhost( rank, time )
	self:stopRecording()
end

function GhostRecord:playerOutOfTime()
	self:stopRecording()
end

function GhostRecord:playerRaceWasted( vehicle )
	self:pauseRecording()
end

function GhostRecord:playerPickUpRacePickup( _, pickupType, model )
	if self.isRecording then
		if pickupType == "nitro" then
			local ticks = getTickCount() - self.startTick
			table.insert( self.recording, { ty = "pi", i = "n", t = ticks } )
			-- outputDebug( "Picked up 'nitro' pickup." )
		elseif pickupType == "repair" then
			local ticks = getTickCount() - self.startTick
			table.insert( self.recording, { ty = "pi", i = "r", t = ticks } )
			-- outputDebug( "Picked up 'repair' pickup." )
		end
	end
end

function GhostRecord:resetKeyStates()
	for _, v in ipairs( keyNames ) do
		self.keyStates[v] = false
	end
end

addEventHandler( "onClientMapStarting", g_Root,
	function ( mapInfo )
		if recording then
			recording:stopRecording()
			recording:destroy()
		end
		
		-- Check if the map is actually a racing map
		if recordEnabled and modes[mapInfo.modename] then
			recording = GhostRecord:create( mapInfo.resname )
			recording:init()
		end
	end
)
