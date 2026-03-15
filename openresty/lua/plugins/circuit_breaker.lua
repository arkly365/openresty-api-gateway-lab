-- openresty/lua/plugins/circuit_breaker.lua
local _M = {
    PRIORITY = 950
}

local ngx = ngx
local tostring = tostring
local tonumber = tonumber
local type = type

local route_config = require("route_config")
local my_redis = require("my_redis")

local function get_current_route()
    return ngx.ctx.route
end

local function get_cb_policy(route_name)
    if not route_name then
        return nil
    end

    local policy = route_config.get_policy(route_name, "circuit_breaker")
    if not policy then
        return nil
    end

    if policy.enabled == false then
        return nil
    end

    return policy
end

local function redis_connect()
    if type(my_redis.connect) == "function" then
        return my_redis.connect()
    end

    if type(my_redis.get_client) == "function" then
        return my_redis.get_client()
    end

    return nil, "my_redis does not expose connect() or get_client()"
end

local function redis_close(red)
    if not red then
        return
    end

    local ok, err = red:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.ERR, "[circuit_breaker] redis keepalive failed: ", err or "unknown")
    end
end

local function cb_key_state(route_name)
    return "gateway:cb:" .. route_name .. ":state"
end

local function cb_key_fail_count(route_name)
    return "gateway:cb:" .. route_name .. ":fail_count"
end

local function cb_key_opened_at(route_name)
    return "gateway:cb:" .. route_name .. ":opened_at"
end

local function get_state(red, route_name)
    local state, err = red:get(cb_key_state(route_name))
    if err then
        return nil, err
    end

    if not state or state == ngx.null then
        return "CLOSED", nil
    end

    return tostring(state), nil
end

local function set_state(red, route_name, state, ttl)
    local ok, err = red:set(cb_key_state(route_name), state)
    if not ok then
        return nil, err
    end

    if ttl and ttl > 0 then
        red:expire(cb_key_state(route_name), ttl)
    end

    return true
end

local function get_opened_at(red, route_name)
    local value, err = red:get(cb_key_opened_at(route_name))
    if err then
        return nil, err
    end

    if not value or value == ngx.null then
        return 0, nil
    end

    return tonumber(value) or 0, nil
end

local function set_opened_at(red, route_name, ts, ttl)
    local ok, err = red:set(cb_key_opened_at(route_name), ts)
    if not ok then
        return nil, err
    end

    if ttl and ttl > 0 then
        red:expire(cb_key_opened_at(route_name), ttl)
    end

    return true
end

local function incr_fail_count(red, route_name, window)
    local count, err = red:incr(cb_key_fail_count(route_name))
    if not count then
        return nil, err
    end

    red:expire(cb_key_fail_count(route_name), window)
    return tonumber(count), nil
end

local function reset_fail_count(red, route_name)
    red:del(cb_key_fail_count(route_name))
end

local function is_failure(upstream_status, final_status)
    local status = tonumber(upstream_status) or tonumber(final_status)

    if not status then
        return true
    end

    if status == 502 or status == 503 or status == 504 then
        return true
    end

    return false
end

local function is_success(upstream_status, final_status)
    local status = tonumber(upstream_status) or tonumber(final_status)

    if not status then
        return false
    end

    return status >= 200 and status < 500
end

function _M.access()
    local route_name = get_current_route()
    if route_name ~= "svc_failover" then
        return
    end

    local policy = get_cb_policy(route_name)
    if not policy then
        return
    end

    ngx.ctx.cb_route = route_name
    ngx.ctx.cb_state = "CLOSED"
    ngx.ctx.cb_force_fallback = false
    ngx.ctx.cb_upstream_mode = "primary"

    local red, err = redis_connect()
    if not red then
        ngx.log(ngx.ERR, "[circuit_breaker] redis connect failed: ", err or "unknown")
        return
    end

    local state, state_err = get_state(red, route_name)
    if state_err then
        ngx.log(ngx.ERR, "[circuit_breaker] get_state failed: ", state_err)
        redis_close(red)
        return
    end

    if state == "OPEN" then
        local opened_at, opened_err = get_opened_at(red, route_name)
        if opened_err then
            ngx.log(ngx.ERR, "[circuit_breaker] get_opened_at failed: ", opened_err)
            redis_close(red)
            return
        end

        local now = ngx.time()
        local recovery_timeout = tonumber(policy.recovery_timeout) or 15

        if now - opened_at >= recovery_timeout then
            set_state(red, route_name, "HALF_OPEN", recovery_timeout + 60)
            ngx.ctx.cb_state = "HALF_OPEN"
            ngx.ctx.cb_force_fallback = false
            ngx.ctx.cb_upstream_mode = "half_open_probe"

            ngx.log(ngx.WARN,
                "[circuit_breaker] route=", route_name,
                ", action=OPEN_TO_HALF_OPEN",
                ", recovery_timeout=", tostring(recovery_timeout)
            )
        else
            ngx.ctx.cb_state = "OPEN"
            ngx.ctx.cb_force_fallback = true
            ngx.ctx.cb_upstream_mode = "fallback"

            ngx.log(ngx.WARN,
                "[circuit_breaker] route=", route_name,
                ", action=SKIP_PRIMARY_FALLBACK",
                ", state=OPEN"
            )
        end
    else
        ngx.ctx.cb_state = state or "CLOSED"
        ngx.ctx.cb_force_fallback = false
        ngx.ctx.cb_upstream_mode = "primary"
    end

    redis_close(red)
