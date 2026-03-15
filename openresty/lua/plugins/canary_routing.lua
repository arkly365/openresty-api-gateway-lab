local _M = {}

_M.PRIORITY = 115

local route_config = require("route_config")

local function normalize_header_name(header_name)
    if not header_name then
        return nil
    end
    return string.lower(header_name)
end

function _M.access()
    local route_name = ngx.ctx.route
    if not route_name then
        return
    end

    local policy = route_config.get_policy(route_name, "canary")
    if not policy or policy.enabled ~= true then
        return
    end

    local mode = policy.mode or "header"

    local stable_upstream = policy.stable_upstream or route_config.get_upstream(route_name)
    local canary_upstream = policy.canary_upstream

    if not stable_upstream or not canary_upstream then
        ngx.log(ngx.ERR, "[canary_routing] invalid upstream config, route=", tostring(route_name))
        return
    end

    local selected_upstream = stable_upstream
    local canary_hit = false
    local actual_value = ""

    if mode == "header" then
        local header_name = policy.header_name
        local expected_value = policy.header_value

        if not header_name or not expected_value then
            ngx.log(ngx.ERR, "[canary_routing] invalid header policy config, route=", tostring(route_name))
            return
        end

        local headers = ngx.req.get_headers()
        actual_value = headers[header_name] or headers[normalize_header_name(header_name)] or ""

        if tostring(actual_value) == tostring(expected_value) then
            selected_upstream = canary_upstream
            canary_hit = true
        end

        ngx.ctx.canary_header_name = header_name
        ngx.ctx.canary_header_value = tostring(actual_value)

    elseif mode == "percentage" then
        local percentage = tonumber(policy.percentage) or 0

        if percentage < 0 then
            percentage = 0
        end

        if percentage > 100 then
            percentage = 100
        end

        local r = math.random(100)

        if r <= percentage then
            selected_upstream = canary_upstream
            canary_hit = true
        else
            selected_upstream = stable_upstream
            canary_hit = false
        end

        ngx.ctx.canary_percentage = percentage
        ngx.ctx.canary_random_value = r
	
	elseif mode == "hybrid" then
		local header_name = policy.header_name
		local expected_value = policy.header_value
		local percentage = tonumber(policy.percentage) or 0

		if percentage < 0 then
			percentage = 0
		end

		if percentage > 100 then
			percentage = 100
		end

		local headers = ngx.req.get_headers()
		local actual_value = headers[header_name] or headers[string.lower(header_name)] or ""

		if tostring(actual_value) == tostring(expected_value) then
			selected_upstream = canary_upstream
			canary_hit = true
			ngx.ctx.canary_reason = "header"
		else
			local r = math.random(100)
			if r <= percentage then
				selected_upstream = canary_upstream
				canary_hit = true
				ngx.ctx.canary_reason = "percentage"
			else
				selected_upstream = stable_upstream
				canary_hit = false
				ngx.ctx.canary_reason = "stable"
			end
			ngx.ctx.canary_random_value = r
			ngx.ctx.canary_percentage = percentage
		end

		ngx.ctx.canary_header_name = header_name
		ngx.ctx.canary_header_value = tostring(actual_value)

    else
        ngx.log(ngx.ERR, "[canary_routing] unsupported mode: ", tostring(mode))
        return
    end

    ngx.ctx.selected_upstream = selected_upstream
    ngx.ctx.canary_hit = canary_hit
    ngx.ctx.canary_mode = mode

    ngx.log(
        ngx.INFO,
        "[canary_routing] route=", tostring(route_name),
        ", mode=", tostring(mode),
        ", canary_hit=", tostring(canary_hit),
        ", selected_upstream=", tostring(selected_upstream)
    )
end

return _M