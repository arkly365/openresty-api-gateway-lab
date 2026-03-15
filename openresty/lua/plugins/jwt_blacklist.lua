local _M = {}
local my_redis = require "my_redis"

function _M.run()
    local payload = ngx.ctx.jwt_payload

    if not payload then
        ngx.status = 500
        ngx.say('{"error":"JWT payload not found in context"}')
        return ngx.exit(500)
    end

    local jti = payload.jti
    if not jti or jti == "" then
        ngx.status = 401
        ngx.say('{"error":"JWT missing jti"}')
        return ngx.exit(401)
    end

    local red, err = my_redis.get_client()
    if not red then
        ngx.status = 500
        ngx.say('{"error":"Redis connection failed"}')
        return ngx.exit(500)
    end

    local key = "blacklist:" .. jti
    local res, err = red:get(key)

    my_redis.keepalive(red)

    if res and res ~= ngx.null then
        ngx.status = 401
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"JWT has been revoked"}')
        return ngx.exit(401)
    end
end

return _M