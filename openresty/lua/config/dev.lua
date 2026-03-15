return {
    cors = {
        allowed_origins = {
            ["http://localhost:3000"] = true,
            ["http://127.0.0.1:5173"] = true,
            ["http://localhost:8080"] = true
        },
        allow_credentials = true,
        allow_methods = "GET, POST, PUT, DELETE, OPTIONS",
        allow_headers = "Authorization, Content-Type, X-Request-Id, X-API-Key",
        max_age = "600"
    }
}