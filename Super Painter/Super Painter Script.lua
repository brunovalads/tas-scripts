--####################################################################
--##                                                                ##
--##   Super Painter (NES) Script for BizHawk                       ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [03/2022]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Script options
local OPTIONS = {
    
    -- Script settings
    left_gap = 70, 
    right_gap = 8,
    top_gap = 30,
    bottom_gap = 30,
    
    ---- DEBUG ----
    DEBUG = false, -- to display debug info for script development only!
    --left_gap = 0, -- 80 if scaled down
    --right_gap = 250,
    --top_gap = 0,
    --bottom_gap = 0, -- 20 is scaled down

}

-- Basic functions renaming
local fmt = string.format
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi

-- Memory read/write functions
local u8 =  memory.read_u8
local s8 =  memory.read_s8
local w8 =  memory.write_u8
local u16 = memory.read_u16_le
local s16 = memory.read_s16_le
local w16 = memory.write_u16_le
local u24 = memory.read_u24_le
local s24 = memory.read_s24_le
local w24 = memory.write_u24_le

-- Font settings
local BIZHAWK_FONT_WIDTH = 10  -- correction to the scale is done in bizhawk_screen_info()
local BIZHAWK_FONT_HEIGHT = 18

-- Drawing function renaming
local draw = {
  box = gui.drawBox,
  ellipse = gui.drawEllipse,
  image = gui.drawImage,
  image_region = gui.drawImageRegion,
  line = gui.drawLine,
  cross = gui.drawAxis,
  pixel = gui.drawPixel,
  polygon = gui.drawPolygon,
  rectangle = gui.drawRectangle,
  text = gui.text,
  pixel_text = gui.pixelText,
}


--################################################################################################################################################################
-- GENERAL UTILITIES

