local _M = {}

local function ensure_table(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

function _M.begin(route_name)
    if type(ngx.ctx.decision) ~= "table" then
        ngx.ctx.decision = {}
    end

    local d = ngx.ctx.decision

    d.route = route_name or ngx.ctx.route or "unknown"

    d.request = d.request or {
        id = ngx.ctx.request_id,
        method = ngx.req.get_method(),
        uri = ngx.var.uri
    }

    d.routing = d.routing or {}
    d.shadow = d.shadow or {}
    d.auth = d.auth or {}
    d.rate_limit = d.rate_limit or {}
    d.meta = d.meta or {}
    d.timing = d.timing or {
        start_time = ngx.now()
    }

    ensure_table(d, "request")
    ensure_table(d, "routing")
    ensure_table(d, "shadow")
    ensure_table(d, "auth")
    ensure_table(d, "rate_limit")
    ensure_table(d, "meta")
    ensure_table(d, "timing")

    return d
end

function _M.get()
    return _M.begin(ngx.ctx.route)
end

function _M.set_request(fields)
    local d = _M.get()
    local req = d.request

    for k, v in pairs(fields or {}) do
        req[k] = v
    end
end

function _M.set_routing(fields)
    local d = _M.get()
    local routing = d.routing

    for k, v in pairs(fields or {}) do
        routing[k] = v
    end
end

function _M.set_shadow(fields)
    local d = _M.get()
    local shadow = d.shadow

    for k, v in pairs(fields or {}) do
        shadow[k] = v
    end
end

function _M.set_auth(fields)
    local d = _M.get()
    local auth = d.auth

    for k, v in pairs(fields or {}) do
        auth[k] = v
    end
end

function _M.set_rate_limit(fields)
    local d = _M.get()
    local rl = d.rate_limit

    for k, v in pairs(fields or {}) do
        rl[k] = v
    end
end

function _M.set_meta(fields)
    local d = _M.get()
    local meta = d.meta

    for k, v in pairs(fields or {}) do
        meta[k] = v
    end
end

function _M.sync_legacy_ctx()
    local d = _M.get()
    local routing = d.routing or {}
    local shadow = d.shadow or {}

    ngx.ctx.selected_upstream = routing.selected_upstream
    ngx.ctx.traffic_strategy = routing.strategy

    ngx.ctx.canary_mode = routing.canary_mode
    ngx.ctx.canary_hit = routing.canary_hit
    ngx.ctx.canary_reason = routing.canary_reason
    ngx.ctx.canary_percentage = routing.canary_percentage

    ngx.ctx.bg_active_color = routing.bg_active_color
    ngx.ctx.bg_selected_color = routing.bg_selected_color

    ngx.ctx.shadow_eligible = shadow.eligible
    ngx.ctx.shadow_enabled = shadow.enabled
    ngx.ctx.shadow_hit = shadow.hit
    ngx.ctx.shadow_reason = shadow.reason
    ngx.ctx.shadow_sample_rate = shadow.sample_rate
    ngx.ctx.shadow_primary_upstream = shadow.primary_upstream
    ngx.ctx.shadow_upstream = shadow.upstream
    ngx.ctx.shadow_mirror_uri = shadow.mirror_uri
    ngx.ctx.shadow_header_name = shadow.header_name
    ngx.ctx.shadow_header_expected = shadow.header_expected
    ngx.ctx.shadow_header_actual = shadow.header_actual
end

return _M