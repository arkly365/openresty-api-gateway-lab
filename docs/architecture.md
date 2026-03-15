# Architecture Notes

This lab is organized around several gateway design concepts:

- route configuration
- policy engine
- plugin runner
- decision context
- observability

The plugin execution model is divided into:

- access phase
- header_filter phase
- log phase

Traffic and reliability decisions are implemented through Lua plugins running inside OpenResty.