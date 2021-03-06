--========= Copyright © 2013-2015, Planimeter, All rights reserved. ==========--
--
-- Purpose: Panel class
--
--============================================================================--

require( "common.color" )

local gui_draw_bounds = convar( "gui_draw_bounds", "0", nil, nil,
                                "Draws the bounds of panels for debugging" )

class( "panel" )

panel.maskedPanel = panel.maskedPanel or nil

function panel.drawMask()
	local self = gui.panel.maskedPanel
	graphics.rectangle( "fill", 0, 0, self:getWidth(), self:getHeight() )
end

function panel:panel( parent, name )
	self.x                 = 0
	self.y                 = 0
	self.width             = 0
	self.height            = 0
	self.name              = name or ""
	self:setParent( parent or g_RootPanel )
	self.zOrder            = -1
	self.visible           = true
	self.markedForDeletion = false
	self.scale             = 1
	self.opacity           = 1
end

local cos = math.cos
local pi  = math.pi

local easing = {
	linear = function( p )
		return p
	end,
	swing = function( p )
		return 0.5 - cos( p * pi ) / 2
	end,
	easeOutQuint = function ( x, t, b, c, d )
		local temp = t / d - 1
		t = t / d - 1
		return c * ( ( temp ) * t * t * t * t + 1 ) + b
	end
}

function panel:animate( properties, duration, easing, complete )
	if ( not self.animations ) then
		self.animations = {}
	end

	local step

	local options = duration
	if ( type( options ) == "table" ) then
		duration = options.duration
		easing   = options.easing
		step     = options.step
		complete = options.complete
	end

	local animation = {
		startTime = nil,
		tweens    = {},
		duration  = duration or 0.4,
		easing    = easing or "swing",
		step      = step,
		complete  = complete
	}

	for member, value in pairs( properties ) do
		animation.tweens[ member ] = {
			startValue = self[ member ],
			endValue   = value,
		}
	end
	table.insert( self.animations, animation )
end

function panel:createFramebuffer()
	if ( self.needsRedraw or self.framebuffer == nil ) then
		local width  = self:getWidth()
		local height = self:getHeight()
		if ( width == 0 or height == 0 ) then
			width  = nil
			height = nil
			if ( not self:shouldSuppressFramebufferWarnings() ) then
				local panel = tostring( self )
				print( "Attempt to create framebuffer for " .. panel ..
				       " with a size of 0!" )
			end
		end
		self.framebuffer = self.framebuffer or
		                 ( self:shouldUseFullscreenFramebuffer() and
		                   graphics.newFullscreenFramebuffer()
		                   or
		                   graphics.newFramebuffer( width, height ) )
		if ( self.framebuffer:shouldAutoRedraw() ) then
			self.framebuffer:setAutoRedraw( false )
		end
		self.framebuffer:clear()
		self.framebuffer:renderTo( function()
			self:draw()
		end )
		self.needsRedraw = nil
	end
end

local opacityStack = { 1 }

