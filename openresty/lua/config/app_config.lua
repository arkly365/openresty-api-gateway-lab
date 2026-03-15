local env = os.getenv("APP_ENV") or "dev"

if env == "prod" then
    return require("config.prod")
else
    return require("config.dev")
end