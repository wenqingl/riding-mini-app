from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth, records, merge

app = FastAPI(title="行者骑行数据合并工具")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: restrict to actual domain in production
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(records.router, prefix="/api", tags=["records"])
app.include_router(merge.router, prefix="/api", tags=["merge"])

@app.get("/health")
async def health():
    return {"status": "ok"}
