---
layout: post
title: Nginx配置Google Fonts反向代理
categories: [Nginx]
tags: [Nginx]
---

使用Nginx反向代理谷歌字体库，可以设置缓存加快访问速度。

## 谷歌字体库

比如以下地址，虽然不再被墙，但访问有时不太稳定，加载速度慢。

```
https://fonts.googleapis.com/css?family=Source+Sans+Pro:300,400,600,700,300italic,400italic,600italic,700italic
```
<!-- more -->

## 国内镜像

```
http://fonts.useso.com/css?family=Source+Sans+Pro:300,400,600,300italic,400italic,600italic
360的，目前已不再维护

http://fonts.gmirror.org/css?family=Lato:400,700|Roboto+Slab:400,700|Inconsolata:400,700
```

### 使用过程的一些问题

1. 大部分镜像不支持https
2. 打开页面的速度寄托在别人的服务器
3. 特殊网络环境可能无法访问

## 搭建反向代理服务

准备以下应用环境，局域网/公网环境都可以，根据自己需要。

1. 可访问的IP或域名（例如`fonts.yourdomain.com`)
2. 机器环境 linux + nginx

安装nginx及第三方模块等就忽略了，直接贴上配置文件。


### 修改nginx缓存

```
# Nginx Cache Settings
proxy_temp_file_write_size 128k;
proxy_temp_path   /data/nginx_cache/proxy_temp;
proxy_cache_path  /data/nginx_cache/proxy_cache levels=1:2 keys_zone=cache_one:200m inactive=30d max_size=30g;
```

其中，`/data/nginx_cache/proxy_temp`和`/data/nginx_cache/proxy_cache`是自定义的目录，如不存在请创建目录。

```
mkdir -p /data/nginx_cache/proxy_temp
mkdir -p /data/nginx_cache/proxy_cache
```

缓存时间为30天，里面各参数根据自己需要进行修改。

### 反向代理配置

fonts.yourdomain.com.conf

```
upstream google {
    server fonts.googleapis.com:443;
}

upstream gstatic {
    server fonts.gstatic.com:443;
}

server {
    listen 80;

    server_name fonts.yourdomain.com;

    resolver 8.8.8.8;

    access_log /data/logs/nginx/fonts.yourdomain.com.access.log main;
    error_log  /data/logs/nginx/fonts.yourdomain.com.error.log info;

    location /css {
        sub_filter 'fonts.gstatic.com' 'fonts.yourdomain.com';
        sub_filter_once off;
        sub_filter_types text/css;
        proxy_pass_header Server;
        proxy_set_header Host fonts.googleapis.com;
        proxy_set_header Accept-Encoding '';
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_pass https://google;
        proxy_cache cache_one;
        proxy_cache_valid  200 304 365d;
        proxy_cache_key $host$uri$is_args$args;
        expires max;
    }

    location /icon {
        sub_filter 'fonts.gstatic.com' 'fonts.yourdomain.com';
        sub_filter_once off;
        sub_filter_types text/css;
        proxy_pass_header Server;
        proxy_set_header Host fonts.googleapis.com;
        proxy_set_header Accept-Encoding '';
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_pass https://google;
        proxy_cache cache_one;
        proxy_cache_valid  200 304 365d;
        proxy_cache_key $host$uri$is_args$args;
        expires max;
    }

    location / {
        proxy_pass_header Server;
        proxy_set_header Host fonts.gstatic.com;
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_pass https://gstatic;
        proxy_cache cache_one;
        proxy_cache_valid  200 304 365d;
        proxy_cache_key $host$uri$is_args$args;
        expires max;
    }
}

server {
    listen 443 ssl;

    ssl on;
    ssl_certificate /root/ssl/css.crt;
    ssl_certificate_key /root/ssl/css.key;

    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4";
    keepalive_timeout 70;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    server_name fonts.yourdomain.com;

    resolver 8.8.8.8;

    location /css {
        sub_filter 'fonts.gstatic.com' 'fonts.yourdomain.com';
        sub_filter_once off;
        sub_filter_types text/css;
        proxy_pass_header Server;
        proxy_set_header Host fonts.googleapis.com;
        proxy_set_header Accept-Encoding '';
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_pass https://google;
        proxy_cache cache_one;
        proxy_cache_valid  200 304 365d;
        proxy_cache_key $host$uri$is_args$args;
        expires max;
    }

    location /icon {
        sub_filter 'fonts.gstatic.com' 'fonts.yourdomain.com';
        sub_filter_once off;
        sub_filter_types text/css;
        proxy_pass_header Server;
        proxy_set_header Host fonts.googleapis.com;
        proxy_set_header Accept-Encoding '';
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_pass https://google;
        proxy_cache cache_one;
        proxy_cache_valid  200 304 365d;
        proxy_cache_key $host$uri$is_args$args;
        expires max;
    }

    location / {
        proxy_pass_header Server;
        proxy_set_header Host fonts.gstatic.com;
        proxy_redirect off;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Scheme $scheme;
        proxy_pass https://gstatic;
        proxy_cache cache_one;
        proxy_cache_valid  200 304 365d;
        proxy_cache_key $host$uri$is_args$args;
        expires max;
    }
}

```

