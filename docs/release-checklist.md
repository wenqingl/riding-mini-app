# Release Checklist (WeChat Mini Program)

## 1. WeChat account + AppID
- Register a WeChat Mini Program and get the AppID.
- Add AppID to `miniapp/project.config.json`.

## 2. CloudRun environment
- Create a CloudRun environment and service.
- Set service name (used by `wx.cloud.callContainer`).
- Configure container port to match your image.
- Add env vars: `XINGZHE_CLIENT_ID`, `XINGZHE_CLIENT_SECRET`, `REDIRECT_URI`.

## 3. Backend domain + HTTPS
- Bind a custom domain to CloudRun (HTTPS).
- Set `REDIRECT_URI` to `https://your-domain.com/auth/callback/web`.
- Ensure the domain is reachable from WeChat.

## 4. WeChat domain settings
- Request合法域名: `https://your-domain.com`
- UploadFile合法域名: `https://your-domain.com`
- DownloadFile合法域名: `https://your-domain.com`
- Webview业务域名: `https://your-domain.com`

## 5. Mini Program settings
- Update `miniapp/app.js` `baseUrl` to the production domain (for WebView login).
- Set `cloudEnvId` and `cloudServiceName` in `miniapp/app.js`.
- Ensure base library >= 2.23.0 (required for `wx.cloud.callContainer`).
- Confirm `sitemap.json` is enabled for search indexing.

## 6. Submit for review
- Upload code in WeChat DevTools.
- Fill in version, description, and categories.
- Submit for review and publish.

## 7. Search availability
- After approval and publish, the Mini Program is searchable by name in WeChat.
- Search ranking depends on name, category, and usage.
