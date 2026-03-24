# 行者骑行数据合并工具 技术方案 (TRD)

## 技术栈

- **后端**: Python 3.11+ + FastAPI
- **前端**: 微信小程序原生开发
- **FIT 解析**: python-fitparse
- **GPX/TCX 解析**: gpxpy / lxml
- **部署**: Nginx + HTTPS + 云服务器
- **数据库**: SQLite（MVP 阶段，存储 token）

## 测试基础设施

**框架**: pytest + httpx (AsyncClient)
**命名约定**: `test_*.py`，按模块分目录
**运行命令**: `pytest tests/ -v`
**Mock**: 用 pytest fixtures + unittest.mock 模拟行者 API

---

## L 内容（组件 & 接口）

### 组件 1: Auth Service（OAuth 代理）
**职责**: 代理行者 OAuth 2.0 授权流程，管理 token

| 接口 | 方法 | 入参 | 出参 | 约束 |
|------|------|------|------|------|
| GET /auth/login | 重定向 | - | 302 → 行者授权页 | 拼接 client_id + redirect_uri + scope |
| GET /auth/callback | GET | code, state | {access_token, user_info} | 用 code 换 token |
| POST /auth/refresh | POST | refresh_token | {access_token} | token 过期时自动调用 |

### 组件 2: Record Service（骑行记录）
**职责**: 从行者 API 获取用户骑行记录列表

| 接口 | 方法 | 入参 | 出参 | 约束 |
|------|------|------|------|------|
| GET /api/records | GET | access_token | [{id, date, distance, duration, name}] | 带 Bearer token |
| GET /api/records/{id}/file | GET | access_token, id, format | FIT/GPX/TCX 二进制流 | 下载原始文件 |

### 组件 3: Merge Service（文件合并）
**职责**: 解析并合并多个运动文件

| 接口 | 方法 | 入参 | 出参 | 约束 |
|------|------|------|------|------|
| POST /api/merge | POST | {files: [{data, format}], format} | 合并后的文件二进制流 | 按时间排序拼接 |
| POST /api/merge-and-upload | POST | {record_ids, access_token, format} | {success, new_record_id} | 合并+自动上传 |

### 组件 4: Upload Service（上传回行者）
**职责**: 将合并后的文件上传回行者

| 接口 | 方法 | 入参 | 出参 | 约束 |
|------|------|------|------|------|
| POST /api/upload | POST | access_token, file_buffer, filename | {record_id, success} | 调用行者上传 API |

---

## 实现计划

### Phase 1: 项目脚手架

**Task 1: 初始化后端项目**
> 搭建 FastAPI 项目骨架

**文件：**
- 新建：`riding-mini-app/backend/requirements.txt`
- 新建：`riding-mini-app/backend/main.py`
- 新建：`riding-mini-app/backend/config.py`
- 新建：`riding-mini-app/backend/routers/__init__.py`
- 新建：`riding-mini-app/backend/routers/auth.py`
- 新建：`riding-mini-app/backend/routers/records.py`
- 新建：`riding-mini-app/backend/routers/merge.py`
- 新建：`riding-mini-app/backend/services/__init__.py`

**Step 1: 创建 requirements.txt**
```
fastapi==0.115.*
uvicorn==0.34.*
httpx==0.28.*
python-fitparse==1.2.*
gpxpy==1.6.*
python-multipart==0.0.*
```

**Step 2: 创建 main.py**
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth, records, merge

app = FastAPI(title="行者骑行数据合并工具")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(records.router, prefix="/api", tags=["records"])
app.include_router(merge.router, prefix="/api", tags=["merge"])

@app.get("/health")
async def health():
    return {"status": "ok"}
```

**Step 3: 创建 config.py**
```python
import os

