import os
from pathlib import Path

# 自动加载项目根目录的 .env 文件
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

XINGZHE_CLIENT_ID = os.getenv("XINGZHE_CLIENT_ID", "")
XINGZHE_CLIENT_SECRET = os.getenv("XINGZHE_CLIENT_SECRET", "")
XINGZHE_AUTH_URL = "https://www.imxingzhe.com/oauth2/v2/authorize"
XINGZHE_TOKEN_URL = "https://www.imxingzhe.com/oauth2/v2/access_token/"
XINGZHE_API_BASE = "https://www.imxingzhe.com/openapi/v1"
REDIRECT_URI = os.getenv("REDIRECT_URI", "http://localhost:8000/auth/callback")
