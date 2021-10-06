meta = {
	name = "Hot and Cold",
	version = "1",
	description = "Play hot and cold with the Ushabtis",
	author = "Zappatic"
}

local init_performed = false
local white = Color:white()
local red = Color:red()
local blue = Color:blue()
local thermometer_texture
local thermometer_hud_pos
local thermometers_count = 15
local wiggle_offset = 0.002
local max_distance = 0
local previous_column = -1
local caption_scale = 0.0008
local caption_timer = 0
local caption = ""
local caption_color = blue
local caption_duration = 120

function init()
    local thermometer_texture_def = TextureDefinition:new()
    thermometer_texture_def.texture_path = "thermometer.png"
    thermometer_texture_def.width = thermometers_count * 256
    thermometer_texture_def.height = 256
    thermometer_texture_def.tile_height = 256
    thermometer_texture_def.tile_width = 256

    thermometer_texture = define_texture(thermometer_texture_def)

    local thermometer_hud_width = 0.16
    local thermometer_hud_height = thermometer_hud_width * (16.0/9.0)
    local thermometer_hud_x = 0.840
    local thermometer_hud_y = 0.80
    thermometer_hud_pos = AABB:new( thermometer_hud_x, 
                                    thermometer_hud_y, 
                                    thermometer_hud_x + thermometer_hud_width,
                                    thermometer_hud_y - thermometer_hud_height)

    init_performed = true
end

function find_ushabti()
    local correct = state:get_correct_ushabti()
    local ushabtis = get_entities_by(ENT_TYPE.ITEM_USHABTI, 0, LAYER.BACK)
    for _, ushabti_uid in pairs(ushabtis) do
        local ushabti = get_entity(ushabti_uid)
        if ushabti.animation_frame == correct then
            return ushabti
        end
    end
    return nil
end

function calc_max_distance()
    local lowest_x = 5000
    local highest_x = 0
    local lowest_y = 5000
    local highest_y = 0
    local bordertiles = get_entities_by(ENT_TYPE.FLOOR_BORDERTILE_METAL, 0, LAYER.BACK)
    for _, floor_uid in pairs(bordertiles) do
        local x, y, _ = get_position(floor_uid)
        if x < lowest_x then lowest_x = x end
        if x > highest_x then highest_x = x end
        if y < lowest_y then lowest_y = y end
        if y > highest_y then highest_y = y end
    end
    lowest_x = lowest_x + 3
    lowest_y = lowest_y + 3
    highest_x = highest_x - 3
    highest_y = highest_y - 3
    local dx = highest_x - lowest_x
    local dy = highest_y - lowest_y
    max_distance = math.sqrt( (dx*dx) + (dy*dy) )
end

set_callback(function() 
    if not init_performed then
        init()
    end
    if state.world == 6 and state.level == 2 then
        calc_max_distance()
    end
end, ON.LEVEL)

set_callback(function(render_ctx) 
    if not init_performed then
        init()
    end
    if state.world == 6 and state.level == 2 and state.camera_layer == LAYER.BACK 
        and players[1]:has_powerup(ENT_TYPE.ITEM_POWERUP_TABLETOFDESTINY) 
        and not test_flag(state.quest_flags, 8) then

        if max_distance == 0 then calc_max_distance() end
        local thermometer_column = 0
        local ushabti = find_ushabti()
        if ushabti ~= nil then
            local wiggle_delta_x = 0
            local wiggle_delta_y = 0
            local d = distance(ushabti.uid, players[1].uid)
            if players[1].holding_uid == ushabti.uid or d < 0.5 then
                if state.pause == 0 then
                    wiggle_delta_x = wiggle_offset * math.sin(60*math.rad(state.time_total))
                    wiggle_delta_y = wiggle_offset * math.cos(48*math.rad(state.time_total))
                end
                thermometer_column = thermometers_count - 1
            else
                thermometer_column =  math.floor(( (max_distance - d) / max_distance) * (thermometers_count - 1))
            end
            local bounds = thermometer_hud_pos
            bounds:offset(wiggle_delta_x, wiggle_delta_y)
            render_ctx:draw_screen_texture(thermometer_texture, 0, thermometer_column, bounds, white)

            if previous_column > 0 then
                if previous_column ~= thermometer_column then
                    caption = "colder"
                    caption_color = blue
                    if previous_column < thermometer_column then
                        caption = "warmer"
                        caption_color = red
                    end
                    if thermometer_column == thermometers_count - 1 then
                        caption = "scorching!"
                        caption_color = red
                    end
                    caption_timer = caption_duration
                end
                if caption_timer > 0 then
                    local caption_x = bounds.left + (bounds:width() / 2.0)
                    local caption_y = bounds.bottom - 0.04
                    caption_color.a = caption_timer / caption_duration
                    render_ctx:draw_text(caption, caption_x, caption_y, caption_scale, caption_scale, caption_color, VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.ITALIC)
                end
                caption_timer = caption_timer - 1
            end
            previous_column = thermometer_column
        end
    end
end, ON.RENDER_POST_HUD)
