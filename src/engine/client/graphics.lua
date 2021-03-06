--========= Copyright © 2013-2015, Planimeter, All rights reserved. ==========--
--
-- Purpose: Graphics interface
--
--============================================================================--

require( "common.color" )

local _INTERACTIVE = _INTERACTIVE

local class    = class
local color    = color
local graphics = love.graphics
local ipairs   = ipairs
local math     = math
local os       = os
local require  = require
local string   = string
local table    = table
local unpack   = unpack
local window   = love.window
local _G       = _G

local r_window_width      = convar( "r_window_width", 800, 800, nil,
                                    "Sets the width of the window on load" )
local r_window_height     = convar( "r_window_height", 600, 600, nil,
                                    "Sets the height of the window on load" )
local r_window_fullscreen = convar( "r_window_fullscreen", "0", nil, nil,
                                    "Toggles fullscreen mode" )
local r_window_borderless = convar( "r_window_borderless", "0", nil, nil,
                                    "Toggles borderless mode" )
local r_window_vsync      = convar( "r_window_vsync", "1", nil, nil,
                                    "Toggles vertical synchronization" )

module( "graphics" )

class( "grid" )

grid.framebuffer = grid.framebuffer or nil

grid.default = {
	backgroundColor = color( 240, 246, 247,                      255 ),
	lines32x32Color	= color(   0,   0,   0, 0.42 * 0.42 * 0.07 * 255 ),
	lines64x64Color	= color(   0,   0,   0, 0.42 * 0.42 * 0.07 * 255 ),
	marks32x32Color = color(   0,   0,   0, 0.42 * 0.66 * 0.07 * 255 ),
	marks64x64Color = color(   0,   0,   0, 0.42 * 0.27 * 0.66 * 255 )
}

grid.dark = {
	backgroundColor = color(  31,  35,  36,                      255 ),
	lines32x32Color = color( 255, 255, 255, 0.42 * 0.42 * 0.07 * 255 ),
	lines64x64Color = color( 255, 255, 255, 0.42 * 0.42 * 0.07 * 255 ),
	marks32x32Color = color( 255, 255, 255, 0.42 * 0.66 * 0.07 * 255 ),
	marks64x64Color = color( 255, 255, 255, 0.42 * 0.27 * 0.66 * 255 )
}

grid.marks = {}

shim  = nil
error = nil

function initialize()
	setBackgroundColor( grid.dark.backgroundColor )
	if ( not graphics.isSupported( "canvas" ) ) then
		shim = newImage( "images/shim.png" )
	end
	error = newImage( "images/error.png" )
	error:setWrap( "repeat", "repeat" )
end

function draw( ... )
	graphics.draw( ... )
end

function drawGrid()
	if ( grid.framebuffer == nil ) then
		grid.framebuffer = newFullscreenFramebuffer()
		grid.framebuffer:renderTo( function()
			setBackgroundColor( grid.dark.backgroundColor )
			graphics.setLineWidth( 1 )
			graphics.setLineStyle( "rough" )
			graphics.setBlendMode( "alpha" )

			-- Grid Lines (32x32)
			setColor( grid.dark.lines32x32Color )
			for i = 0, graphics.getWidth() / 32 do
				line( 32 * i,
				      0,
				      32 * i,
				      graphics.getHeight() )
			end
			for i = 0, graphics.getHeight() / 32 do
				line( 0,
				      32 * i,
				      graphics.getWidth(),
				      32 * i )
			end

			-- Grid Lines (64x64)
			setColor( grid.dark.lines64x64Color )
			for i = 0, graphics.getWidth() / 64 do
				line( 64 * i,
				      0,
				      64 * i,
				      graphics.getHeight() )
			end
			for i = 0, graphics.getHeight() / 64 do
				line( 0,
				      64 * i,
				      graphics.getWidth(), 64 * i )
			end

			-- Grid Marks (32x32)
			setColor( grid.dark.marks32x32Color )
			for x = 0, graphics.getWidth() / 32 do
				for y = 0, graphics.getHeight() / 32 do
					line( 32 * x,     32 * y - 2.5, 32 * x,     32 * y + 2.5 )
					line( 32 * x - 2, 32 * y,       32 * x,     32 * y )
					line( 32 * x + 1, 32 * y,       32 * x + 3, 32 * y )
				end
			end

			-- Grid Marks (64x64)
			-- setColor( grid.dark.marks64x64Color )
			-- for x = 0, graphics.getWidth() / 64 do
			-- 	for y = 0, graphics.getHeight() / 64 do
			-- 		line( 64 * x,     64 * y - 2.5, 64 * x,     64 * y + 2.5 )
			-- 		line( 64 * x - 2, 64 * y,       64 * x,     64 * y )
			-- 		line( 64 * x + 1, 64 * y,       64 * x + 3, 64 * y )
			-- 	end
			-- end
		end )
	end

	setColor( color.white )
	graphics.setBlendMode( "premultiplied" )
		draw( grid.framebuffer:getDrawable() )
	graphics.setBlendMode( "alpha" )

	-- Grid Marks (64x64)
	-- setColor( grid.dark.marks64x64Color )
	for x = 0, graphics.getWidth() / 64 do
		grid.marks[ x ] = grid.marks[ x ] or {}
		for y = 0, graphics.getHeight() / 64 do
			if ( not grid.marks[ x ][ y ] ) then
				grid.marks[ x ][ y ] = {
					twinkling	= false,
					lastTwinkle = _G.engine.getRealTime()
				}
			end

			setColor( grid.marks[ x ][ y ].color or grid.dark.marks64x64Color )
			line( 64 * x,     64 * y - 2.5, 64 * x,     64 * y + 2.5 )
			line( 64 * x - 2, 64 * y,       64 * x,     64 * y )
			line( 64 * x + 1, 64 * y,       64 * x + 3, 64 * y )
		end
	end
