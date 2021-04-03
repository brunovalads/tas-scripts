

-- Some renaming
local fmt = string.format
local floor = math.floor
local ceil = math.ceil

-- Font settings
local BIZHAWK_FONT_WIDTH = 10
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

-- Memory read/write functions
local u8 =  mainmemory.read_u8
local s8 =  mainmemory.read_s8
local w8 =  mainmemory.write_u8
local u16 = mainmemory.read_u16_le
local s16 = mainmemory.read_s16_le
local w16 = mainmemory.write_u16_le

-- To check if file exists
local function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then io.close(f) return true else return false end
end

-- Game variables

local RAM = {
  camera_x = 0x000C, -- TODO: figure out better
  camera_y = 0x000D, -- TODO: figure out better
  
  screen_id1 = 0x0033,
  screen_id2 = 0x0067,
  screen_id3 = 0x0086,
  
  puzzle_id = 0x0037,
  
  block_y_pos = 0x0042,
  block_x_pos = 0x0043,
  
  puzzle_mode_flag = 0x0046,
  
  moving_timer = 0x0300,
  
  puzzle_flags = 0x0500, 
}

-- Game data
local puzzle_id_to_name = { -- my own naming, based on the apparent order
  [0x00] = "0-1",
  [0x01] = "0-2",
  [0x02] = "0-3",
  [0x03] = "0-4",
  [0x04] = "B-1",
  [0x05] = "B-2",
  [0x06] = "B-3",
  [0x07] = "B-4",
  [0x08] = "B-5",
  [0x09] = "B-6",
  [0x0A] = "B-7",
  [0x0B] = "B-8",
  [0x0C] = "C-1",
  [0x0D] = "C-2",
  [0x0E] = "C-3",
  [0x0F] = "C-4",
  [0x10] = "C-5",
  [0x11] = "C-6",
  [0x12] = "C-7",
  [0x13] = "C-8",
  [0x14] = "C-9",
  [0x15] = "A-1",
  [0x16] = "A-2",
  [0x17] = "A-3",
  [0x18] = "A-4",
  [0x19] = "A-5",
  [0x1A] = "A-6",
  [0x1B] = "A-7",
  [0x1C] = "A-8",
  [0x1D] = "A-9",
  [0x1E] = "A-10",
  [0x1F] = "Final"
}


-- Main memory reads
local Camera_x, Camera_y
local Is_puzzle
local function scan_game()
  Camera_x = u8(RAM.camera_x)
  Camera_y = u8(RAM.camera_y)
  
  Is_puzzle = u8(RAM.puzzle_mode_flag) > 0
  
  Framecount = emu.framecount()
end


-- Drawings

local function clear_image_cache() -- clears the image cache every second if not inside a puzzle
  if Is_puzzle then return end
  
  if Framecount%60 == 0 then gui.clearImageCache() end
end