function panel:draw()
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:createFramebuffer()
		end
	end

	self:setZOrder()

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			local scale  = v:getScale()
			local width  = v:getWidth()
			local height = v:getHeight()
			graphics.push()
				graphics.translate( v:getX(), v:getY() )
				graphics.scale( scale )
				graphics.translate( ( width  / scale ) / 2 -
				                      width  / 2,
				                    ( height / scale ) / 2 -
				                      height / 2 )
				local opacity = opacityStack[ #opacityStack ]
				opacity       = opacity * v:getOpacity()
				graphics.setOpacity( opacity )
				table.insert( opacityStack, opacity )
					if ( v:isVisible() ) then
						v:drawFramebuffer()
					end

					if ( gui_draw_bounds:getBoolean() ) then
						if ( v:isVisible() and v.mouseover ) then
							v:drawBounds()
						end
					end
				table.remove( opacityStack, #opacityStack )
				graphics.setOpacity( opacityStack[ #opacityStack ] )
				graphics.scale( 1 )
			graphics.pop()
		end
	end
end

function panel:drawBounds()
	graphics.setColor( color.red )
	graphics.rectangle( "line", 0, 0, self:getWidth(), self:getHeight() )
end

function panel:drawFramebuffer()
	if ( not self.framebuffer ) then
		self:createFramebuffer()
	end

	gui.panel.maskedPanel = self
	graphics.setStencil( gui.panel.drawMask )
	graphics.setColor( color.white, true )
	graphics.setBlendMode( "premultiplied" )
		graphics.draw( self.framebuffer:getDrawable() )
	graphics.setBlendMode( "alpha" )
	graphics.setStencil()
end

function panel:getChildren()
	return self.children
end

function panel:getName()
	return self.name
end

function panel:getOpacity()
	return self.opacity
end

function panel:getParent()
	return self.parent
end

function panel:getScale()
	return self.scale
end

local getProperty = scheme.getProperty

function panel:getScheme( property )
	return getProperty( self.scheme, property )
end

function panel:getWidth()
	return self.width
end

function panel:getHeight()
	return self.height
end

function panel:getSize()
	return self:getWidth(), self:getHeight()
end

function panel:getX()
	return self.x
end

function panel:getY()
	return self.y
end

function panel:getPos()
	return self:getX(), self:getY()
end

local sx, sy           = 0, 0
local w,  h            = 0, 0
local pointInRectangle = math.pointInRectangle
local children         = nil
local topChild         = nil

function panel:getTopMostChildAtPos( x, y )
	if ( not self:isVisible() ) then
		return nil
	end

	sx, sy = self:localToScreen( self:getX(), self:getY() )
	w,  h  = self:getWidth(), self:getHeight()
	if ( not pointInRectangle( x, y, sx, sy, w, h ) ) then
		return nil
	end

	children = self:getChildren()
	if ( children ) then
		for i = #children, 1, -1 do
			topChild = children[ i ]:getTopMostChildAtPos( x, y )
			if ( topChild ) then
				return topChild
			end
		end
	end

	return self
end

function panel:invalidate()
	self.needsRedraw = true

	local parent = self:getParent()
	while ( parent ~= nil ) do
		parent:invalidate()
		parent = parent:getParent()
	end
end

function panel:invalidateLayout()
	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:invalidateLayout()
		end
	end

	self:invalidate()
end

function panel:invalidateParent()
	self:getParent():invalidate()
end

function panel:isChildMousedOver()
	local panel = gui.topPanel
	while ( panel ~= nil ) do
		panel = panel:getParent()
		if ( self == panel ) then
			return true
		end
	end

	return false
end

function panel:isTopMostChild()
	local children = self:getChildren()
	if ( children ) then
		return children[ #children ] == self
	else
		return true
	end
end

function panel:isValid()
	return not self.markedForDeletion
end

function panel:isVisible()
	return self.visible
end

function panel:joystickpressed( joystick, button )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:joystickpressed( joystick, button )
		end
	end
end

function panel:joystickreleased( joystick, button )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:joystickreleased( joystick, button )
		end
	end
end

function panel:keypressed( key, isrepeat )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		local filtered
		for i, v in ipairs( self:getChildren() ) do
			filtered = v:keypressed( key, isrepeat )
			if ( filtered ~= nil ) then
				return filtered
			end
		end
	end
end

function panel:keyreleased( key )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:keyreleased( key )
		end
	end
end

local posX, posY = 0, 0
local parent     = nil

function panel:localToScreen( x, y )
	posX, posY = x, y
	parent     = self:getParent()
	while ( parent ~= nil ) do
		posX = posX + parent:getX()
		posY = posY + parent:getY()
		parent = parent:getParent()
	end

	return posX, posY
end

function panel:mousepressed( x, y, button )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:mousepressed( x, y, button )
		end
	end
end

function panel:mousereleased( x, y, button )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:mousereleased( x, y, button )
		end
	end
end

function panel:moveToFront()
	local parent   = self:getParent()
	local children = nil
	if ( parent ) then
		children = parent:getChildren()
		if ( self == children[ #children ] ) then
			return
		end
	end

	if ( gui.focusedPanel ) then
		gui.setFocusedPanel( nil, false )
	end

	if ( parent ) then
		for i, v in ipairs( children ) do
			if ( v == self ) then
				table.remove( children, i )
			end
		end

		children[ #children + 1 ] = self
	end

	if ( self:getParent() ) then
		self:invalidateParent()
	end
end

function panel:moveToBack()
	local parent   = self:getParent()
	local children = nil
	if ( parent ) then
		children = parent:getChildren()
		if ( self == children[ 1 ] ) then
			return
		end
	end

	if ( gui.focusedPanel ) then
		gui.setFocusedPanel( nil, false )
	end

	if ( parent ) then
		for i, v in ipairs( children ) do
			if ( v == self ) then
				table.remove( children, i )
			end
		end

		table.insert( children, 1, self )
	end

	if ( self:getParent() ) then
		self:invalidateParent()
	end
end

function panel:onMouseLeave()
end

function panel:onRemove()
end

function panel:remove()
	if ( self:getChildren() ) then
		self:removeChildren()
	end

	if ( self:getParent() ) then
		local children = self:getParent():getChildren()
		for i, v in ipairs( children ) do
			if ( v == self ) then
				table.remove( children, i )
			end
		end

		if ( #children == 0 ) then
			self:getParent().children = nil
		end
	end

	self.markedForDeletion = true

	self:onRemove()

	table.clear( self )
end

function panel:removeChildren()
	local children = self:getChildren()
	for i = #children, 1, -1 do
		children[ i ]:remove()
	end
end

local root = nil

function panel:screenToLocal( x, y )
	posX, posY = 0, 0
	root       = self
	while ( root:getParent() ~= nil ) do
		posX = posX + root:getX()
		posY = posY + root:getY()
		root = root:getParent()
	end

	x = x - posX
	y = y - posY

	return x, y
end

function panel:setUseFullscreenFramebuffer( useFullscreenFramebuffer )
	self.useFullscreenFramebuffer = useFullscreenFramebuffer and true or nil
end

function panel:setSuppressFramebufferWarnings( suppressFramebufferWarnings )
	self.suppressFramebufferWarnings = suppressFramebufferWarnings
end

function panel:setName( name )
	self.name = name
end

function panel:setNextThink( nextThink )
	self.nextThink = nextThink
end

function panel:setOpacity( opacity )
	self.opacity = opacity
end

function panel:setParent( panel )
	if ( self:getParent() ) then
		local children = self:getParent():getChildren()
		for i, v in ipairs( children ) do
			if ( v == self ) then
				table.remove( children, i )
			end
		end
	end

	panel.children = panel.children or {}
	for i, v in ipairs( panel.children ) do
		if ( v == panel ) then
			return
		end
	end

	table.insert( panel.children, self )
	self.parent = panel
end

function panel:setScale( scale )
	self.scale = scale
end

function panel:setScheme( name )
	if ( not scheme.isLoaded( name ) ) then
		scheme.load( name )
	end
	self.scheme = name
end

function panel:setVisible( visible )
	self.visible = visible
end

function panel:setWidth( width )
	self.width = math.round( width )
	self:invalidate()
end

function panel:setHeight( height )
	self.height = math.round( height )
	self:invalidate()
end

function panel:setSize( width, height )
	self:setWidth( width )
	self:setHeight( height )
end

function panel:setX( x )
	self.x = math.round( x )
	if ( self:getParent() ) then
		self:invalidateParent()
	end
end

function panel:setY( y )
	self.y = math.round( y )
	if ( self:getParent() ) then
		self:invalidateParent()
	end
end

function panel:setPos( x, y )
	self:setX( x )
	self:setY( y )
end

function panel:setZOrder()
	gui.zIteration = gui.zIteration + 1
	self.zOrder    = gui.zIteration
end

function panel:shouldUseFullscreenFramebuffer()
	return self.useFullscreenFramebuffer
end

function panel:shouldSuppressFramebufferWarnings()
	return self.suppressFramebufferWarnings
end

function panel:textinput( text )
	if ( not self:isVisible() ) then
		return
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:textinput( text )
		end
	end
end

function panel:update( dt )
	if ( self.think and
		 self.nextThink and
		 self.nextThink <= engine.getRealTime() ) then
		self.nextThink = nil
		self:think()
	end

	if ( self.animations ) then
		self:updateAnimations( dt )
	end

	if ( self:getChildren() ) then
		for i, v in ipairs( self:getChildren() ) do
			v:update( dt )
		end
	end
end

local startTime  = 0
local duration   = 0
local remaining  = 0
local max        = math.max
local percent    = 0
local startValue = 0
local endValue   = 0
local eased      = 0
local complete   = nil
local len        = table.len

function panel:updateAnimations( dt )
	for _, animation in ipairs( self.animations ) do
		if ( not animation.startTime ) then
			animation.startTime = engine.getRealTime()
		end

		startTime     = animation.startTime
		duration      = animation.duration
		remaining     = max( 0, startTime + duration - engine.getRealTime() )
		percent       = 1 - ( remaining / duration or 0 )
		animation.pos = percent

		for member, tween in pairs( animation.tweens ) do
			startValue = tween.startValue
			endValue   = tween.endValue
			eased      = easing[ animation.easing ](
				percent, duration * percent, 0, 1, duration
			)
			self[ member ] = ( endValue - startValue ) * eased + startValue

			if ( animation.step ) then
				animation.step( self[ member ], tween )
			end

			self:invalidate()
		end

		if ( percent == 1 ) then
			complete = animation.complete
			if ( complete ) then
				complete()
			end
			self:invalidate()
		end
	end

	for i = #self.animations, 1, -1 do
		if ( self.animations[ i ].pos and self.animations[ i ].pos == 1 ) then
			table.remove( self.animations, i )
		end
	end

	if ( len( self.animations ) == 0 ) then
		self.animations = nil
	end
end

function panel:__tostring()
	return "panel: \"" .. self.name .. "\" (" .. self.__type .. ")"
end

gui.register( panel, "panel" )