end

local markColor    = nil
local alpha        = 0
local gridMark     = nil
local lifetime     = 0
local maxAlpha     = 0
local decay        = 0
local twinkleAlpha = 0
local random       = math.random

function updateGrid()
	local realTime = _G.engine.getRealTime()
	for x = 0, graphics.getWidth() / 64 do
		grid.marks[ x ] = grid.marks[ x ] or {}
		for y = 0, graphics.getHeight() / 64 do
			if ( not grid.marks[ x ][ y ] ) then
				grid.marks[ x ][ y ] = {
					twinkling   = false,
					lastTwinkle = realTime
				}
			end

			markColor    = grid.dark.marks64x64Color
			alpha        = markColor.a
			gridMark     = grid.marks[ x ][ y ]
			lifetime     = realTime - gridMark.lastTwinkle
			maxAlpha     = 0.27
			decay        = math.clamp( lifetime * 0.27, 0, maxAlpha ) / 1
			twinkleAlpha = math.max( alpha, ( maxAlpha - decay ) * 255 )
			if ( gridMark.twinkling ) then
				markColor.a    = twinkleAlpha
				gridMark.color = color.copy( markColor )
				if ( twinkleAlpha == alpha ) then
					gridMark.twinkling = false
				end
				markColor.a = alpha
			elseif ( random( 0, graphics.getWidth()	 / 64 ) == x and
			         random( 0, graphics.getHeight() / 64 ) == y ) then
				gridMark.twinkling	 = true
				gridMark.lastTwinkle = realTime
			end
		end
	end
end

local gcd = math.gcd

function getAspectRatios()
	local modes = getFullscreenModes()
	local r     = 1
	for i, mode in ipairs( modes ) do
		r = gcd( mode.width, mode.height )
		mode.x = mode.width  / r
		mode.y = mode.height / r
		mode.width  = nil
		mode.height = nil
	end
	table.sort( modes, function( a, b )
		return a.x * a.y < b.x * b.y
	end )
	modes = table.unique( modes )
	return modes
end

local r, g, b, a = 0, 0, 0, 0
local _color     = color( r, g, b, a )

function getBlendMode()
	return graphics.getBlendMode()
end

function getColor()
	r, g, b, a = graphics.getColor()
	_color.r = r
	_color.g = g
	_color.b = b
	_color.a = a
	return _color
end

local mode   = nil
local w, h   = -1, -1
local r      = 1
local mx, my = -1, -1

function getFullscreenModes( x, y )
	local modes = window.getFullscreenModes()
	if ( x and y ) then
		for i = #modes, 1, -1 do
			mode = modes[ i ]
			w, h = mode.width, mode.height
			if ( w >= 800 and h >= 600 ) then
				r = gcd( w, h )
				mx = w / r
				my = h / r
				if ( not ( mx == x and my == y ) ) then
					table.remove( modes, i )
				end
			else
				table.remove( modes, i )
			end
		end
	end
	table.sort( modes, function( a, b )
		return a.width * a.height < b.width * b.height
	end )
	return modes
