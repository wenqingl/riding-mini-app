import json
from html import escape

from fastapi import APIRouter, Query, HTTPException
from fastapi.responses import RedirectResponse, HTMLResponse

from services.auth_service import get_auth_url, exchange_code_for_token, refresh_access_token

router = APIRouter()

# In-memory state store for CSRF protection (use Redis in production)
_state_store: dict[str, str] = {}


def _verify_state(state: str) -> None:
    if not state or state not in _state_store:
        raise HTTPException(status_code=400, detail="Invalid or missing state parameter")
    _state_store.pop(state)  # one-time use


@router.get("/login")
async def login():
    url, state = get_auth_url()
    _state_store[state] = state  # store for callback verification
    return RedirectResponse(url=url)


@router.get("/callback")
async def callback(code: str = Query(...), state: str = Query(default="")):
    _verify_state(state)

    token_data = await exchange_code_for_token(code)
    return {
        "access_token": token_data.get("access_token"),
        "refresh_token": token_data.get("refresh_token"),
    }


@router.get("/callback/web")
async def callback_web(code: str = Query(...), state: str = Query(default="")):
    _verify_state(state)

    token_data = await exchange_code_for_token(code)
    access_token = token_data.get("access_token") or ""
    refresh_token = token_data.get("refresh_token") or ""

    payload = json.dumps({
        "access_token": access_token,
        "refresh_token": refresh_token,
    })

    html = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Authorization Complete</title>
    <style>
      body {{ font-family: Arial, sans-serif; padding: 24px; }}
      .box {{ max-width: 520px; margin: 0 auto; }}
      pre {{ white-space: pre-wrap; word-break: break-all; background: #f5f5f5; padding: 12px; border-radius: 6px; }}
      button {{ padding: 8px 12px; border: 0; background: #4A90D9; color: #fff; border-radius: 4px; }}
    </style>
  </head>
  <body>
    <div class="box">
      <h2>Authorization complete</h2>
      <p>You can return to the mini program.</p>
      <button id="copy">Copy token</button>
      <pre id="token">{escape(access_token)}</pre>
    </div>
    <script src="https://res.wx.qq.com/open/js/jweixin-1.6.0.js"></script>
    <script>
      (function () {{
        var data = {payload};
        function post() {{
          if (window.wx && wx.miniProgram && wx.miniProgram.postMessage) {{
            wx.miniProgram.postMessage({{ data: data }});
          }}
        }}
        post();
        var copyBtn = document.getElementById('copy');
        copyBtn.addEventListener('click', function () {{
          var el = document.getElementById('token');
          var range = document.createRange();
          range.selectNodeContents(el);
          var sel = window.getSelection();
          sel.removeAllRanges();
          sel.addRange(range);
          try {{ document.execCommand('copy'); }} catch (e) {{}}
        }});
      }})();
    </script>
  </body>
</html>"""

    return HTMLResponse(content=html)


@router.post("/refresh")
async def refresh(refresh_token: str = Query(...)):
    token_data = await refresh_access_token(refresh_token)
    return {"access_token": token_data.get("access_token")}
