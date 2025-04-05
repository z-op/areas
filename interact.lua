local S = minetest.get_translator("areas")
local protector_flip = minetest.settings:get_bool("protector_flip") or true
local protector_hurt = tonumber(minetest.settings:get("protector_hurt")) or 1

if areas.awards_available then
	awards.register_award("award_wall_by_head", {
		title = S("Breaks head by wall"),
		description = S("Die by areas violation"),
		secret = true,
	})
end


local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
	if not areas:canInteract(pos, name) then
		return true
	end
	return old_is_protected(pos, name)
end

minetest.register_on_protection_violation(function(pos, name)
	if not areas:canInteract(pos, name) then
		local owners = areas:getNodeOwners(pos)
		local player = minetest.get_player_by_name(name)
		minetest.chat_send_player(name,S("@1 is protected by @2.",minetest.pos_to_string(pos),table.concat(owners, ", ")))
		if player and player:is_player() then
			-- hurt player if protection violated
			if protector_hurt > 0 and player:get_hp() > 0 then
				if player:get_hp() > 2 then
					player:set_hp("2")
				end
				if areas.awards_available and (player:get_hp() - protector_hurt) <= 0 then
					awards.unlock(name, "award_wall_by_head")
				end
				-- This delay fixes item duplication bug (thanks luk3yx)
				minetest.after(0.1, function(p)
				p:set_hp(p:get_hp() - protector_hurt)
				end, player)

			end
			-- flip player when protection violated
			if protector_flip then
				-- yaw + 180°
				local yaw = player:get_look_horizontal() + math.pi
				if yaw > 2 * math.pi then
					yaw = yaw - 2 * math.pi
				end
				player:set_look_horizontal(yaw)
				-- invert pitch
				player:set_look_vertical(-player:get_look_vertical())
				-- if digging below player, move up to avoid falling through hole
				local pla_pos = player:get_pos()
				if pos.y < pla_pos.y then
					player:set_pos({
						x = pla_pos.x,
						y = pla_pos.y + 0.8,
						z = pla_pos.z
					})
				end
			end
		end
	end
end)
