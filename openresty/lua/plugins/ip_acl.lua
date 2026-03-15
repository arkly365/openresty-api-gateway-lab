local _M = {}

_M.PRIORITY = 1000

local env = os.getenv("APP_ENV") or "dev"

local function is_dev_allowed(ip)
    if not ip or ip == "" then
        return false
    end

    -- localhost
    if ip == "127.0.0.1" or ip == "::1" then
        return true
    end

    -- Docker / bridge 常見 gateway
    if string.match(ip, "^172%.[0-9]+%.[0-9]+%.1$") then
        return true
    end

    -- 常見家用 / 內網 NAT
    if string.match(ip, "^192%.168%.[0-9]+%.[0-9]+$") then
        return true
    end

    -- 若你的環境也可能經過 10.x 私網，可打開
    if string.match(ip, "^10%.[0-9]+%.[0-9]+%.[0-9]+$") then
        return true
    end

    return false
end

local function is_prod_allowed(ip)
    local whitelist = {
        -- ["10.10.1.10"] = true,
        -- ["10.10.1.11"] = true,
    }

    return whitelist[ip] == true
end

function _M.access()
    local ip = ngx.var.remote_addr

    local blacklist = {
        ["192.168.1.200"] = true
    }

    if blacklist[ip] then
        ngx.status = 403
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Forbidden: IP is blacklisted","ip":"' .. (ip or "-") .. '"}')
        return ngx.exit(403)
    end

    local allowed = false

    if env == "prod" then
        allowed = is_prod_allowed(ip)
    else
        allowed = is_dev_allowed(ip)
    end

    if not allowed then
        ngx.status = 403
        ngx.header.content_type = "application/json; charset=utf-8"
        ngx.say('{"error":"Forbidden: IP not in whitelist","ip":"' .. (ip or "-") .. '","env":"' .. env .. '"}')
        return ngx.exit(403)
    end
end

return _M