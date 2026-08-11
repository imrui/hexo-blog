# hexo-blog

个人博客 [七月流火 - 四零九六](https://www.imrui.net) 的源码仓库。

- **框架**：[Hexo](https://hexo.io/) 7.3
- **主题**：[NexT](https://theme-next.js.org/) 8.29
- **运行环境**：Node.js >= 20.19（受 `hexo-generator-feed@4` 约束）

## 快速开始

```bash
npm install     # 安装依赖
npm run server  # 本地预览 http://localhost:4321
npm run build   # 生成静态文件到 public/
npm run clean   # 清理缓存与 public/
npm run deploy  # 构建产物推送到 GitHub
```

> 本地预览端口固定为 **4321** 而非 Hexo 默认的 4000，因为 4000 会被福昕阅读器的
> `FoxitProtect` 服务占用（它显式绑定 `127.0.0.1:4000`，优先级高于 Hexo 的通配绑定，
> 表现为服务启动正常但浏览器打不开）。

## 目录结构

```
_config.yml         Hexo 站点配置
_config.next.yml    NeXT 主题配置（npm 安装主题的覆盖方式）
scaffolds/          新建文章模板
source/
  _posts/           文章 Markdown
  _data/            主题自定义注入片段
  about/ 404/       独立页面
  images/           图片资源
  CNAME             GitHub Pages 自定义域名绑定
```

## 部署架构

站点**并非**由 GitHub Pages 直接对外提供服务，GitHub 仅作为分发中转：

```
本地 npm run deploy
  └─> push 到 github.com/imrui/imrui.github.io
        └─> GitHub WebHook
              └─> 腾讯云 VPS 上的 OpenResty 执行 git pull
                    └─> 对外提供 https://www.imrui.net
```

WebHook 侧的实现见文章[《基于 OpenResty + GitHub WebHook 的代码自动更新》](https://www.imrui.net/2020/12/02/nginx-lua-webhook/)。

`source/CNAME` 只影响 `imrui.github.io` 的跳转行为（301 到自定义域名），
对主站没有作用——主站域名由 VPS 侧的 DNS 与 Nginx 配置决定。

## 已知问题

**HTTP 明文访问被拦截。** `http://www.imrui.net` 会被腾讯云 DNSPod 302 到
`webblock` 提示页（备案相关），HTTPS 不受影响。因此 `_config.yml` 中的 `url`
必须使用 `https://`，否则 RSS 与站点地图中的绝对链接会全部指向被拦截的地址。

**NeXT 8.29 的飘带配置失效。** 主题给 `ribbon.js` 加了 `defer`，而该脚本依赖
「自己是文档中最后一个 script」来读取 `size` / `alpha` 属性；`defer` 使其推迟到
DOM 解析完毕后执行，此时读不到属性而静默回落内置默认值（`size=90`、`alpha=0.6`），
表现为飘带锯齿密集、颜色过饱和。当前的规避方式是关闭主题自带的 `canvas_ribbon`，
改由 `source/_data/body-end.njk` 在运行时动态注入，详见该文件内的注释。
