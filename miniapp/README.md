# 行者骑行合并 — Flutter Android App

微信小程序已迁移为 Flutter Android APK。原小程序备份：`docs/archive/miniapp_backup_20260522.zip`

## 功能

- 行者 OAuth 登录（WebView 内完成授权）
- 骑行记录列表（支持多选）
- 合并并上传回行者
- 合并并下载 GPX 文件

## 环境要求

| 工具 | 版本 |
|---|---|
| Flutter SDK | ≥ 3.10 |
| Android SDK | API 21+ |
| Java | 11+ |

## 安装 Flutter（Windows）

```powershell
# 1. 下载 Flutter SDK
#    https://docs.flutter.dev/get-started/install/windows
#    解压到 C:\flutter

# 2. 添加到 PATH
$env:PATH += ";C:\flutter\bin"

# 3. 验证
flutter doctor
```

## 本地开发

```powershell
cd miniapp

# 安装依赖
flutter pub get

# 运行（需要连接 Android 设备或启动模拟器）
# 后端地址默认: http://10.0.2.2:8000 (Android 模拟器访问宿主机)
flutter run

# 指定自定义后端地址
flutter run --dart-define=BASE_URL=https://your-server.com
```

## 打包 APK

```powershell
cd miniapp

# Debug APK（快速测试）
flutter build apk --debug

# Release APK（正式发布）
flutter build apk --release --dart-define=BASE_URL=https://your-server.com

# 输出路径
# build/app/outputs/flutter-apk/app-release.apk
```

## 后端配置

后端无需修改，`backend/` 目录原样使用。

```powershell
# 启动后端（Docker）
docker-compose up -d

# 或直接运行
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## 项目结构

```
miniapp/
├── lib/
│   ├── main.dart              # 入口 + AuthGate
│   ├── pages/
│   │   ├── login_page.dart    # 登录页 (OAuth WebView)
│   │   └── records_page.dart  # 骑行记录 + 合并操作
│   ├── models/
│   │   └── record.dart        # RideRecord 数据模型
│   └── services/
│       └── api_service.dart   # 后端 API 封装
├── android/                   # Android 原生配置
└── pubspec.yaml               # 依赖声明
```
