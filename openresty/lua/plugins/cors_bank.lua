local _M = {}

function _M.run()
    local origin = ngx.var.http_origin

    local allowed_origins = {
        ["https://ibank.example.com"] = true,
        ["https://m.ibank.example.com"] = true,
        ["https://ibank-uat.example.com"] = true
    }

    if origin and allowed_origins[origin] then
        ngx.header["Access-Control-Allow-Origin"] = origin
        ngx.header["Vary"] = "Origin"
        ngx.header["Access-Control-Allow-Credentials"] = "true"
        ngx.header["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        ngx.header["Access-Control-Allow-Headers"] = "Authorization, Content-Type, X-Request-Id"
        ngx.header["Access-Control-Max-Age"] = "600"
    end

    if ngx.var.request_method == "OPTIONS" then
        return ngx.exit(204)
    end
end

return _M