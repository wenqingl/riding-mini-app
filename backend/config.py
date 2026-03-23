import os

XINGZHE_CLIENT_ID = os.getenv("XINGZHE_CLIENT_ID", "")
XINGZHE_CLIENT_SECRET = os.getenv("XINGZHE_CLIENT_SECRET", "")
XINGZHE_AUTH_URL = "https://www.imxingzhe.com/oauth2/v2/authorize"
XINGZHE_TOKEN_URL = "https://www.imxingzhe.com/oauth2/v2/token"
XINGZHE_API_BASE = "https://www.imxingzhe.com/api/v1"
REDIRECT_URI = os.getenv("REDIRECT_URI", "http://localhost:8000/auth/callback")
