---
title: 基于 OpenResty + GitHub WebHook 的代码自动更新
date: 2020-12-02 17:09:34
categories: [Nginx]
tags: [Nginx,OpenResty]
description: 基于 OpenResty + GitHub WebHook 的代码自动更新
---

## OpenResty

OpenResty 是一个基于 Nginx 与 Lua 的高性能 Web 平台，其内部集成了大量精良的 Lua 库、第三方模块以及大多数的依赖项。用于方便地搭建能够处理超高并发、扩展性极高的动态 Web 应用、Web 服务和动态网关。

安装及使用请参阅[OpenResty官网](https://openresty.org/)

## Nginx配置

```nginx
server {
    listen       80;
    server_name  yourdomain;

    location /webhook {
        default_type 'text/plain';
        content_by_lua_file /your/lua/path/webhook.lua;
    }
}
```

## webhook.lua 源码

```lua
local GITHUB_WEBHOOK_SECRET = "your github webhook secret"

local request_method = ngx.var.request_method
if "POST" ~= request_method then
    ngx.exit(404)
end

local signature = ngx.req.get_headers()["X-Hub-Signature"]
if signature == nil then
    return ngx.exit(404)
end

ngx.req.read_body()
local req_body = ngx.req.get_body_data()
if not req_body then
    return ngx.exit(404)
end

local dt = {}
for k, v in string.gmatch(signature, "(%w+)=(%w+)") do
    dt[k] = v
end

local str = require "resty.string"

local digest = ngx.hmac_sha1(GITHUB_WEBHOOK_SECRET, req_body)

if not str.to_hex(digest) == dt["sha1"] then
    return ngx.exit(404)
end

os.execute("cd /your/blog/repositorie/path/ && git pull");
ngx.say("OK")
```