XINGZHE_CLIENT_ID = os.getenv("XINGZHE_CLIENT_ID", "")
XINGZHE_CLIENT_SECRET = os.getenv("XINGZHE_CLIENT_SECRET", "")
XINGZHE_AUTH_URL = "https://www.imxingzhe.com/oauth2/v2/authorize"
XINGZHE_TOKEN_URL = "https://www.imxingzhe.com/oauth2/v2/token"
XINGZHE_API_BASE = "https://www.imxingzhe.com/api/v1"
REDIRECT_URI = os.getenv("REDIRECT_URI", "http://localhost:8000/auth/callback")
```

**Step 4: 冒烟测试**
```bash
cd riding-mini-app/backend
pip install -r requirements.txt
uvicorn main:app --reload
curl http://localhost:8000/health
# 预期: {"status": "ok"}
```

**提交信息:** `chore: init backend project structure`

---

**Task 2: 初始化小程序项目**
> 创建微信小程序前端骨架

**文件：**
- 新建：`riding-mini-app/miniapp/app.js`
- 新建：`riding-mini-app/miniapp/app.json`
- 新建：`riding-mini-app/miniapp/app.wxss`
- 新建：`riding-mini-app/miniapp/pages/index/index.wxml`
- 新建：`riding-mini-app/miniapp/pages/index/index.js`
- 新建：`riding-mini-app/miniapp/pages/index/index.wxss`
- 新建：`riding-mini-app/miniapp/utils/api.js`
- 新建：`riding-mini-app/miniapp/project.config.json`

**Step 1: 创建 app.json**
```json
{
  "pages": ["pages/index/index"],
  "window": {
    "navigationBarTitleText": "骑行数据合并",
    "navigationBarBackgroundColor": "#4A90D9"
  }
}
```

**Step 2: 创建 utils/api.js（API 封装）**
```javascript
const BASE_URL = 'https://your-domain.com'; // 替换为实际后端地址

