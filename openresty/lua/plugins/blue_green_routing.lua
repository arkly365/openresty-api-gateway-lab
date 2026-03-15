local _M = {}

_M.PRIORITY = 118

local route_config = require("route_config")

function _M.access()
    local route_name = ngx.ctx.route
    if not route_name then
        return
    end

    local policy = route_config.get_policy(route_name, "blue_green")
    if not policy or policy.enabled ~= true then
        return
    end

    local active_color = policy.active_color
    local blue_upstream = policy.blue_upstream
    local green_upstream = policy.green_upstream

    if not active_color or not blue_upstream or not green_upstream then
        ngx.log(ngx.ERR, "[blue_green_routing] invalid policy config, route=", tostring(route_name))
        return
    end

    local selected_upstream
    local selected_color

    if active_color == "blue" then
        selected_upstream = blue_upstream
        selected_color = "blue"
    elseif active_color == "green" then
        selected_upstream = green_upstream
        selected_color = "green"
    else
        ngx.log(ngx.ERR, "[blue_green_routing] unsupported active_color: ", tostring(active_color))
        return
    end

    ngx.ctx.selected_upstream = selected_upstream
    ngx.ctx.bg_active_color = active_color
    ngx.ctx.bg_selected_color = selected_color

    ngx.log(
        ngx.INFO,
        "[blue_green_routing] route=", tostring(route_name),
        ", active_color=", tostring(active_color),
        ", selected_color=", tostring(selected_color),
        ", selected_upstream=", tostring(selected_upstream)
    )
end

return _M