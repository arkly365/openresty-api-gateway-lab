local _M = {}

_M.PRIORITY = 110

local route_config = require("route_config")

local function pick_by_weight(targets)
    local total = 0

    for _, target in ipairs(targets) do
        local weight = tonumber(target.weight) or 0
        if weight > 0 then
            total = total + weight
        end
    end

    if total <= 0 then
        return nil, "invalid total weight"
    end

    local r = math.random(total)
    local acc = 0

    for _, target in ipairs(targets) do
        local weight = tonumber(target.weight) or 0
        if weight > 0 then
            acc = acc + weight
            if r <= acc then
                return target.upstream
            end
        end
    end

    return nil, "no upstream selected"
end

function _M.access()
    local route_name = ngx.ctx.route
    if not route_name then
        return
    end

    local policy = route_config.get_policy(route_name, "weighted_routing")
    if not policy or policy.enabled ~= true then
        return
    end

    local mode = policy.mode or "random"
    local targets = policy.targets

    if mode ~= "random" then
        ngx.log(ngx.ERR, "[weighted_routing] unsupported mode: ", tostring(mode))
        return
    end

    if type(targets) ~= "table" or #targets == 0 then
        ngx.log(ngx.ERR, "[weighted_routing] empty targets, route=", tostring(route_name))
        return
    end

    local selected_upstream, err = pick_by_weight(targets)
    if not selected_upstream then
        ngx.log(ngx.ERR, "[weighted_routing] select upstream failed, route=", tostring(route_name), ", err=", tostring(err))
        return
    end

    ngx.ctx.selected_upstream = selected_upstream
    ngx.ctx.weighted_route_enabled = true
    ngx.ctx.weighted_route_mode = mode

    ngx.log(ngx.INFO,
        "[weighted_routing] route=", tostring(route_name),
        ", mode=", tostring(mode),
        ", selected_upstream=", tostring(selected_upstream)
    )
end

return _M