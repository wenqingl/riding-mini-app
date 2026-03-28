import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth, records, merge

app = FastAPI(title="行者骑行数据合并工具")

# 允许的源：从环境变量读取，默认本地开发
_allowed_origins = os.getenv("CORS_ORIGINS", "http://localhost,http://localhost:8080").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(records.router, prefix="/api", tags=["records"])
app.include_router(merge.router, prefix="/api", tags=["merge"])

@app.get("/health")
async def health():
    return {"status": "ok"}
