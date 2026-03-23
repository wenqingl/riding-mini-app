# 🚴 骑行数据合并工具

合并行者 App 分段骑行数据的微信小程序。

## 功能
- 登录行者账号（OAuth 2.0）
- 查看骑行记录列表
- 选择多条记录合并
- 自动上传回行者
- 支持 FIT/GPX/TCX 格式

## 技术栈
- 后端：Python + FastAPI
- 前端：微信小程序原生
- 部署：Docker + Nginx

## 本地开发

### 后端
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### 小程序
用微信开发者工具打开 miniapp/ 目录

## 部署
```bash
docker-compose up -d
```
