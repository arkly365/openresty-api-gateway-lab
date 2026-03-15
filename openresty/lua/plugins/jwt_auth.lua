local _M = {}

_M.PRIORITY = 900

function _M.access()
    local jwt_hs256 = require "jwt_hs256"
    local auth_header = ngx.var.http_authorization

    if not auth_header then
        ngx.status = 401
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Missing Authorization header"}')
        return ngx.exit(401)
    end

    local _, _, token = string.find(auth_header, "Bearer%s+(.+)")
    if not token then
        ngx.status = 401
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Invalid Authorization format"}')
        return ngx.exit(401)
    end

    local secret = os.getenv("JWT_SECRET") or "my_jwt_secret_123456789012345678901234"

    local jwt_obj, err = jwt_hs256.verify_hs256(secret, token)

    if not jwt_obj then
        ngx.status = 401
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Invalid JWT","reason":"' .. tostring(err) .. '"}')
        return ngx.exit(401)
    end

    ngx.ctx.jwt_token = token
    ngx.ctx.jwt_payload = jwt_obj.payload

    if jwt_obj.payload.sub then
        ngx.req.set_header("X-User-Id", jwt_obj.payload.sub)
    end

    if jwt_obj.payload.role then
        ngx.req.set_header("X-User-Role", jwt_obj.payload.role)
    end

    ngx.req.clear_header("Authorization")
end

return _M