-- Get screen dimensions of the emulator and the game
local PC, Game = {}, {}
local Scale
local function bizhawk_screen_info()
    -- Get/calculate screen scale -------------------------------------------------
    if client.borderwidth() == 0 then -- to avoid division by zero bug when borders are not yet ready when loading the script
        Scale = 2 -- because is the one I always use
    elseif OPTIONS.left_gap > 0 and OPTIONS.top_gap > 0 then -- to make sure this method won't get div/0
        Scale = math.min(client.borderwidth()/OPTIONS.left_gap, client.borderheight()/OPTIONS.top_gap) -- Pixel scale
    else
        Scale = client.getwindowsize()
    end

    -- Dimensions in PC pixels ----------------------------------------------------
    PC.screen_width = client.screenwidth()   --\ Emu screen drawing area (doesn't take menu and status bar into account)
    PC.screen_height = client.screenheight() --/ 

    PC.left_padding = client.borderwidth()         --\
    PC.right_padding = OPTIONS.right_gap * Scale   -- | Emu extra paddings around the game area
    PC.top_padding = client.borderheight()         -- |
    PC.bottom_padding = OPTIONS.bottom_gap * Scale --/

    PC.buffer_width = PC.screen_width - PC.left_padding - PC.right_padding   --\ Game area
    PC.buffer_height = PC.screen_height - PC.top_padding - PC.bottom_padding --/

    PC.buffer_middle_x = PC.left_padding + PC.buffer_width/2 --\ Middle coordinates of the game area, referenced to the whole emu screen
    PC.buffer_middle_y = PC.top_padding + PC.buffer_height/2 --/

    PC.screen_middle_x = PC.screen_width/2  --\ Middle coordinates of the emu screen drawing area
    PC.screen_middle_y = PC.screen_height/2 --/

    PC.right_padding_start = PC.left_padding + PC.buffer_width  --\ Coordinates for the start of right and bottom paddings
    PC.bottom_padding_start = PC.top_padding + PC.buffer_height --/

    -- Dimensions in game pixels ----------------------------------------------------
    Game.buffer_width = client.bufferwidth()
    Game.buffer_height = client.bufferheight()

    Game.screen_width = PC.screen_width/Scale
    Game.screen_height = PC.screen_height/Scale

    Game.left_padding = PC.left_padding/Scale
    Game.right_padding = PC.right_padding/Scale
    Game.top_padding = PC.top_padding/Scale
    Game.bottom_padding = PC.bottom_padding/Scale

    Game.buffer_middle_x = Game.left_padding + Game.buffer_width/2
    Game.buffer_middle_y = Game.top_padding + Game.buffer_height/2

    Game.screen_middle_x = Game.screen_width/2
    Game.screen_middle_y = Game.screen_height/2

    Game.right_padding_start = Game.left_padding + Game.buffer_width
    Game.bottom_padding_start = Game.top_padding + Game.buffer_height
 
 end

-- Returns frames-time conversion
local function frame_time(frame, mili)
    local total_seconds = frame/FRAMERATE
    local hours = floor(total_seconds/3600)
    local tmp = total_seconds - 3600*hours
    local minutes = floor(tmp/60)
    tmp = tmp - 60*minutes
    local seconds = floor(tmp)

    local miliseconds = 1000* (total_seconds%1)
    local miliseconds_str = fmt(".%03.0f", miliseconds)
    local str = fmt("%.2d:%.2d:%.2d%s", hours, minutes, seconds, mili and miliseconds_str or "")
    return str
end

-- Get main BizHawk status
local Framecount, Movie_active, Movie_size
local function bizhawk_status()
    Framecount = emu.framecount()
    if Movie_active and not Movie_size then
        Movie_size = movie.length()
    end
end
-- This can be read just once, because it shouldn't change when making encodes (if using TAStudio the movie length will keep incrementing if you reach the end, so this is a workaround)
Movie_active = movie.isloaded()
if Movie_active then
    Movie_size = movie.length()
end

-- Draw an arrow given (x1, y1) and (x2, y2)
function draw.arrow(x1, y1, x2, y2, colour, head)
    
    local angle = math.atan((y2-y1)/(x2-x1)) -- in radians
    
    -- Arrow head
    local head_size = head or 10
    local angle1, angle2 = angle + math.pi/4, angle - math.pi/4 --0.785398163398, angle - 0.785398163398 -- 45° in radians
    local delta_x1, delta_y1 = floor(head_size*math.cos(angle1)), floor(head_size*math.sin(angle1))
    local delta_x2, delta_y2 = floor(head_size*math.cos(angle2)), floor(head_size*math.sin(angle2))
    local head1_x1, head1_y1 = x2, y2 
    local head1_x2, head1_y2 
    local head2_x1, head2_y1 = x2, y2
    local head2_x2, head2_y2
    
    if x1 < x2 then -- 1st and 4th quadrant
        head1_x2, head1_y2 = head1_x1 - delta_x1, head1_y1 - delta_y1
        head2_x2, head2_y2 = head2_x1 - delta_x2, head2_y1 - delta_y2
    elseif x1 == x2 then -- vertical arrow
        head1_x2, head1_y2 = head1_x1 - delta_x1, head1_y1 - delta_y1
        head2_x2, head2_y2 = head2_x1 - delta_x2, head2_y1 - delta_y2
    else
        head1_x2, head1_y2 = head1_x1 + delta_x1, head1_y1 + delta_y1
        head2_x2, head2_y2 = head2_x1 + delta_x2, head2_y1 + delta_y2
    end
    
    -- Draw
    draw.line(x1, y1, x2, y2, colour)
    draw.line(head1_x1, head1_y1, head1_x2, head1_y2, colour)
    draw.line(head2_x1, head2_y1, head2_x2, head2_y2, colour)
end

-- Draw an arrow given a start point, an angle in radians and a length, follow the Left Hand Rule due Y being from top to bottom
function draw.arrow_by_angle(startX, startY, angleRadians, length, headSize, colour)
    
    -- Init
    local length = length or 16
    local headSize = headSize or 8
    local colour = colour or 0xffFFFFFF
    
    -- Calculate the arrow end point
    local endX = startX + length*math.cos(angleRadians)
    local endY = startY + length*math.sin(angleRadians)
    
    -- Calculate the angles for the head lines
    local angleLeft = angleRadians + 3*math.pi/4 -- 135° in radians
    local angleRight = angleRadians - 3*math.pi/4
    
    -- Calculate the end points for the head lines
    local headLeftEndX = endX + headSize*math.cos(angleLeft)
    local headLeftEndY = endY + headSize*math.sin(angleLeft)
    local headRightEndX = endX + headSize*math.cos(angleRight)
    local headRightEndY = endY + headSize*math.sin(angleRight)
    
    -- Draw the lines
    draw.line(startX, startY, endX, endY, colour)
    draw.line(endX, endY, headLeftEndX, headLeftEndY, colour)
    draw.line(endX, endY, headRightEndX, headRightEndY, colour)
end


--################################################################################################################################################################
-- GAME INFO DISPLAY FUNCTIONS

-- RAM addresses
local RAM = {
    -- Enemies, 6 bytes per table, 1 per slot
    enemies_x_pos = 0x0389,
    enemies_y_pos = 0x038F,
    enemies_anim_timer = 0x0395,
    enemies_anim_frame_curr = 0x039B,
    enemies_anim_frame_1 = 0x03A1,
    enemies_anim_frame_2 = 0x03A7,
    enemies_active = 0x03AD, -- flag
    enemies_type = 0x03B3, -- 1 = walking, 2 = flying
    enemies_direction = 0x03B9, -- 1 = left, 2 = right, 3 = down, 4 = up
    enemies_wave_phase = 0x03BF,
    
    -- Falling stars (Game Over screen), 8 slots, 3 bytes per slot struct
    stars_x_pos = 0x03C5,
    stars_y_pos = 0x03C6,
    stars_y_speed = 0x03C7,
    
    -- Falling leaves, 8 bytes per table, 1 per slot
    leaves_x_pos = 0x03DD,
    leaves_y_pos = 0x03E5,
    leaves_wave_phase = 0x03ED, -- the waving
    
    -- Player
    x_pos = 0x03FE,
    y_pos = 0x03FF,
    can_climb = 0x040C,
    climbing = 0x040D,
    x_speed = 0x040E,
    y_speed = 0x040F,
    
    -- General
    level = 0x0411,
    level_loader_x = 0x0412,
    level_loader_y = 0x0413,
    level_loader_current_block = 0x0414, -- level_loader_y * 0x10 + level_loader_x, also it's the currently proccessed enemy
    controller = 0x0415,
    remaining_blocks = 0x0417,
    exit_x = 0x041A,
    exit_y = 0x041B,
    is_paused = 0x041C,
    lives = 0x041F,
    score_increment = 0x0420,
    score_digits = 0x0421, -- 5 bytes, overflow to a 6th
    blocks = 0x0426, -- 0xE0 bytes
}

-- Main player RAM read, outside the main_display because I need previous
local X_pos, Y_pos
local X_pos_prev, Y_pos_prev = 0, 0
local function main_player()
    if X_pos then X_pos_prev = X_pos end -- conditional to avoid writing nil to prev
    if Y_pos then Y_pos_prev = Y_pos end
    X_pos = u8(RAM.x_pos)
    Y_pos = u8(RAM.y_pos)
end

-- Main display function, ALL DRAWINGS SHOULD BE CALLED HERE
local function main_display()
    --- Dark filter
    draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, 256, 224, 0x80000000, 0x80000000)
    
    --- Block grid
    local block_id, block_type
    local colour_border, colour_fill
    for y = 0, 14 do
        for x = 0, 15 do
            -- Get the colour according to the block type
            block_id = y*16 + x
            block_type = u8(RAM.blocks + block_id)
            if block_type == 0 then
                colour_border, colour_fill = 0x80808080, nil
            elseif block_type == 1 then
                colour_border, colour_fill = 0x80FF0000, 0x60FF0000
            elseif block_type == 2 then
                colour_border, colour_fill = 0x8000FF00, 0x6000FF00
            else
                colour_border, colour_fill = 0x8000FFFF, nil --0x8000FFFF
            end
            
            -- Draw the grid
            if block_type ~= 0 then
                draw.rectangle(OPTIONS.left_gap + x*16, OPTIONS.top_gap - 8 + y*16, 15, 15, colour_border, colour_fill)
            end
            
            -- Draw the minimap
            draw.pixel(1 + x, 70 + y, colour_border)
        end
    end
    
    --- Player info
    -- Read RAM
    local x_pos = X_pos
    local y_pos = Y_pos
    local x_speed = s8(RAM.x_speed)
    local y_speed = s8(RAM.y_speed)
    local can_climb = u8(RAM.can_climb) == 1
    local climbing = u8(RAM.climbing) == 1
    local lives = u8(RAM.lives)
    
    -- RAM that need calc
    local dx_pos = X_pos - X_pos_prev
    local dy_pos = Y_pos - Y_pos_prev
    
    -- Display player info
    local i = 0
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Pos: %02X, %02X", x_pos, y_pos)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Speed: %+d, %+d", x_speed, y_speed)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %+d, %+d", dx_pos, dy_pos)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Can climb: %s", can_climb and "yes" or "no")); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Climbing: %s", climbing and "yes" or "no")); i = i + 1
    draw.pixel_text(OPTIONS.left_gap + 0, OPTIONS.top_gap + 8, fmt("%d=", lives), 0x80000000, 0)
    
    -- Show position and hitbox? on screen
    if y_pos >= 0xF0 then y_pos = y_pos - 0x100 end
    draw.cross(OPTIONS.left_gap + x_pos, OPTIONS.top_gap - 8 + y_pos, 2, "orange")
    
    --draw.cross(OPTIONS.left_gap + x_pos - 6, OPTIONS.top_gap - 8 + y_pos + 7, 2, "magenta")
    draw.line(OPTIONS.left_gap + x_pos - 6, OPTIONS.top_gap - 8 + y_pos + 7,
              OPTIONS.left_gap + x_pos - 6, OPTIONS.top_gap - 8 + y_pos - 7, "magenta")
    --draw.cross(OPTIONS.left_gap + x_pos + 5, OPTIONS.top_gap - 8 + y_pos + 7, 2, "magenta")
    draw.line(OPTIONS.left_gap + x_pos + 5, OPTIONS.top_gap - 8 + y_pos + 7,
               OPTIONS.left_gap + x_pos + 5, OPTIONS.top_gap - 8 + y_pos - 7, "magenta")
    
    draw.cross(OPTIONS.left_gap + x_pos - 4, OPTIONS.top_gap - 8 + y_pos + 7, 2, "blue")
    draw.cross(OPTIONS.left_gap + x_pos + 4, OPTIONS.top_gap - 8 + y_pos + 7, 2, "blue")
    draw.cross(OPTIONS.left_gap + x_pos - 4, OPTIONS.top_gap - 8 + y_pos - 6, 2, "blue")
    draw.cross(OPTIONS.left_gap + x_pos + 4, OPTIONS.top_gap - 8 + y_pos - 6, 2, "blue")
    
    -- Show climbing guide for "quick des-climb"
    if climbing then
        local x_pos_rounded = 16*floor(x_pos/16)
        draw.line(OPTIONS.left_gap + x_pos_rounded + 0x4, OPTIONS.top_gap + y_pos - 0x20, OPTIONS.left_gap + x_pos_rounded + 0x4, OPTIONS.top_gap + y_pos + 0x10, 0x8000FFFF)
        draw.line(OPTIONS.left_gap + x_pos_rounded + 0xB, OPTIONS.top_gap + y_pos - 0x20, OPTIONS.left_gap + x_pos_rounded + 0xB, OPTIONS.top_gap + y_pos + 0x10, 0x8000FFFF)
    end
    
    -- Show position on minimap
    draw.pixel(1 + floor(x_pos/16), 70 + floor(y_pos/16), "orange")
    
    --- Level info
    i = i + 1
    -- Current level
    local level = u8(RAM.level)
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Level: %02d/24", level)); i = i + 1
    
    -- Remaining blocks
    local remaining_blocks = u8(RAM.remaining_blocks)
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Remaining blocks: %d", remaining_blocks), remaining_blocks == 0 and 0xff00FF00 or 0xffFF0000); i = i + 1
    
    -- Exit position
    local exit_x = u8(RAM.exit_x)
    local exit_y = u8(RAM.exit_y)
    draw.rectangle(OPTIONS.left_gap + exit_x - 8, OPTIONS.top_gap - 8 + exit_y - 8, 15, 15, 0x80000000, 0x60000000) 
    
    --- Enemy info
    i = i + 4
    local active, type_, direction, colour
    local colours = {
        0xa0A0A0FF, -- blue
        0xa0FF80FF, -- magenta
        0xa0FF6060, -- red
        0xa0FFA100, -- orange
        0xa0FFFF80, -- yellow
        0xa040FF40  -- green
    }
    local directions = {
        [0]={name = "", angle = 0},
        [1]={name = "left", angle = math.pi},
        [2]={name = "right", angle = 0},
        [3]={name = "down", angle = math.pi/2.0},
        [4]={name = "up", angle = 3.0*math.pi/2.0},
    }
    -- Main enemy loop
    for slot = 0, 5 do
        -- Read RAM
        x_pos = u8(RAM.enemies_x_pos + slot)
        y_pos = u8(RAM.enemies_y_pos + slot)
        active = u8(RAM.enemies_active + slot) > 0
        type_ = u8(RAM.enemies_type + slot)
        direction = u8(RAM.enemies_direction + slot)
        y_screen = y_pos < 0xF0 and y_pos or y_pos - 0x100
        
        -- Highlight active enemy slots
        if active then
            colour = colours[slot+1]
            direction_name = directions[direction].name
            draw.cross(OPTIONS.left_gap + x_pos, OPTIONS.top_gap - 8 + y_screen, 2, colour)
            --draw.rectangle(OPTIONS.left_gap + x_pos - 7, OPTIONS.top_gap - 8 + y_pos - 11, 15, 15, colour-0x80000000)
            draw.arrow_by_angle(OPTIONS.left_gap + x_pos, OPTIONS.top_gap - 8 + y_screen, directions[direction].angle, 0x08, 0x04, colour)
        else
            colour = 0x80808080
            direction_name = ""
        end
        
        -- Display enemy table
        draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT + slot * BIZHAWK_FONT_HEIGHT, fmt("#%d: %X (%02X, %02X) %s", slot, type_, x_pos, y_pos, direction_name), colour)
    end
end

--################################################################################################################################################################
-- MAIN

-- Create lateral gaps
client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)

-- Functions to run when script is stopped or reset
event.onexit(function()
  
    forms.destroyall()
  
    --gui.clearImageCache()
    
    gui.clearGraphics()
  
	client.SetGameExtraPadding(0, 0, 0, 0)
  
    print("\nFinishing Super Painter Utility Script.\n------------------------------------")
end)

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print("\n\nSuper Painter Utility Script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time

-- Main loop
while true do
    -- Read very important emu stuff
    bizhawk_screen_info()
    bizhawk_status()
    -- Update main game values and display these stuff
    main_player()
    main_display()
    -- DEBUG
    -- Advance The Frame
    emu.frameadvance()
end


