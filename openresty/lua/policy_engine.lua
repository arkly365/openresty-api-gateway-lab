local _M = {}

local route_config = require("route_config")

local function deepcopy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end

    local out = {}
    for k, v in pairs(tbl) do
        out[k] = deepcopy(v)
    end
    return out
end

local function normalize_traffic_policy(route_name, policies)
    local traffic = policies.traffic
    if type(traffic) ~= "table" then
        return nil
    end

    local normalized = deepcopy(traffic)

    normalized.enabled = normalized.enabled ~= false

    normalized.routing = normalized.routing or {
        strategy = "direct",
        primary_upstream = route_config.get_upstream(route_name)
    }

    normalized.shadow = normalized.shadow or {
        enabled = false
    }

    if not normalized.routing.primary_upstream then
        normalized.routing.primary_upstream = route_config.get_upstream(route_name)
    end

    return normalized
end

function _M.get_route_bundle(route_name)
    local route = route_config.get_route(route_name)
    if not route then
        return nil, "route_not_found"
    end

    local policies = route_config.get_policies(route_name) or {}

    local bundle = {
        route_name = route_name,
        route = route,
        plugins = route.plugins or {},
        policies = deepcopy(policies),
        traffic = normalize_traffic_policy(route_name, policies)
    }

    return bundle
end

function _M.get_traffic_policy(route_name)
    local bundle, err = _M.get_route_bundle(route_name)
    if not bundle then
        return nil, err
    end
    return bundle.traffic
end

function _M.get_routing_policy(route_name)
    local traffic = _M.get_traffic_policy(route_name)
    if not traffic then
        return nil
    end
    return traffic.routing
end

function _M.get_shadow_policy(route_name)
    local traffic = _M.get_traffic_policy(route_name)
    if not traffic then
        return nil
    end
    return traffic.shadow
end

function _M.validate_traffic_policy(route_name)
    local traffic = _M.get_traffic_policy(route_name)
    if not traffic then
        return true, nil
    end

    local routing = traffic.routing or {}
    local strategy = routing.strategy or "direct"

    if strategy ~= "direct"
        and strategy ~= "weighted"
        and strategy ~= "canary"
        and strategy ~= "blue_green" then
        return false, "invalid_routing_strategy"
    end

    if strategy == "weighted" then
        local targets = ((routing.weighted or {}).targets or {})
        if #targets == 0 then
            return false, "weighted_targets_empty"
        end
    end

    if strategy == "canary" then
        local canary = routing.canary or {}
        if not canary.stable_upstream or not canary.canary_upstream then
            return false, "canary_upstream_missing"
        end
    end

    if strategy == "blue_green" then
        local bg = routing.blue_green or {}
        if type(bg.mappings) ~= "table" then
            return false, "blue_green_mappings_missing"
        end
    end

    return true, nil
end

return _M