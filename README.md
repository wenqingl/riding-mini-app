# 🚴 骑行数据合并工具

合并行者 App 分段骑行数据，提供 Android APK。

> 原微信小程序已备份至 `docs/archive/miniapp_backup_20260522.zip`

## 功能
- 登录行者账号（OAuth 2.0）
- 查看骑行记录列表
- 选择多条记录合并
- 自动上传回行者
- 支持 GPX 格式下载

## 技术栈
- 后端：Python + FastAPI
- 前端：Flutter（Android APK）
- 部署：Docker + Nginx

## 本地开发

### 后端
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### Flutter App
```bash
cd miniapp
flutter pub get
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000

# 打包 APK
flutter build apk --release --dart-define=BASE_URL=https://your-server.com
```

## 部署
```bash
docker-compose up -d
```

## 行者 API 参考

- [行者快速入门](https://developer.imxingzhe.com/docs/intro) — OAuth2.0 授权流程、创建开发者账号
- [行者接口文档 (Swagger)](https://www.imxingzhe.com/openapi/doc/) — 需登录行者账号查看
- [行者应用管理](https://www.imxingzhe.com/home/#/settings/api/124) — 管理 client_id / secret、回调域名

### 注意事项
- Token 接口：`POST /oauth2/v2/access_token/`（注意尾部斜杠）
- Content-Type：`multipart/form-data`
- Authorization Header：`Bearer {client_id}:{client_secret}`（冒号分隔）
- API 基础路径：`/openapi/v1/`（非 `/api/v1/`）
- Token 默认有效期 3 个月，过期需用 refresh_token 刷新
- 速率限制：每 15 分钟 1000 次，每天 60,000 次
