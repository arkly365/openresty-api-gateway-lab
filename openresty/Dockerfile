FROM openresty/openresty:latest

RUN mkdir -p /usr/local/openresty/lualib/resty
RUN mkdir -p /usr/local/openresty/lualib/resty/openssl

COPY third_party/resty/jwt.lua /usr/local/openresty/lualib/resty/jwt.lua
COPY third_party/resty/jwt-validators.lua /usr/local/openresty/lualib/resty/jwt-validators.lua
COPY third_party/resty/hmac.lua /usr/local/openresty/lualib/resty/hmac.lua

# lua-resty-http
COPY third_party/resty/http.lua /usr/local/openresty/lualib/resty/http.lua
COPY third_party/resty/http_connect.lua /usr/local/openresty/lualib/resty/http_connect.lua
COPY third_party/resty/http_headers.lua /usr/local/openresty/lualib/resty/http_headers.lua

# lua-resty-openssl
COPY third_party/resty/openssl /usr/local/openresty/lualib/resty/openssl
COPY third_party/resty/openssl.lua /usr/local/openresty/lualib/resty/openssl.lua