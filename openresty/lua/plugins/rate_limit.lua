local _M = {}

_M.PRIORITY = 800

local my_redis = require "my_redis"
local route_config = require "route_config"

function _M.access()
    local route = ngx.ctx.route or "unknown"
    local rate_limit_policy = route_config.get_policy(route, "rate_limit") or {}

    local limit = tonumber(rate_limit_policy.limit) or 5
    local window = tonumber(rate_limit_policy.window) or 10

    local red, err = my_redis.get_client()
    if not red then
        ngx.status = 500
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Redis connect failed","reason":"' .. tostring(err) .. '"}')
        return ngx.exit(500)
    end

    local ip = ngx.var.remote_addr
    local key = "limit:" .. route .. ":" .. ip

    local current, err2 = red:incr(key)
    if not current then
        ngx.log(ngx.ERR, "redis incr failed: ", err2)
        my_redis.keepalive(red)

        ngx.status = 500
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Rate limit internal error"}')
        return ngx.exit(500)
    end

    if current == 1 then
        red:expire(key, window)
    end

    my_redis.keepalive(red)

    if current > limit then
        ngx.status = 429
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.header["X-RateLimit-Limit"] = tostring(limit)
        ngx.header["X-RateLimit-Remaining"] = "0"
        ngx.header["Retry-After"] = tostring(window)
        ngx.say('{"error":"Too Many Requests","window_sec":' .. window .. ',"limit":' .. limit .. '}')
        return ngx.exit(429)
    end

    ngx.header["X-RateLimit-Limit"] = tostring(limit)
    ngx.header["X-RateLimit-Remaining"] = tostring(math.max(limit - current, 0))
end

return _M