local _M = {}

_M.PRIORITY = 125

local route_config = require("route_config")
local policy_engine = require("policy_engine")
local traffic_ctx = require("traffic_context")
local decision_ctx = require("decision_context")

local function weighted_pick(targets)
    if type(targets) ~= "table" or #targets == 0 then
        return nil
    end

    local total = 0
    for _, item in ipairs(targets) do
        local weight = tonumber(item.weight) or 0
        if weight > 0 then
            total = total + weight
        end
    end

    if total <= 0 then
        return nil
    end

    local r = math.random(total)
    local acc = 0

    for _, item in ipairs(targets) do
        local weight = tonumber(item.weight) or 0
        if weight > 0 then
            acc = acc + weight
            if r <= acc then
                return item.upstream
            end
        end
    end

    return targets[1] and targets[1].upstream or nil
end

local function canary_by_header(canary_policy)
    local header = canary_policy.header or {}
    local header_name = header.name
    local header_value = header.value

    if not header_name then
        return false
    end

    local actual = ngx.req.get_headers()[header_name]
    if actual == nil then
        return false
    end

    return tostring(actual) == tostring(header_value)
end

local function canary_by_percentage(canary_policy)
    local pct = tonumber(canary_policy.percentage) or 0

    if pct <= 0 then
        return false
    end

    if pct >= 100 then
        return true
    end

    local r = math.random(100)
    return r <= pct
end

local function set_routing_decision(data)
    decision_ctx.set_routing(data)
    traffic_ctx.set_routing_base({
        strategy = data.strategy,
        selected_upstream = data.selected_upstream,
        default_upstream = data.default_upstream,
        reason = data.reason
    })
end

local function apply_direct(route_name, routing_policy)
    local default_upstream = routing_policy.primary_upstream or route_config.get_upstream(route_name)
    local selected = default_upstream

    set_routing_decision({
        strategy = "direct",
        selected_upstream = selected,
        default_upstream = default_upstream,
        reason = "direct_primary"
    })
end

local function apply_weighted(route_name, routing_policy)
    local weighted = routing_policy.weighted or {}
    local targets = weighted.targets or {}
    local default_upstream = routing_policy.primary_upstream or route_config.get_upstream(route_name)

    local selected = weighted_pick(targets)
    if not selected then
        selected = default_upstream
    end

    set_routing_decision({
        strategy = "weighted",
        selected_upstream = selected,
        default_upstream = default_upstream,
        reason = "weighted_random",
        weighted_mode = weighted.mode or "random",
        weighted_target_count = #targets
    })

    traffic_ctx.set_weighted({
        mode = weighted.mode or "random",
        target_count = #targets
    })
end

local function apply_canary(route_name, routing_policy)
    local canary = routing_policy.canary or {}
    local mode = canary.mode or "header"

    local default_upstream = canary.stable_upstream
        or routing_policy.primary_upstream
        or route_config.get_upstream(route_name)

    local canary_upstream = canary.canary_upstream

    local hit = false
    local reason = "stable"

    if mode == "header" then
        hit = canary_by_header(canary)
        reason = hit and "header_match" or "header_not_match"
    elseif mode == "percentage" then
        hit = canary_by_percentage(canary)
        reason = hit and "percentage_hit" or "percentage_miss"
    elseif mode == "hybrid" then
        local header_hit = canary_by_header(canary)
        if header_hit then
            hit = true
            reason = "header_match"
        else
            hit = canary_by_percentage(canary)
            reason = hit and "percentage_hit" or "hybrid_miss"
        end
    else
        hit = false
        reason = "unknown_mode"
    end

    local selected = default_upstream
    if hit and canary_upstream then
        selected = canary_upstream
    end

    set_routing_decision({
        strategy = "canary",
        selected_upstream = selected,
        default_upstream = default_upstream,
        reason = reason,
        canary_mode = mode,
        canary_hit = hit,
        canary_reason = reason,
        canary_percentage = tonumber(canary.percentage) or 0
    })

    traffic_ctx.set_canary({
        mode = mode,
        hit = hit,
        reason = reason,
        percentage = tonumber(canary.percentage) or 0
    })
end

local function apply_blue_green(route_name, routing_policy)
    local bg = routing_policy.blue_green or {}
    local active_color = bg.active_color or "blue"
    local mappings = bg.mappings or {}

    local default_upstream = routing_policy.primary_upstream or route_config.get_upstream(route_name)
    local selected = mappings[active_color]

    if not selected or selected == "" then
        selected = default_upstream
    end

    set_routing_decision({
        strategy = "blue_green",
        selected_upstream = selected,
        default_upstream = default_upstream,
        reason = "active_color_" .. tostring(active_color),
        bg_active_color = active_color,
        bg_selected_color = active_color
    })

    traffic_ctx.set_blue_green({
        active_color = active_color,
        selected_color = active_color
    })
end

function _M.access()
    local route_name = ngx.ctx.route
    if not route_name then
        return
    end

    decision_ctx.begin(route_name)
    decision_ctx.set_request({
        id = ngx.ctx.request_id,
        method = ngx.req.get_method(),
        uri = ngx.var.uri
    })

    traffic_ctx.begin(route_name)

    local ok, reason = policy_engine.validate_traffic_policy(route_name)
    if not ok then
        ngx.log(ngx.ERR, "[traffic_router] invalid traffic policy, route=", route_name, ", reason=", tostring(reason))
        local default_upstream = route_config.get_upstream(route_name)

        set_routing_decision({
            strategy = "invalid",
            selected_upstream = default_upstream,
            default_upstream = default_upstream,
            reason = reason
        })

        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    local traffic = policy_engine.get_traffic_policy(route_name)
    if type(traffic) ~= "table" then
        local default_upstream = route_config.get_upstream(route_name)

        set_routing_decision({
            strategy = "default",
            selected_upstream = default_upstream,
            default_upstream = default_upstream,
            reason = "route_default"
        })

        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    if traffic.enabled == false then
        local default_upstream = route_config.get_upstream(route_name)

        set_routing_decision({
            strategy = "disabled",
            selected_upstream = default_upstream,
            default_upstream = default_upstream,
            reason = "traffic_disabled"
        })

        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    local routing = policy_engine.get_routing_policy(route_name) or {}
    local strategy = routing.strategy or "direct"

    if strategy == "weighted" then
        apply_weighted(route_name, routing)
    elseif strategy == "canary" then
        apply_canary(route_name, routing)
    elseif strategy == "blue_green" then
        apply_blue_green(route_name, routing)
    else
        apply_direct(route_name, routing)
    end

    traffic_ctx.export_legacy_ctx()
    decision_ctx.sync_legacy_ctx()

    ngx.log(
        ngx.INFO,
        "[traffic_router] route=", tostring(route_name),
        ", strategy=", tostring(strategy),
        ", selected_upstream=", tostring(ngx.ctx.selected_upstream)
    )
end

return _M