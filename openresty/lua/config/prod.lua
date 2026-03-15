return {
    cors = {
        allowed_origins = {
            ["https://ibank.example.com"] = true,
            ["https://m.ibank.example.com"] = true
        },
        allow_credentials = true,
        allow_methods = "GET, POST, OPTIONS",
        allow_headers = "Authorization, Content-Type, X-Request-Id",
        max_age = "600"
    }
}