end

function _M.header_filter()
    local route_name = ngx.ctx.cb_route
    if not route_name then
        return
    end

    ngx.header["X-CB-Route"] = route_name
    ngx.header["X-CB-State"] = tostring(ngx.ctx.cb_state or "UNKNOWN")
    ngx.header["X-CB-Fallback"] = tostring(ngx.ctx.cb_force_fallback == true)
    ngx.header["X-CB-Upstream-Mode"] = tostring(ngx.ctx.cb_upstream_mode or "unknown")
end

local function update_breaker_state(premature, params)
    if premature then
        return
    end

    local route_name = params.route_name
    local upstream_status = params.upstream_status
    local final_status = params.final_status
    local cb_state = params.cb_state
    local cb_force_fallback = params.cb_force_fallback
    local cb_upstream_mode = params.cb_upstream_mode
    local failure_window = params.failure_window
    local failure_threshold = params.failure_threshold
    local recovery_timeout = params.recovery_timeout

    local red, err = redis_connect()
    if not red then
        ngx.log(ngx.ERR, "[circuit_breaker] timer redis connect failed: ", err or "unknown")
        return
    end

    local current_state, state_err = get_state(red, route_name)
    if state_err then
        ngx.log(ngx.ERR, "[circuit_breaker] timer get_state failed: ", state_err)
        redis_close(red)
        return
    end

    if cb_state then
        current_state = cb_state
    end

    if is_success(upstream_status, final_status) then
        reset_fail_count(red, route_name)
        set_state(red, route_name, "CLOSED", failure_window + 60)
        set_opened_at(red, route_name, 0, failure_window + 60)

        ngx.log(ngx.INFO,
            "[circuit_breaker] route=", route_name,
            ", result=success",
            ", http_status=", tostring(final_status),
            ", upstream_status=", tostring(upstream_status),
            ", request_state=", tostring(current_state),
            ", fallback=", tostring(cb_force_fallback),
            ", upstream_mode=", tostring(cb_upstream_mode),
            " -> CLOSED"
        )

    elseif is_failure(upstream_status, final_status) then
        local count, incr_err = incr_fail_count(red, route_name, failure_window)
        if incr_err then
            ngx.log(ngx.ERR, "[circuit_breaker] timer incr_fail_count failed: ", incr_err)
            redis_close(red)
            return
        end

        if current_state == "HALF_OPEN" or count >= failure_threshold then
            set_state(red, route_name, "OPEN", recovery_timeout + 60)
            set_opened_at(red, route_name, ngx.time(), recovery_timeout + 60)

            ngx.log(ngx.WARN,
                "[circuit_breaker] route=", route_name,
                ", result=failure",
                ", http_status=", tostring(final_status),
                ", upstream_status=", tostring(upstream_status),
                ", fail_count=", tostring(count),
                ", threshold=", tostring(failure_threshold),
                ", request_state=", tostring(current_state),
                ", fallback=", tostring(cb_force_fallback),
                ", upstream_mode=", tostring(cb_upstream_mode),
                " -> OPEN"
            )
        else
            ngx.log(ngx.WARN,
                "[circuit_breaker] route=", route_name,
                ", result=failure",
                ", http_status=", tostring(final_status),
                ", upstream_status=", tostring(upstream_status),
                ", fail_count=", tostring(count),
                ", threshold=", tostring(failure_threshold),
                ", request_state=", tostring(current_state),
                ", fallback=", tostring(cb_force_fallback),
                ", upstream_mode=", tostring(cb_upstream_mode),
                ", state stays CLOSED"
            )
        end
    end

    redis_close(red)
end

function _M.log()
    local route_name = get_current_route()
    if route_name ~= "svc_failover" then
        return
    end

    local policy = get_cb_policy(route_name)
    if not policy then
        return
    end

    local params = {
        route_name = route_name,
        upstream_status = ngx.var.upstream_status,
        final_status = ngx.status,
        cb_state = ngx.ctx.cb_state,
        cb_force_fallback = ngx.ctx.cb_force_fallback,
        cb_upstream_mode = ngx.ctx.cb_upstream_mode,
        failure_window = tonumber(policy.failure_window) or 30,
        failure_threshold = tonumber(policy.failure_threshold) or 2,
        recovery_timeout = tonumber(policy.recovery_timeout) or 15
    }

    local ok, err = ngx.timer.at(0, update_breaker_state, params)
    if not ok then
        ngx.log(ngx.ERR, "[circuit_breaker] failed to create timer: ", err or "unknown")
    end
end

return _M