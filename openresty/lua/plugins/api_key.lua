local _M = {}

_M.PRIORITY = 850

function _M.access()
    local api_key = ngx.var.http_x_api_key
    local expected_key = os.getenv("GATEWAY_API_KEY") or "abc123"

    if not api_key or api_key == "" then
        ngx.status = 401
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Missing API Key"}')
        return ngx.exit(401)
    end

    if api_key ~= expected_key then
        ngx.status = 401
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Invalid API Key"}')
        return ngx.exit(401)
    end
end

return _M