local function display_general_info()
  
  local xpos, ypos = 4, 40
  
  -- Camera
  draw.text(xpos, ypos, fmt("Camera (0x%02X, 0x%02X)", Camera_x, Camera_y))
  ypos = ypos + BIZHAWK_FONT_HEIGHT
  
  -- Position
  local block_x_pos = u8(RAM.block_x_pos)
  local block_y_pos = u8(RAM.block_y_pos)
  draw.text(xpos, ypos, fmt("Block pos (0x%02X, 0x%02X)", block_x_pos, block_y_pos))
  ypos = ypos + BIZHAWK_FONT_HEIGHT
  
  -- Puzzle id or moving timer
  if Is_puzzle then
    local puzzle_id = u8(RAM.puzzle_id)
    draw.text(xpos, ypos, fmt("Puzzle id: %d(0x%02X) %s", puzzle_id, puzzle_id, puzzle_id_to_name[puzzle_id]))
  else
    local moving_timer = u8(RAM.moving_timer)
    draw.text(xpos, ypos, fmt("Moving timer: %d", moving_timer))
  end
  ypos = ypos + BIZHAWK_FONT_HEIGHT
  
  -- Current screen id
  local screen_id1 = u8(RAM.screen_id1)
  local screen_id2 = u8(RAM.screen_id2)
  local screen_id3 = u8(RAM.screen_id3)
  draw.text(xpos, ypos, fmt("Screen: %02X/%02X/%02X", screen_id1, screen_id2, screen_id3))
  ypos = ypos + 2*BIZHAWK_FONT_HEIGHT
  
  --- Puzzle flags
  draw.text(xpos, ypos, fmt("Puzzle flags:"))
  ypos = ypos + 2*BIZHAWK_FONT_HEIGHT
  for i = 0, 9 do
    draw.text(xpos, ypos + i*BIZHAWK_FONT_HEIGHT, fmt("%d", i+1))
  end
  local puzzle_flags = mainmemory.readbyterange(RAM.puzzle_flags, 0x20)
  local colour_table = {[0] = 0x80808080, [1] = 0xa0808080, [2] = 0xff00FF00}
  -- 0- flags
  xpos = xpos + 2*BIZHAWK_FONT_WIDTH
  draw.text(xpos, ypos - BIZHAWK_FONT_HEIGHT, "0")
  for i = 0x00, 0x03 do
    draw.text(xpos, ypos + i*BIZHAWK_FONT_HEIGHT, fmt("%d", puzzle_flags[i]), colour_table[puzzle_flags[i]])
  end
  -- A- flags
  xpos = xpos + 2*BIZHAWK_FONT_WIDTH
  draw.text(xpos, ypos - BIZHAWK_FONT_HEIGHT, "A")
  for i = 0x15, 0x1E do
    draw.text(xpos, ypos + (i-0x15)*BIZHAWK_FONT_HEIGHT, fmt("%d", puzzle_flags[i]), colour_table[puzzle_flags[i]])
  end
  -- B- flags
  xpos = xpos + 2*BIZHAWK_FONT_WIDTH
  draw.text(xpos, ypos - BIZHAWK_FONT_HEIGHT, "B")
  for i = 0x04, 0x0B do
    draw.text(xpos, ypos + (i-0x04)*BIZHAWK_FONT_HEIGHT, fmt("%d", puzzle_flags[i]), colour_table[puzzle_flags[i]])
  end
  -- C- flags
  xpos = xpos + 2*BIZHAWK_FONT_WIDTH
  draw.text(xpos, ypos - BIZHAWK_FONT_HEIGHT, "C")
  for i = 0x0C, 0x14 do
    draw.text(xpos, ypos + (i-0x0C)*BIZHAWK_FONT_HEIGHT, fmt("%d", puzzle_flags[i]), colour_table[puzzle_flags[i]])
  end
  
  
end

local function draw_grid()
  if Is_puzzle then return end
  
  local x_square, y_square
  
  -- Draw the 16x16 tile grid
  for i = 0, 31 do
    for j = 0, 31 do
      x_square, y_square = i*16 - Camera_x, j*16 - Camera_y
      if x_square > -16 and x_square < 256 and y_square > -8 and y_square < 232 then
        draw.rectangle(x_square, y_square, 15, 15, 0x80FFFFFF)
      end
    end
  end
  
  --[[ Draw the 256x256 screen grid
  x_square, y_square = 0 - Camera_x, -32 - Camera_y
  draw.rectangle(x_square, y_square, 255, 271, 0xffFF0000) -- red
  
  x_square, y_square = 256 - Camera_x, -32 - Camera_y
  draw.rectangle(x_square, y_square, 255, 271, 0xffFFFF00) -- yellow
  
  x_square, y_square = 0 - Camera_x, 240 - Camera_y
  draw.rectangle(x_square, y_square, 255, 271, 0xffFF00FF) -- purple
  
  x_square, y_square = 256 - Camera_x, 240 - Camera_y
  draw.rectangle(x_square, y_square, 255, 271, 0xff00FFFF) -- cyan]]
end

local function solution_display()
  if not Is_puzzle then return end
  
  -- Get puzzle image file name
  local puzzle_id = u8(RAM.puzzle_id)
  local image_file = fmt("Solution %s transp.png", puzzle_id_to_name[puzzle_id])   --Solution 0-1 transp
  
  -- Failsafe to prevent loading non-existent images
  if not file_exists(image_file) then print("Couldn't find solution image for this puzzle!") return end
  
  -- Draw the solution image
  draw.image(image_file, 0, 8)
end

-- ROM write to make tilemap
--[[
for i = 0x0, 0xFF do
  memory.writebyte(0x5F3D + i, i, "PRG ROM")
end
]]

-- Main

while true do
  -- Update stuff
  scan_game()
  
  -- Drawings
  clear_image_cache()
  display_general_info()
  draw_grid()
  solution_display()
  
  -- Advance
  emu.frameadvance()

end