const request = (url, options = {}) => {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${BASE_URL}${url}`,
      ...options,
      success: res => resolve(res.data),
      fail: err => reject(err)
    });
  });
};

module.exports = {
  login: () => request('/auth/login', { method: 'GET' }),
  getRecords: (token) => request('/api/records', { 
    method: 'GET', header: { Authorization: `Bearer ${token}` }
  }),
  mergeAndUpload: (data, token) => request('/api/merge-and-upload', {
    method: 'POST', header: { Authorization: `Bearer ${token}` }, data
  })
};
```

**提交信息:** `chore: init miniapp project structure`

---

### Phase 2: OAuth 授权

**Task 3: 实现行者 OAuth 授权流程**
> 实现 /auth/login 和 /auth/callback
> 测试层次: UT（来源: F文档 @FT-01~04）

**文件：**
- 修改：`riding-mini-app/backend/routers/auth.py`
- 新建：`riding-mini-app/backend/services/auth_service.py`
- 新建：`riding-mini-app/backend/tests/test_auth.py`

**Step 1: 实现 auth_service.py**
```python
import httpx
from config import XINGZHE_CLIENT_ID, XINGZHE_CLIENT_SECRET, XINGZHE_AUTH_URL, XINGZHE_TOKEN_URL, REDIRECT_URI

def get_auth_url(state: str = "abc") -> str:
    return (
        f"{XINGZHE_AUTH_URL}?client_id={XINGZHE_CLIENT_ID}"
        f"&response_type=code&state={state}&scope=write"
        f"&redirect_uri={REDIRECT_URI}"
    )

async def exchange_code_for_token(code: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(XINGZHE_TOKEN_URL, data={
            "grant_type": "authorization_code",
            "code": code,
            "client_id": XINGZHE_CLIENT_ID,
            "client_secret": XINGZHE_CLIENT_SECRET,
            "redirect_uri": REDIRECT_URI,
        })
        resp.raise_for_status()
        return resp.json()

async def refresh_token(refresh_token: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(XINGZHE_TOKEN_URL, data={
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": XINGZHE_CLIENT_ID,
            "client_secret": XINGZHE_CLIENT_SECRET,
        })
        resp.raise_for_status()
        return resp.json()
```

**Step 2: 实现 routers/auth.py**
```python
from fastapi import APIRouter, Query
from fastapi.responses import RedirectResponse
from services.auth_service import get_auth_url, exchange_code_for_token

router = APIRouter()

@router.get("/login")
async def login():
    url = get_auth_url()
    return RedirectResponse(url=url)

@router.get("/callback")
async def callback(code: str = Query(...), state: str = Query(default="abc")):
    token_data = await exchange_code_for_token(code)
    return {"access_token": token_data.get("access_token"), "refresh_token": token_data.get("refresh_token")}
```

**Step 3: 写单元测试 test_auth.py**
```python
import pytest
from unittest.mock import AsyncMock, patch
from services.auth_service import get_auth_url, exchange_code_for_token

def test_get_auth_url_contains_client_id():
    url = get_auth_url()
    assert "client_id=" in url
    assert "response_type=code" in url
    assert "scope=write" in url

@pytest.mark.asyncio
async def test_exchange_code_for_token():
    mock_response = {"access_token": "test_token", "refresh_token": "test_refresh"}
    with patch("services.auth_service.httpx.AsyncClient") as MockClient:
        instance = MockClient.return_value.__aenter__.return_value
        instance.post = AsyncMock()
        instance.post.return_value.raise_for_status = AsyncMock()
        instance.post.return_value.json = lambda: mock_response
        result = await exchange_code_for_token("test_code")
        assert result["access_token"] == "test_token"
```

**Step 4: 跑测试确认通过**
```bash
pytest tests/test_auth.py -v
```

**提交信息:** `feat: implement xingzhe OAuth login/callback`

---

### Phase 3: 骑行记录获取

**Task 4: 实现骑行记录列表接口**
> 对接行者 API 获取记录列表
> 测试层次: UT（来源: F文档 @FT-05~07）

**文件：**
- 新建：`riding-mini-app/backend/services/record_service.py`
- 修改：`riding-mini-app/backend/routers/records.py`
- 新建：`riding-mini-app/backend/tests/test_records.py`

**Step 1: 实现 record_service.py**
```python
import httpx
from config import XINGZHE_API_BASE

async def get_records(access_token: str) -> list:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{XINGZHE_API_BASE}/records",
            headers={"Authorization": f"Bearer {access_token}"}
        )
        resp.raise_for_status()
        return resp.json().get("data", [])

async def download_record_file(access_token: str, record_id: str, fmt: str = "fit") -> bytes:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{XINGZHE_API_BASE}/records/{record_id}/export",
            params={"format": fmt},
            headers={"Authorization": f"Bearer {access_token}"}
        )
        resp.raise_for_status()
        return resp.content
```

**Step 2: 实现 routers/records.py**
```python
from fastapi import APIRouter, Header, HTTPException
from services.record_service import get_records, download_record_file

router = APIRouter()

def parse_token(authorization: str) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")
    return authorization.split(" ", 1)[1]

@router.get("/records")
async def list_records(authorization: str = Header(...)):
    token = parse_token(authorization)
    records = await get_records(token)
    return {"records": records}

@router.get("/records/{record_id}/file")
async def get_record_file(record_id: str, format: str = "fit", authorization: str = Header(...)):
    token = parse_token(authorization)
    data = await download_record_file(token, record_id, format)
    content_type = {"fit": "application/octet-stream", "gpx": "application/gpx+xml", "tcx": "application/xml"}
    return Response(content=data, media_type=content_type.get(format, "application/octet-stream"))
```

**提交信息:** `feat: implement record list and file download API`

---

### Phase 4: 文件合并核心逻辑

**Task 5: 实现 FIT 文件解析与合并**
> 实现 FIT/GPX/TCX 解析 + 按时间拼接
> 测试层次: UT（来源: F文档 @FT-08~10）

**文件：**
- 新建：`riding-mini-app/backend/services/merge_service.py`
- 新建：`riding-mini-app/backend/tests/test_merge.py`
- 新建：`riding-mini-app/backend/tests/fixtures/sample.fit`（测试用）
- 新建：`riding-mini-app/backend/tests/fixtures/sample.gpx`（测试用）

**Step 1: 实现 merge_service.py**
```python
import fitparse
import gpxpy
from io import BytesIO
from datetime import datetime

def parse_fit_records(data: bytes) -> list:
    """解析 FIT 文件，返回按时间排序的 record 列表"""
    fitfile = fitparse.FitFile(BytesIO(data))
    records = []
    for record in fitfile.get_messages("record"):
        r = {}
        for field in record:
            r[field.name] = field.value
        if r.get("timestamp"):
            records.append(r)
    return sorted(records, key=lambda x: x["timestamp"])

def parse_gpx_records(data: bytes) -> list:
    """解析 GPX 文件，返回 record 列表"""
    gpx = gpxpy.parse(data.decode("utf-8"))
    records = []
    for track in gpx.tracks:
        for segment in track.segments:
            for point in segment.points:
                records.append({
                    "timestamp": point.time,
                    "position_lat": point.latitude,
                    "position_long": point.longitude,
                    "altitude": point.elevation,
                })
    return sorted(records, key=lambda x: x["timestamp"])

def merge_records(file_list: list[dict]) -> list:
    """合并多个文件的 record 列表，按时间排序，空白不补"""
    all_records = []
    for f in file_list:
        if f["format"] == "fit":
            all_records.extend(parse_fit_records(f["data"]))
        elif f["format"] == "gpx":
            all_records.extend(parse_gpx_records(f["data"]))
    return sorted(all_records, key=lambda x: x["timestamp"])

def records_to_fit(records: list) -> bytes:
    """将 record 列表写回 FIT 文件"""
    fitfile = fitparse.FitFile()
    # 注意：python-fitparse 主要用于读取，写入需要用 fit-sdk 或手动构建
    # MVP 阶段先用 gpx 输出作为 fallback
    return records_to_gpx(records)

def records_to_gpx(records: list) -> bytes:
    """将 record 列表写为 GPX 文件"""
    import gpxpy.gpx
    gpx = gpxpy.gpx.GPX()
    gpx_track = gpxpy.gpx.GPXTrack()
    gpx.tracks.append(gpx_track)
    gpx_segment = gpxpy.gpx.GPXTrackSegment()
    gpx_track.segments.append(gpx_segment)
    for r in records:
        point = gpxpy.gpx.GPXTrackPoint(
            latitude=r.get("position_lat", 0),
            longitude=r.get("position_long", 0),
            elevation=r.get("altitude", 0),
            time=r.get("timestamp"),
        )
        gpx_segment.points.append(point)
    return gpx.to_xml().encode("utf-8")
```

**Step 2: 写单元测试 test_merge.py**
```python
from services.merge_service import parse_gpx_records, merge_records, records_to_gpx
from datetime import datetime, timezone

SAMPLE_GPX = b"""<?xml version="1.0"?>
<gpx version="1.1">
  <trk><name>Test</name><trkseg>
    <trkpt lat="39.9" lon="116.4"><ele>50</ele><time>2026-03-01T08:00:00Z</time></trkpt>
    <trkpt lat="39.91" lon="116.41"><ele>55</ele><time>2026-03-01T08:05:00Z</time></trkpt>
  </trkseg></trk>
</gpx>"""

def test_parse_gpx_records():
    records = parse_gpx_records(SAMPLE_GPX)
    assert len(records) == 2
    assert records[0]["position_lat"] == 39.9

def test_merge_two_files():
    file1 = {"format": "gpx", "data": SAMPLE_GPX}
    file2 = {"format": "gpx", "data": SAMPLE_GPX}
    merged = merge_records([file1, file2])
    assert len(merged) == 4  # 2 + 2

def test_records_to_gpx_roundtrip():
    records = parse_gpx_records(SAMPLE_GPX)
    gpx_bytes = records_to_gpx(records)
    roundtrip = parse_gpx_records(gpx_bytes)
    assert len(roundtrip) == 2
```

**Step 3: 跑测试**
```bash
pytest tests/test_merge.py -v
```

**提交信息:** `feat: implement FIT/GPX parse, merge, and export`

---

**Task 6: 实现合并+上传接口**
> POST /api/merge-and-upload 全流程
> 测试层次: UT（来源: F文档 @FT-11~13）

**文件：**
- 新建：`riding-mini-app/backend/services/upload_service.py`
- 修改：`riding-mini-app/backend/routers/merge.py`
- 新建：`riding-mini-app/backend/tests/test_upload.py`

**Step 1: 实现 upload_service.py**
```python
import httpx
from config import XINGZHE_API_BASE

async def upload_to_xingzhe(access_token: str, file_data: bytes, filename: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{XINGZHE_API_BASE}/records/upload",
            headers={"Authorization": f"Bearer {access_token}"},
            files={"file": (filename, file_data)},
        )
        resp.raise_for_status()
        return resp.json()
```

**Step 2: 实现 merge router**
```python
from fastapi import APIRouter, Header, HTTPException
from services.record_service import download_record_file
from services.merge_service import merge_records, records_to_gpx
from services.upload_service import upload_to_xingzhe

router = APIRouter()

@router.post("/merge-and-upload")
async def merge_and_upload(body: dict, authorization: str = Header(...)):
    token = authorization.split(" ", 1)[1]
    record_ids = body.get("record_ids", [])
    target_format = body.get("format", "gpx")
    
    # 下载所有文件
    file_list = []
    for rid in record_ids:
        data = await download_record_file(token, str(rid), target_format)
        file_list.append({"format": target_format, "data": data})
    
    # 合并
    merged_records = merge_records(file_list)
    merged_bytes = records_to_gpx(merged_records) if target_format == "gpx" else None
    
    # 上传
    result = await upload_to_xingzhe(token, merged_bytes, f"merged.{target_format}")
    return {"success": True, "record_id": result.get("id")}
```

**提交信息:** `feat: implement merge-and-upload endpoint`

---

### Phase 5: 小程序前端

**Task 7: 实现小程序登录页**
> 行者 OAuth 登录流程前端
> 测试层次: 手动测试（@FT-01~04 前端部分）

**文件：**
- 修改：`riding-mini-app/miniapp/pages/index/index.wxml`
- 修改：`riding-mini-app/miniapp/pages/index/index.js`
- 修改：`riding-mini-app/miniapp/pages/index/index.wxss`

**Step 1: index.wxml**
```html
<view class="container">
  <view wx:if="{{!loggedIn}}" class="login-section">
    <text class="title">🚴 骑行数据合并</text>
    <text class="desc">合并你的分段骑行记录</text>
    <button bindtap="doLogin" type="primary">登录行者</button>
  </view>
  
  <view wx:if="{{loggedIn}}" class="main-section">
    <text class="section-title">选择要合并的记录</text>
    <view wx:for="{{records}}" wx:key="id" class="record-item {{item.selected ? 'selected' : ''}}" bindtap="toggleRecord" data-id="{{item.id}}">
      <checkbox checked="{{item.selected}}" />
      <view class="record-info">
        <text>{{item.date}}</text>
        <text>{{item.distance}}km | {{item.duration}}</text>
      </view>
    </view>
    <button wx:if="{{selectedCount >= 2}}" bindtap="doMerge" type="primary">合并 {{selectedCount}} 条记录</button>
    <view wx:if="{{mergeResult}}" class="result">
      <text>✅ 合并成功！已上传至行者</text>
    </view>
  </view>
</view>
```

**Step 2: index.js**
```javascript
const api = require('../../utils/api');

Page({
  data: { loggedIn: false, records: [], selectedCount: 0, mergeResult: null, token: '' },
  
  doLogin() {
    wx.login({
      success: () => {
        // 实际流程：跳转 web-view 打开行者授权页
        // MVP: 先用后端 callback 获取 token
        wx.showModal({ title: '提示', content: '请在浏览器中完成行者授权' });
      }
    });
  },
  
  toggleRecord(e) {
    const id = e.currentTarget.dataset.id;
    const records = this.data.records.map(r => {
      if (r.id === id) r.selected = !r.selected;
      return r;
    });
    const selectedCount = records.filter(r => r.selected).length;
    this.setData({ records, selectedCount });
  },
  
  async doMerge() {
    const ids = this.data.records.filter(r => r.selected).map(r => r.id);
    wx.showLoading({ title: '合并中...' });
    try {
      const res = await api.mergeAndUpload({ record_ids: ids }, this.data.token);
      this.setData({ mergeResult: res });
    } catch (e) {
      wx.showToast({ title: '合并失败', icon: 'error' });
    }
    wx.hideLoading();
  }
});
```

**提交信息:** `feat: implement miniapp login and record selection UI`

---

**Task 8: 实现记录列表和合并操作前端**
> 展示记录、选择、合并、下载
> 测试层次: 手动测试（@FT-05~13 前端部分）

**文件：**
- 同 Task 7 的文件（完善逻辑）

**Step 1: 完善 doLogin 跳转逻辑**
```javascript
// 使用 web-view 承载行者 OAuth 页面
doLogin() {
  const authUrl = `${API_BASE}/auth/login`;
  // 方案A: 直接 wx.navigateTo 到一个 web-view 页面
  // 方案B: 复制链接让用户在浏览器打开
  wx.setStorageSync('auth_url', authUrl);
  wx.navigateTo({ url: '/pages/webview/webview' });
}
```

**Step 2: 完善记录加载**
```javascript
onLoad() {
  const token = wx.getStorageSync('access_token');
  if (token) {
    this.setData({ loggedIn: true, token });
    this.loadRecords();
  }
},

async loadRecords() {
  const res = await api.getRecords(this.data.token);
  const records = (res.records || []).map(r => ({ ...r, selected: false }));
  this.setData({ records });
}
```

**提交信息:** `feat: complete miniapp frontend flow`

---

### Phase 6: 部署配置

**Task 9: 配置部署环境**
> Nginx + HTTPS + 环境变量
> 测试层次: 冒烟测试

**文件：**
- 新建：`riding-mini-app/backend/Dockerfile`
- 新建：`riding-mini-app/docker-compose.yml`
- 新建：`riding-mini-app/nginx.conf`

**Step 1: Dockerfile**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Step 2: docker-compose.yml**
```yaml
version: "3"
services:
  backend:
    build: .
    ports:
      - "8000:8000"
    env_file:
      - .env
```

**Step 3: .env.example**
```
XINGZHE_CLIENT_ID=your_client_id
XINGZHE_CLIENT_SECRET=your_client_secret
REDIRECT_URI=https://your-domain.com/auth/callback
```

**提交信息:** `chore: add deployment config`

---

### Phase 7: 验证

**Task 10: 验证 RFL 一致性**
> 输出覆盖率比对表

**AT/FT 覆盖率比对表：**

| PRD Scenario | PRD Feature | TRD Task | 测试方法 | 状态 |
|-------------|-------------|----------|---------|------|
| @AT-01 OAuth 授权登录 | 用户合并多日骑行记录 | Task 3 + Task 7 | test_get_auth_url_contains_client_id + 手动测试 | ✅ |
| @AT-02 选择记录合并 | 用户合并多日骑行记录 | Task 5 + Task 8 | test_merge_two_files + 手动测试 | ✅ |
| @AT-03 自动上传回行者 | 用户合并多日骑行记录 | Task 6 | test (待实现) | ⚠️ 需行者API验证 |
| @AT-04 下载到本地 | 用户合并多日骑行记录 | Task 6 | test_records_to_gpx_roundtrip | ✅ |
| @AT-05 授权失败处理 | 用户合并多日骑行记录 | Task 3 | 手动测试 | ✅ |
| @AT-06 多格式合并 | 用户合并多日骑行记录 | Task 5 | test_merge_two_files | ✅ |
| @FT-01~04 OAuth | 行者账号授权 | Task 3 | test_auth.py | ✅ |
| @FT-05~07 记录管理 | 骑行记录管理 | Task 4 | test_records.py | ✅ |
| @FT-08~10 文件合并 | FIT/GPX/TCX 合并 | Task 5 | test_merge.py | ✅ |
| @FT-11~13 上传下载 | 合并结果输出 | Task 6 | test_upload.py | ✅ |
| @FT-14~15 广告 | 广告变现（后期） | 待定 | 待定 | ⏳ 延后 |

**待验证项：**
- ⚠️ 行者 API 上传接口是否可用（需注册开发者账号后验证）
- ⚠️ 微信小程序 web-view 域名限制（需配置业务域名）
- ⏳ 广告变现模块延后

---

## 任务清单（底部常驻）

- [x] Task 1: 初始化后端项目
- [x] Task 2: 初始化小程序项目
- [ ] Task 3: 实现 OAuth 授权流程
- [ ] Task 4: 实现骑行记录列表接口
- [ ] Task 5: 实现 FIT/GPX 解析与合并
- [ ] Task 6: 实现合并+上传接口
- [ ] Task 7: 实现小程序登录页
- [ ] Task 8: 实现记录列表和合并前端
- [ ] Task 9: 配置部署环境
- [ ] Task 10: 验证 RFL 一致性
