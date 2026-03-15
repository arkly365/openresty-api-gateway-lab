local cjson = require("cjson.safe")
local decision_ctx = require("decision_context")

local _M = {}
_M.PRIORITY = 1

function _M.access()
    local d = decision_ctx.get()
    local routing = d.routing or {}
    local shadow = d.shadow or {}

    local log_obj = {
        phase = "access",
        request_id = ngx.ctx.request_id,
        route = d.route or ngx.ctx.route or "-",
        uri = ngx.var.uri,
        method = ngx.req.get_method(),
        status = 0,
        remote_addr = ngx.var.remote_addr,
        request_time = "0.000",
        upstream_status = "-",
        upstream_response_time = "-",
        selected_upstream = routing.selected_upstream or ngx.ctx.selected_upstream,
        traffic_strategy = routing.strategy or ngx.ctx.traffic_strategy,
        shadow_enabled = shadow.enabled,
        shadow_upstream = shadow.upstream
    }

    ngx.log(ngx.INFO, "[logger] ", cjson.encode(log_obj))
end

function _M.log()
    local d = decision_ctx.get()
    local routing = d.routing or {}
    local shadow = d.shadow or {}

    local log_obj = {
        phase = "log",
        request_id = ngx.ctx.request_id,
        route = d.route or ngx.ctx.route or "-",
        uri = ngx.var.uri,
        method = ngx.req.get_method(),
        status = ngx.status,
        remote_addr = ngx.var.remote_addr,
        request_time = tostring(ngx.var.request_time or "-"),
        upstream_status = tostring(ngx.var.upstream_status or "-"),
        upstream_response_time = tostring(ngx.var.upstream_response_time or "-"),
        selected_upstream = routing.selected_upstream or ngx.ctx.selected_upstream,
        traffic_strategy = routing.strategy or ngx.ctx.traffic_strategy,
        shadow_enabled = shadow.enabled,
        shadow_upstream = shadow.upstream
    }

    ngx.log(ngx.INFO, "[logger] ", cjson.encode(log_obj))
end

return _M