end

local _opacity = 1

function getOpacity()
	return _opacity
end

local _stencilFunction = nil

function getStencil()
	return _stencilFunction
end

function getViewportAspectRatio()
	w = graphics.getWidth()
	h = graphics.getHeight()
	r = gcd( w, h )
	return w / r, h / r
end

function getViewportHeight()
	return graphics.getHeight()
end

function getViewportWidth()
	return graphics.getWidth()
end

function newFont( filename, size )
	return graphics.newFont( filename, size )
end

function newFramebuffer( width, height )
	require( "engine.client.framebuffer" )
	return _G.framebuffer( width, height )
end

function newFullscreenFramebuffer()
	require( "engine.client.framebuffer" )
	return _G.fullscreenframebuffer()
end

function newImage( filename )
	require( "engine.client.image" )
	return _G.image( filename )
end

function newQuad( x, y, width, height, sw, sh )
	return graphics.newQuad( x, y, width, height, sw, sh )
end

function newShader( ... )
	if ( not graphics.isSupported( "shader" ) ) then
		return nil
	end

	return graphics.newShader( ... )
end

function newSpriteBatch( image, size, usagehint )
	return graphics.newSpriteBatch( image, size, usagehint or "dynamic" )
end

local points = nil

function line( ... )
	points = { ... }
	for i, v in ipairs( points ) do
		points[ i ] = v + 0.5
	end
	graphics.line( unpack( points ) )
end

function pop()
	graphics.pop()
end

function print( text, x, y, r, sx, sy, ox, oy, kx, ky, tracking )
	if ( tracking ) then
		local font = graphics.getFont()
		local char
		for i = 1, string.len( text ) do
			char = string.sub( text, i, i )
			graphics.print( char, x, y, r, sx, sy, ox, oy, kx, ky )
			x = x + font:getWidth( char ) + tracking
		end
		return
	end

	graphics.print( text, x, y, r, sx, sy, ox, oy, kx, ky )
end

function printf( text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky )
	graphics.printf( text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky )
end

function push()
	graphics.push()
end

function rectangle( mode, x, y, width, height )
	-- HACKHACK: There's something wrong with line drawing in interactive mode!!
	if ( _INTERACTIVE ) then
		graphics.rectangle( mode, x, y, width, height )
		return
	end

	if ( mode == "line" ) then
		line( x,               y,
		      x + width - 0.5, y,
		      x + width - 0.5, y + height - 1,
		      x,               y + height - 1,
		      x + 0.5,         y + 0.5 )
	else
		graphics.rectangle( mode, x, y, width, height )
	end
end

function scale( sx, sy )
	graphics.scale( sx, sy )
end

local tempColor = color()

function setBackgroundColor( color, multiplicative )
	tempColor[ 1 ] = color.r * ( multiplicative and _opacity or 1 )
	tempColor[ 2 ] = color.g * ( multiplicative and _opacity or 1 )
	tempColor[ 3 ] = color.b * ( multiplicative and _opacity or 1 )
	tempColor[ 4 ] = color.a * _opacity
	graphics.setBackgroundColor( tempColor )
end

function setBlendMode( mode )
	graphics.setBlendMode( mode )
end

function setColor( color, multiplicative )
	tempColor[ 1 ] = color.r * ( multiplicative and _opacity or 1 )
	tempColor[ 2 ] = color.g * ( multiplicative and _opacity or 1 )
	tempColor[ 3 ] = color.b * ( multiplicative and _opacity or 1 )
	tempColor[ 4 ] = color.a * _opacity
	graphics.setColor( tempColor )
end

function setFont( font )
	graphics.setFont( font )
end

function setLineWidth( width )
	graphics.setLineWidth( width )
end

function setMode( width, height, flags )
	local success = window.setMode( width, height, flags )
	if ( success ) then
		_G.engine.reload()
	end
	return success
end

function setOpacity( opacity )
	_opacity = opacity
end

function setShader( shader )
	if ( not graphics.isSupported( "shader" ) ) then
		return
	end

	graphics.setShader( shader )
end

function setStencil( stencilFunction )
	_stencilFunction = stencilFunction
	graphics.setStencil( stencilFunction )
end

function translate( dx, dy )
	graphics.translate( dx, dy )
end
