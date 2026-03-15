local _M = {}
local config = require("config.app_config")

function _M.run()
    local origin = ngx.var.http_origin
    local cors = config.cors

    if origin and cors.allowed_origins[origin] then
        ngx.header["Access-Control-Allow-Origin"] = origin
        ngx.header["Vary"] = "Origin"
        ngx.header["Access-Control-Allow-Credentials"] = tostring(cors.allow_credentials)
        ngx.header["Access-Control-Allow-Methods"] = cors.allow_methods
        ngx.header["Access-Control-Allow-Headers"] = cors.allow_headers
        ngx.header["Access-Control-Max-Age"] = cors.max_age
    end
end

return _M