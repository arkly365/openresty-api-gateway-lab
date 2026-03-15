local cjson = require "cjson.safe"
local hmac = require "resty.hmac"
local str = require "resty.string"

local _M = {}

local function b64url_decode(input)
    if not input then
        return nil
    end

    input = input:gsub("-", "+"):gsub("_", "/")
    local pad = #input % 4
    if pad == 2 then
        input = input .. "=="
    elseif pad == 3 then
        input = input .. "="
    elseif pad == 1 then
        return nil
    end

    return ngx.decode_base64(input)
end

local function b64url_encode(input)
    local s = ngx.encode_base64(input)
    s = s:gsub("+", "-"):gsub("/", "_"):gsub("=", "")
    return s
end

function _M.verify_hs256(secret, token)
    if not token or token == "" then
        return nil, "missing token"
    end

    local header_b64, payload_b64, signature_b64 = token:match("^([^.]+)%.([^.]+)%.([^.]+)$")
    if not header_b64 then
        return nil, "invalid token format"
    end

    local header_json = b64url_decode(header_b64)
    local payload_json = b64url_decode(payload_b64)

    if not header_json or not payload_json then
        return nil, "base64url decode failed"
    end

    local header = cjson.decode(header_json)
    local payload = cjson.decode(payload_json)

    if not header or not payload then
        return nil, "json decode failed"
    end

    if header.alg ~= "HS256" then
        return nil, "unsupported alg: " .. tostring(header.alg)
    end

    local signing_input = header_b64 .. "." .. payload_b64

    local hm, err = hmac:new(secret, hmac.ALGOS.SHA256)
    if not hm then
        return nil, "hmac init failed: " .. tostring(err)
    end

    local digest = hm:final(signing_input)
    if not digest then
        return nil, "hmac final failed"
    end

    local expected_sig = b64url_encode(digest)

    if expected_sig ~= signature_b64 then
        return nil, "signature mismatch"
    end

    if payload.exp and tonumber(payload.exp) then
        if tonumber(payload.exp) < ngx.time() then
            return nil, "token expired"
        end
    end

    return {
        header = header,
        payload = payload
    }, nil
end

return _M