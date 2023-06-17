dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "global_definitions.lua")
dofile(minetest.get_modpath("airutils") .. DIR_DELIM .. "lib_planes" .. DIR_DELIM .. "hud.lua")

function airutils.properties_copy(origin_table)
    local tablecopy = {}
    for k, v in pairs(origin_table) do
      tablecopy[k] = v
    end
    return tablecopy
end

function airutils.get_hipotenuse_value(point1, point2)
    return math.sqrt((point1.x - point2.x) ^ 2 + (point1.y - point2.y) ^ 2 + (point1.z - point2.z) ^ 2)
end

function airutils.dot(v1,v2)
	return v1.x*v2.x+v1.y*v2.y+v1.z*v2.z
end

function airutils.sign(n)
	return n>=0 and 1 or -1
end

function airutils.minmax(v,m)
	return math.min(math.abs(v),m)*airutils.sign(v)
end

function airutils.get_gauge_angle(value, initial_angle)
    initial_angle = initial_angle or 90
    local angle = value * 18
    angle = angle - initial_angle
    angle = angle * -1
	return angle
end

-- attach player
function airutils.attach(self, player, instructor_mode)
    instructor_mode = instructor_mode or false
    local name = player:get_player_name()
    self.driver_name = name

    -- attach the driver
    local eye_y = 0
    if instructor_mode == true then
        eye_y = -2.5
        player:set_attach(self.passenger_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    else
        eye_y = -4
        player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    end
    if airutils.detect_player_api(player) == 1 then
        eye_y = eye_y + 6.5
    end

    player:set_eye_offset({x = 0, y = eye_y, z = 2}, {x = 0, y = 1, z = -30})
    player_api.player_attached[name] = true
    player_api.set_animation(player, "sit")
    -- make the driver sit
    minetest.after(1, function()
        if player then
            --minetest.chat_send_all("okay")
            airutils.sit(player)
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

-- attach passenger
function airutils.attach_pax(self, player)
    local name = player:get_player_name()
    self._passenger = name

    -- attach the driver
    local eye_y = 0
    if self._instruction_mode == true then
        eye_y = -4
        player:set_attach(self.pilot_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    else
        eye_y = -2.5
        player:set_attach(self.passenger_seat_base, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
    end
    if airutils.detect_player_api(player) == 1 then
        eye_y = eye_y + 6.5
    end

    player:set_eye_offset({x = 0, y = eye_y, z = 2}, {x = 0, y = 1, z = -30})
    player_api.player_attached[name] = true
    player_api.set_animation(player, "sit")
    -- make the driver sit
    minetest.after(1, function()
        player = minetest.get_player_by_name(name)
        if player then
            airutils.sit(player)
            --apply_physics_override(player, {speed=0,gravity=0,jump=0})
        end
    end)
end

function airutils.dettachPlayer(self, player)
    local name = self.driver_name
    airutils.setText(self, self.infotext)

    airutils.remove_hud(player)

    --self._engine_running = false

    -- driver clicked the object => driver gets off the vehicle
    self.driver_name = nil

    -- detach the player
    --player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
    player:set_detach()
    player_api.player_attached[name] = nil
    player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    player_api.set_animation(player, "stand")
    self.driver = nil
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
end

function airutils.dettach_pax(self, player)
    local name = self._passenger

    -- passenger clicked the object => driver gets off the vehicle
    self._passenger = nil

    -- detach the player
    --player:set_physics_override({speed = 1, jump = 1, gravity = 1, sneak = true})
    if player then
        player:set_detach()
        player_api.player_attached[name] = nil
        player_api.set_animation(player, "stand")
        player:set_eye_offset({x=0,y=0,z=0},{x=0,y=0,z=0})
    --remove_physics_override(player, {speed=1,gravity=1,jump=1})
    end
end

function airutils.checkAttach(self, player)
    if player then
        local player_attach = player:get_attach()
        if player_attach then
            if player_attach == self.pilot_seat_base or player_attach == self.passenger_seat_base then
                return true
            end
        end
    end
    return false
end

-- destroy the boat
function airutils.destroy(self)
    if self.sound_handle then
        minetest.sound_stop(self.sound_handle)
        self.sound_handle = nil
    end

    if self._passenger then
        -- detach the passenger
        local passenger = minetest.get_player_by_name(self._passenger)
        if passenger then
            airutils.dettach_pax(self, passenger)
        end
    end

    if self.driver_name then
        -- detach the driver
        local player = minetest.get_player_by_name(self.driver_name)
        airutils.dettachPlayer(self, player)
    end

    local pos = self.object:get_pos()

    if self._destroy_parts_method then
        self._destroy_parts_method(self)
    end

    airutils.destroy_inventory(self)
    self.object:remove()

    --[[pos.y=pos.y+2
    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'hidroplane:wings')

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:steel_ingot')
    end

    for i=1,2 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'wool:white')
    end

    for i=1,6 do
	    minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:mese_crystal')
        minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'default:diamond')
    end]]--

    --minetest.add_item({x=pos.x+math.random()-0.5,y=pos.y,z=pos.z+math.random()-0.5},'hidroplane:hidro')
end

function airutils.testImpact(self, velocity, position)
    local p = position --self.object:get_pos()
    local collision = false
    if self._last_vel == nil then return end
    --lets calculate the vertical speed, to avoid the bug on colliding on floor with hard lag
    if abs(velocity.y - self._last_vel.y) > 2 then
		local noded = airutils.nodeatpos(airutils.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
		    collision = true
	    else
            self.object:set_velocity(self._last_vel)
            --self.object:set_acceleration(self._last_accell)
            self.object:set_velocity(vector.add(velocity, vector.multiply(self._last_accell, self.dtime/8)))
        end
    end
    local impact = abs(airutils.get_hipotenuse_value(velocity, self._last_vel))
    --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
    if impact > 2 then
        --minetest.chat_send_all('impact: '.. impact .. ' - hp: ' .. self.hp_max)
        if self.colinfo then
            collision = self.colinfo.collides
        end
    end

    if impact > 1.2  and self._longit_speed > 2 then
        local noded = airutils.nodeatpos(airutils.pos_shift(p,{y=-2.8}))
	    if (noded and noded.drawtype ~= 'airlike') then
            minetest.sound_play("airutils_touch", {
                --to_player = self.driver_name,
                object = self.object,
                max_hear_distance = 15,
                gain = 1.0,
                fade = 0.0,
                pitch = 1.0,
            }, true)
	    end
    end

    if collision then
        --self.object:set_velocity({x=0,y=0,z=0})
        local damage = impact / 2
        self.hp_max = self.hp_max - damage --subtract the impact value directly to hp meter
        minetest.sound_play(self._collision_sound, {
            --to_player = self.driver_name,
            object = self.object,
            max_hear_distance = 15,
            gain = 1.0,
            fade = 0.0,
            pitch = 1.0,
        }, true)

        if self.driver_name then
            local player_name = self.driver_name
            airutils.setText(self, self.infotext)

            --minetest.chat_send_all('damage: '.. damage .. ' - hp: ' .. self.hp_max)
            if self.hp_max < 0 then --if acumulated damage is greater than 50, adieu
                airutils.destroy(self)
            end

            local player = minetest.get_player_by_name(player_name)
            if player then
		        if player:get_hp() > 0 then
			        player:set_hp(player:get_hp()-(damage/2))
		        end
            end
            if self._passenger ~= nil then
                local passenger = minetest.get_player_by_name(self._passenger)
                if passenger then
		            if passenger:get_hp() > 0 then
			            passenger:set_hp(passenger:get_hp()-(damage/2))
		            end
                end
            end
        end

    end
end

function airutils.checkattachBug(self)
    -- for some engine error the player can be detached from the submarine, so lets set him attached again
    if self.owner and self.driver_name then
        -- attach the driver again
        local player = minetest.get_player_by_name(self.owner)
        if player then
		    if player:get_hp() > 0 then
                airutils.attach(self, player, self._instruction_mode)
            else
                airutils.dettachPlayer(self, player)
		    end
        else
            if self._passenger ~= nil and self._command_is_given == false then
                self._autopilot = false
                airutils.transfer_control(self, true)
            end
        end
    end
end

function airutils.engineSoundPlay(self)
    --sound
    if self.sound_handle then minetest.sound_stop(self.sound_handle) end
    if self.object then
        self.sound_handle = minetest.sound_play({name = self._engine_sound},
            {object = self.object, gain = 2.0,
                pitch = 0.5 + ((self._power_lever/100)/2),
                max_hear_distance = 15,
                loop = true,})
    end
end

function airutils.engine_set_sound_and_animation(self)
    --minetest.chat_send_all('test1 ' .. dump(self._engine_running) )
    if self._engine_running then
        if self._last_applied_power ~= self._power_lever then
            --minetest.chat_send_all('test2')
            self._last_applied_power = self._power_lever
            self.object:set_animation_frame_speed(60 + self._power_lever)
            airutils.engineSoundPlay(self)
        end
    else
        if self.sound_handle then
            minetest.sound_stop(self.sound_handle)
            self.sound_handle = nil
            self.object:set_animation_frame_speed(0)
        end
    end
end

function airutils.add_paintable_part(self, entity_ref)
    if not self._paintable_parts then self._paintable_parts = {} end
    table.insert(self._paintable_parts, entity_ref:get_luaentity())
end

function airutils.set_param_paint(self, puncher, itmstck)
    local item_name = ""
    if itmstck then item_name = itmstck:get_name() end
    
    if item_name == "automobiles_lib:painter" or item_name == "bike:painter" then
        --painting with bike painter
        local meta = itmstck:get_meta()
	    local colstr = meta:get_string("paint_color")
        airutils.param_paint(self, colstr)
        return true
    else
        --painting with dyes
        local split = string.split(item_name, ":")
        local color, indx, _
        if split[1] then _,indx = split[1]:find('dye') end
        if indx then
            --[[for clr,_ in pairs(airutils.colors) do
                local _,x = split[2]:find(clr)
                if x then color = clr end
            end]]--
            --lets paint!!!!
	        local color = (item_name:sub(indx+1)):gsub(":", "")
	        local colstr = airutils.colors[color]
            --minetest.chat_send_all(color ..' '.. dump(colstr))
            --minetest.chat_send_all(dump(airutils.colors))
	        if colstr then
                airutils.param_paint(self, colstr)
		        itmstck:set_count(itmstck:get_count()-1)
                if puncher ~= nil then puncher:set_wielded_item(itmstck) end
                return true
	        end
            -- end painting
        end
    end
    return false
end

local function _paint(self, l_textures, colstr, paint_list, mask_associations)
    paint_list = paint_list or self._painting_texture
    mask_associations = mask_associations or self._mask_painting_associations
    for _, texture in ipairs(l_textures) do
        for i, texture_name in ipairs(paint_list) do --textures list
            local indx = texture:find(texture_name)
            if indx then
                l_textures[_] = texture_name.."^[multiply:".. colstr  --paint it normally
                local mask_texture = mask_associations[texture_name] --check if it demands a maks too
                if mask_texture then --so it then
                    l_textures[_] = "("..l_textures[_]..")^("..texture_name.."^[mask:"..mask_texture..")" --add the mask
                end
            end
        end
    end
    return l_textures
end

--painting
function airutils.param_paint(self, colstr)
    if not self then return end
    if colstr then
        self._color = colstr
        local l_textures = self.initial_properties.textures
        l_textures = _paint(self, l_textures, colstr) --paint the main plane
        self.object:set_properties({textures=l_textures})

        if self._paintable_parts then --paint individual parts
            for i, part_entity in ipairs(self._paintable_parts) do
                local p_textures = part_entity.initial_properties.textures
                p_textures = _paint(part_entity, p_textures, colstr, self._painting_texture, self._mask_painting_associations)
                part_entity.object:set_properties({textures=p_textures})
            end
        end
    end
end

function airutils.paint_with_mask(self, colstr, target_texture, mask_texture)
    if colstr then
        self._color = colstr
        self._det_color = mask_colstr
        local l_textures = self.initial_properties.textures
        for _, texture in ipairs(l_textures) do
            local indx = texture:find(target_texture)
            if indx then
                --"("..target_texture.."^[mask:"..mask_texture..")"
                l_textures[_] = "("..target_texture.."^[multiply:".. colstr..")^("..target_texture.."^[mask:"..mask_texture..")"
            end
        end
	    self.object:set_properties({textures=l_textures})
    end
end
