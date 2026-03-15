local _M = {}

local redis = require "resty.redis"

function _M.get_client()
    local red = redis:new()
    red:set_timeout(1000)

    local host = os.getenv("REDIS_HOST") or "redis"
    local port = tonumber(os.getenv("REDIS_PORT")) or 6379

    local ok, err = red:connect(host, port)
    if not ok then
        return nil, err
    end

    return red
end

function _M.keepalive(red)
    if not red then
        return
    end

    local ok, err = red:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.ERR, "[my_redis] set_keepalive failed: ", err)
    end
end

return _M