-- Mine Test Ball Pit (Bällebad)
-- A relaxing ball pit mod with physics-based rainbow balls and a spawner.

local rainbow_colors = {
    "#FF0000:200", -- Red
    "#FFA500:200", -- Orange
    "#FFFF00:200", -- Yellow
    "#008000:200", -- Green
    "#0000FF:200", -- Blue
    "#4B0082:200", -- Indigo
    "#EE82EE:200"  -- Violet
}

minetest.register_craftitem("mine_test_ball_pit:ball", {
    description = "Ball Pit Ball",
    inventory_image = "ball_base.png^[colorize:#FF0000:200",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = minetest.get_pointed_thing_position(pointed_thing, true)
            if pos then
                minetest.add_entity(pos, "mine_test_ball_pit:ball_entity")
                if not (placer and placer:is_player() and minetest.is_creative_enabled(placer:get_player_name())) then
                    itemstack:take_item()
                end
            end
        end
        return itemstack
    end,
})

minetest.register_entity("mine_test_ball_pit:ball_entity", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.125, -0.125, -0.125, 0.125, 0.125, 0.125},
        visual = "mesh",
        mesh = "ball.obj",
        visual_size = {x = 0.25, y = 0.25, z = 0.25},
        textures = {"ball_base.png"},
        hp_max = 1,
        makes_footstep_sound = false,
        static_save = true,
    },

    on_activate = function(self, staticdata)
        -- Allow the ball to be punched, but prevent default damage sounds by avoiding 'fleshy'
        self.object:set_armor_groups({punch_operable = 1})

        -- Set random color if none is saved
        if not self._color_idx then
            if staticdata and staticdata ~= "" then
                self._color_idx = tonumber(staticdata)
            else
                self._color_idx = math.random(1, #rainbow_colors)
            end
        end

        -- Fallback in case of bad staticdata
        if not self._color_idx or self._color_idx < 1 or self._color_idx > #rainbow_colors then
            self._color_idx = 1
        end

        self.object:set_properties({
            textures = {"ball_base.png^[colorize:" .. rainbow_colors[self._color_idx]}
        })

        -- Low gravity (standard is usually 9.8 or similar depending on the game, we use -3.0 for a floaty feel)
        self.object:set_acceleration({x = 0, y = -3.0, z = 0})

        -- Tiny random velocity upon spawn if it's new (staticdata == "")
        if staticdata == "" then
            local rx = (math.random() - 0.5) * 4.0
            local ry = math.random() * 4.0 + 3.0
            local rz = (math.random() - 0.5) * 4.0
            self.object:set_velocity({x = rx, y = ry, z = rz})
        end
    end,

    get_staticdata = function(self)
        return tostring(self._color_idx or 1)
    end,

    on_step = function(self, dtime)
        -- Simulate bounce
        local vel = self.object:get_velocity()
        if not vel then return end

        local pos = self.object:get_pos()
        if not pos then return end

        if not self._last_vel then
            self._last_vel = vel
            return
        end

        local new_vel = {x = vel.x, y = vel.y, z = vel.z}
        local bounced = false
        local restitution = 0.6 -- How bouncy they are

        -- Player/Mob Repulsion (Diving Effect)
        local objs = minetest.get_objects_inside_radius(pos, 1.5)
        if #objs > 15 then
            self.object:remove()
            return
        end
        for _, obj in ipairs(objs) do
            if obj ~= self.object then
                -- Check if object is a player or a mob (basic entity that isn't a ball)
                local lua_ent = obj:get_luaentity()
                local is_player = obj:is_player()
                local is_mob = lua_ent and lua_ent.name ~= "mine_test_ball_pit:ball_entity"
                local is_ball = lua_ent and lua_ent.name == "mine_test_ball_pit:ball_entity"

                if is_player or is_mob or is_ball then
                    local opos = obj:get_pos()
                    if opos then
                        local dx = pos.x - opos.x
                        local dz = pos.z - opos.z
                        -- Apply a small push away from the object
                        new_vel.x = new_vel.x + dx * 2.0 * dtime
                        new_vel.z = new_vel.z + dz * 2.0 * dtime
                        bounced = true
                    end
                end
            end
        end

        -- If suddenly stopped falling, bounce upwards
        if self._last_vel.y < -0.5 and math.abs(vel.y) < 0.1 then
            new_vel.y = math.abs(self._last_vel.y) * restitution
            bounced = true
        end

        -- If hit a wall horizontally, bounce sideways
        if math.abs(self._last_vel.x) > 0.1 and math.abs(vel.x) < 0.05 then
            new_vel.x = -self._last_vel.x * restitution
            bounced = true
        end

        if math.abs(self._last_vel.z) > 0.1 and math.abs(vel.z) < 0.05 then
            new_vel.z = -self._last_vel.z * restitution
            bounced = true
        end

        -- Also decay velocity slightly for friction
        if not bounced and math.abs(vel.y) < 0.1 then
            new_vel.x = vel.x * 0.95
            new_vel.z = vel.z * 0.95
            if math.abs(new_vel.x) < 0.05 then new_vel.x = 0 end
            if math.abs(new_vel.z) < 0.05 then new_vel.z = 0 end
            if vel.x ~= new_vel.x or vel.z ~= new_vel.z then
                bounced = true
            end
        end

        -- Water Physics (Swimming/Floating)
        local node = minetest.get_node(pos)
        if node and minetest.get_item_group(node.name, "lava") > 0 then
            self.object:remove()
            return
        end
        local in_liquid = false
        if node and minetest.registered_nodes[node.name] then
            local def = minetest.registered_nodes[node.name]
            if def.liquidtype and def.liquidtype ~= "none" then
                in_liquid = true
            end
        end

        if in_liquid then
            self.object:set_acceleration({x = 0, y = 1.0, z = 0})
            -- Dampening drag effect in water
            new_vel.x = new_vel.x * 0.9
            new_vel.y = new_vel.y * 0.9
            new_vel.z = new_vel.z * 0.9
            bounced = true -- force velocity update
        else
            self.object:set_acceleration({x = 0, y = -3.0, z = 0})
        end

        if bounced then
            self.object:set_velocity(new_vel)
        end

        self._last_vel = self.object:get_velocity()
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        if puncher and puncher:is_player() then
            local inv = puncher:get_inventory()
            if inv then
                inv:add_item("main", "mine_test_ball_pit:ball")
            end
        end
        self.object:remove()
    end,
})

minetest.register_node("mine_test_ball_pit:spawner", {
    description = "Ball Pit Spawner",
    tiles = {"ball_spawner.png"},
    groups = {cracky = 3, oddly_breakable_by_hand = 1},
    sounds = nil, -- Explicitly no sound

    on_construct = function(pos)
        local timer = minetest.get_node_timer(pos)
        timer:start(math.random(10, 20) / 10.0) -- 1.0 to 2.0 seconds
    end,

    on_timer = function(pos, elapsed)
        local spawn_pos = {x = pos.x, y = pos.y + 0.6, z = pos.z}
        minetest.add_entity(spawn_pos, "mine_test_ball_pit:ball_entity")

        local timer = minetest.get_node_timer(pos)
        timer:start(math.random(10, 20) / 10.0)
        return true
    end,
})
