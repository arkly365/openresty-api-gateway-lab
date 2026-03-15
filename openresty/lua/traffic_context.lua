local _M = {}

local function ensure_table(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

function _M.ensure()
    if type(ngx.ctx.traffic_decision) ~= "table" then
        ngx.ctx.traffic_decision = {}
    end

    local td = ngx.ctx.traffic_decision
    ensure_table(td, "routing")
    ensure_table(td, "shadow")

    local routing = td.routing
    ensure_table(routing, "weighted")
    ensure_table(routing, "canary")
    ensure_table(routing, "blue_green")

    return td
end

function _M.begin(route_name)
    local td = _M.ensure()
    td.route = route_name or ngx.ctx.route or "unknown"
    return td
end

function _M.get()
    return _M.ensure()
end

function _M.set_routing_base(fields)
    local td = _M.ensure()
    local routing = td.routing

    if fields.strategy ~= nil then
        routing.strategy = fields.strategy
    end
    if fields.selected_upstream ~= nil then
        routing.selected_upstream = fields.selected_upstream
    end
    if fields.default_upstream ~= nil then
        routing.default_upstream = fields.default_upstream
    end
    if fields.reason ~= nil then
        routing.reason = fields.reason
    end

    return td
end

function _M.set_weighted(fields)
    local td = _M.ensure()
    local weighted = td.routing.weighted

    if fields.mode ~= nil then
        weighted.mode = fields.mode
    end
    if fields.target_count ~= nil then
        weighted.target_count = fields.target_count
    end

    return td
end

function _M.set_canary(fields)
    local td = _M.ensure()
    local canary = td.routing.canary

    if fields.mode ~= nil then
        canary.mode = fields.mode
    end
    if fields.hit ~= nil then
        canary.hit = fields.hit
    end
    if fields.reason ~= nil then
        canary.reason = fields.reason
    end
    if fields.percentage ~= nil then
        canary.percentage = fields.percentage
    end

    return td
end

function _M.set_blue_green(fields)
    local td = _M.ensure()
    local bg = td.routing.blue_green

    if fields.active_color ~= nil then
        bg.active_color = fields.active_color
    end
    if fields.selected_color ~= nil then
        bg.selected_color = fields.selected_color
    end

    return td
end

function _M.set_shadow(fields)
    local td = _M.ensure()
    local shadow = td.shadow

    if fields.eligible ~= nil then
        shadow.eligible = fields.eligible
    end
    if fields.enabled ~= nil then
        shadow.enabled = fields.enabled
    end
    if fields.hit ~= nil then
        shadow.hit = fields.hit
    end
    if fields.reason ~= nil then
        shadow.reason = fields.reason
    end
    if fields.sample_rate ~= nil then
        shadow.sample_rate = fields.sample_rate
    end
    if fields.primary_upstream ~= nil then
        shadow.primary_upstream = fields.primary_upstream
    end
    if fields.shadow_upstream ~= nil then
        shadow.shadow_upstream = fields.shadow_upstream
    end
    if fields.mirror_uri ~= nil then
        shadow.mirror_uri = fields.mirror_uri
    end
    if fields.header_name ~= nil then
        shadow.header_name = fields.header_name
    end
    if fields.header_expected ~= nil then
        shadow.header_expected = fields.header_expected
    end
    if fields.header_actual ~= nil then
        shadow.header_actual = fields.header_actual
    end

    return td
end

function _M.export_legacy_ctx()
    local td = _M.ensure()
    local routing = td.routing or {}
    local canary = routing.canary or {}
    local bg = routing.blue_green or {}
    local shadow = td.shadow or {}

    ngx.ctx.selected_upstream = routing.selected_upstream
    ngx.ctx.traffic_strategy = routing.strategy

    ngx.ctx.canary_mode = canary.mode
    ngx.ctx.canary_hit = canary.hit
    ngx.ctx.canary_reason = canary.reason
    ngx.ctx.canary_percentage = canary.percentage

    ngx.ctx.bg_active_color = bg.active_color
    ngx.ctx.bg_selected_color = bg.selected_color

    ngx.ctx.shadow_eligible = shadow.eligible
    ngx.ctx.shadow_enabled = shadow.enabled
    ngx.ctx.shadow_hit = shadow.hit
    ngx.ctx.shadow_reason = shadow.reason
    ngx.ctx.shadow_sample_rate = shadow.sample_rate
    ngx.ctx.shadow_primary_upstream = shadow.primary_upstream
    ngx.ctx.shadow_upstream = shadow.shadow_upstream
    ngx.ctx.shadow_mirror_uri = shadow.mirror_uri
    ngx.ctx.shadow_header_name = shadow.header_name
    ngx.ctx.shadow_header_expected = shadow.header_expected
    ngx.ctx.shadow_header_actual = shadow.header_actual
end

return _M