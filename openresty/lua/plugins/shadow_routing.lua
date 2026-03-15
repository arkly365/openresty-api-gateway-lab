local _M = {}

_M.PRIORITY = 117

local route_config = require("route_config")
local policy_engine = require("policy_engine")
local traffic_ctx = require("traffic_context")
local decision_ctx = require("decision_context")

local function normalize_method_list(methods)
    if type(methods) ~= "table" then
        return nil
    end

    local map = {}
    for _, m in ipairs(methods) do
        if m then
            map[string.upper(tostring(m))] = true
        end
    end
    return map
end

local function method_allowed(policy)
    local methods = normalize_method_list(policy.methods)
    if not methods then
        return true
    end

    local req_method = string.upper(ngx.req.get_method() or "")
    return methods[req_method] == true
end

local function headers_match(policy)
    local header_match = policy.header_match
    if type(header_match) ~= "table" then
        return true
    end

    local headers = ngx.req.get_headers()
    for name, expected in pairs(header_match) do
        local actual = headers[name]
        if tostring(actual or "") ~= tostring(expected) then
            return false, name, expected, actual
        end
    end

    return true
end

local function sample_hit(policy)
    local rate = tonumber(policy.sample_rate)

    if rate == nil then
        rate = 1
    end

    if rate < 0 then
        rate = 0
    elseif rate > 1 then
        rate = 1
    end

    if rate == 0 then
        return false, rate
    end

    if rate == 1 then
        return true, rate
    end

    local r = math.random()
    return r < rate, rate
end

local function set_shadow_decision(data)
    decision_ctx.set_shadow(data)
    traffic_ctx.set_shadow({
        eligible = data.eligible,
        enabled = data.enabled,
        hit = data.hit,
        reason = data.reason,
        sample_rate = data.sample_rate,
        primary_upstream = data.primary_upstream,
        shadow_upstream = data.upstream,
        mirror_uri = data.mirror_uri,
        header_name = data.header_name,
        header_expected = data.header_expected,
        header_actual = data.header_actual
    })
end

function _M.access()
    local route_name = ngx.ctx.route
    if not route_name then
        return
    end

    decision_ctx.begin(route_name)
    traffic_ctx.begin(route_name)

    local policy = policy_engine.get_shadow_policy(route_name)
    if type(policy) ~= "table" then
        return
    end

    local d = decision_ctx.get()
    local routing = d.routing or {}

    local primary_upstream = routing.selected_upstream
        or routing.default_upstream
        or route_config.get_upstream(route_name)

    local shadow_upstream = policy.upstream or policy.shadow_upstream

    set_shadow_decision({
        eligible = false,
        enabled = false,
        hit = false,
        reason = nil,
        sample_rate = tonumber(policy.sample_rate) or 1,
        primary_upstream = primary_upstream,
        upstream = shadow_upstream,
        mirror_uri = nil
    })

    if policy.enabled == false then
        set_shadow_decision({
            eligible = false,
            enabled = false,
            hit = false,
            reason = "disabled",
            sample_rate = tonumber(policy.sample_rate) or 1,
            primary_upstream = primary_upstream,
            upstream = shadow_upstream,
            mirror_uri = nil
        })
        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    if not primary_upstream or primary_upstream == "" then
        set_shadow_decision({
            eligible = false,
            enabled = false,
            hit = false,
            reason = "missing_primary",
            sample_rate = tonumber(policy.sample_rate) or 1,
            primary_upstream = primary_upstream,
            upstream = shadow_upstream,
            mirror_uri = nil
        })
        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    if not shadow_upstream or shadow_upstream == "" then
        set_shadow_decision({
            eligible = false,
            enabled = false,
            hit = false,
            reason = "missing_shadow_upstream",
            sample_rate = tonumber(policy.sample_rate) or 1,
            primary_upstream = primary_upstream,
            upstream = shadow_upstream,
            mirror_uri = nil
        })
        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    if not method_allowed(policy) then
        set_shadow_decision({
            eligible = false,
            enabled = false,
            hit = false,
            reason = "method_not_allowed",
            sample_rate = tonumber(policy.sample_rate) or 1,
            primary_upstream = primary_upstream,
            upstream = shadow_upstream,
            mirror_uri = nil
        })
        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    local ok, header_name, expected, actual = headers_match(policy)
    if not ok then
        set_shadow_decision({
            eligible = false,
            enabled = false,
            hit = false,
            reason = "header_not_match",
            sample_rate = tonumber(policy.sample_rate) or 1,
            primary_upstream = primary_upstream,
            upstream = shadow_upstream,
            mirror_uri = nil,
            header_name = header_name,
            header_expected = tostring(expected or ""),
            header_actual = tostring(actual or "")
        })
        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    local hit, applied_rate = sample_hit(policy)

    if not hit then
        set_shadow_decision({
            eligible = true,
            enabled = false,
            hit = false,
            reason = "sample_skip",
            sample_rate = applied_rate,
            primary_upstream = primary_upstream,
            upstream = shadow_upstream,
            mirror_uri = nil
        })
        traffic_ctx.export_legacy_ctx()
        decision_ctx.sync_legacy_ctx()
        return
    end

    set_shadow_decision({
        eligible = true,
        enabled = true,
        hit = true,
        reason = "sampled",
        sample_rate = applied_rate,
        primary_upstream = primary_upstream,
        upstream = shadow_upstream,
        mirror_uri = "/__shadow_mirror__"
    })

    traffic_ctx.export_legacy_ctx()
    decision_ctx.sync_legacy_ctx()

    ngx.log(
        ngx.INFO,
        "[shadow_routing] route=", tostring(route_name),
        ", primary_upstream=", tostring(primary_upstream),
        ", shadow_upstream=", tostring(shadow_upstream),
        ", sample_rate=", tostring(applied_rate),
        ", reason=sampled"
    )
end

return _M