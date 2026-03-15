local _M = {}

_M.PRIORITY = 10

local http = require("resty.http")
local metrics = require("plugins.metrics")

local function clone_headers(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end

    for k, v in pairs(src) do
        local key = tostring(k)
        local lower = string.lower(key)

        if lower ~= "host"
            and lower ~= "connection"
            and lower ~= "content-length"
            and lower ~= "transfer-encoding"
        then
            out[key] = v
        end
    end

    return out
end

local function send_shadow(premature, data)
    if premature then
        return
    end

    local httpc = http.new()
    httpc:set_timeout(2000)

    local start_time = ngx.now()

    local res, err = httpc:request_uri(data.url, {
        method = data.method,
        headers = data.headers,
        body = data.body,
        keepalive = false,
    })

    local latency_ms = (ngx.now() - start_time) * 1000
    if latency_ms < 0 then
        latency_ms = 0
    end

    if not res then
        ngx.log(
            ngx.ERR,
            "[shadow_executor] request failed, route=", tostring(data.route),
            ", shadow_upstream=", tostring(data.shadow_upstream),
            ", err=", tostring(err)
        )

        metrics.record_shadow_mirror_result(
            data.route,
            data.shadow_upstream,
            0,
            latency_ms,
            "network_error"
        )
        return
    end

    ngx.log(
        ngx.INFO,
        "[shadow_executor] request success, route=", tostring(data.route),
        ", shadow_upstream=", tostring(data.shadow_upstream),
        ", status=", tostring(res.status),
        ", latency_ms=", tostring(latency_ms)
    )

    metrics.record_shadow_mirror_result(
        data.route,
        data.shadow_upstream,
        res.status,
        latency_ms,
        nil
    )
end

function _M.log()
    local td = ngx.ctx.traffic_decision or {}
    local shadow = td.shadow or {}

    local shadow_enabled = shadow.enabled
    if shadow_enabled ~= true then
        shadow_enabled = ngx.ctx.shadow_enabled
    end

    if shadow_enabled ~= true then
        return
    end

    local shadow_upstream = shadow.shadow_upstream or ngx.ctx.shadow_upstream or "backend_echo"
    local route_name = td.route or ngx.ctx.route or "unknown"
    local shadow_url = "http://" .. shadow_upstream .. "/"

    local headers = clone_headers(ngx.req.get_headers())
    headers["X-Shadow-Request"] = "1"
    headers["X-Shadow-Parent-Route"] = route_name

    local method = ngx.req.get_method()
    local body = nil

    if method == "POST" or method == "PUT" or method == "PATCH" then
        ngx.req.read_body()
        body = ngx.req.get_body_data()
    end

    local ok, err = ngx.timer.at(0, send_shadow, {
        route = route_name,
        shadow_upstream = shadow_upstream,
        url = shadow_url,
        method = method,
        headers = headers,
        body = body
    })

    if not ok then
        ngx.log(ngx.ERR, "[shadow_executor] failed to create timer: ", err)

        metrics.record_shadow_mirror_result(
            route_name,
            shadow_upstream,
            0,
            0,
            "timer_create_failed"
        )
    end
end

return _M