"""
Lambda 함수: EC2 시작 및 code-server 리다이렉트
환경변수:
  INSTANCE_ID       - EC2 인스턴스 ID (필수)
  REGION            - AWS 리전 (기본: ap-northeast-2)
  CODE_SERVER_PORT  - code-server 포트 (기본: 8080)
"""

import boto3
import os

INSTANCE_ID = os.environ.get("INSTANCE_ID", "")
REGION = os.environ.get("REGION", "ap-northeast-2")
CODE_SERVER_PORT = os.environ.get("CODE_SERVER_PORT", "8080")


# ── AWS 클라이언트 (테스트 시 주입 가능) ─────────────────────
def _ec2_client():
    return boto3.client("ec2", region_name=REGION)


# ── 인스턴스 정보 조회 ────────────────────────────────────────
def get_instance_info(client=None):
    ec2 = client or _ec2_client()
    resp = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    inst = resp["Reservations"][0]["Instances"][0]
    return inst["State"]["Name"], inst.get("PublicIpAddress", "")


def start_instance(client=None):
    ec2 = client or _ec2_client()
    ec2.start_instances(InstanceIds=[INSTANCE_ID])


# ── HTTP 응답 헬퍼 ────────────────────────────────────────────
def redirect_response(url: str) -> dict:
    return {
        "statusCode": 302,
        "headers": {"Location": url},
        "body": "",
    }


def html_response(html: str) -> dict:
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html; charset=utf-8"},
        "body": html,
    }


# ── HTML 템플릿 ───────────────────────────────────────────────
_STYLE = """
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
       display:flex;align-items:center;justify-content:center;
       min-height:100vh;background:#0d1117;color:#e6edf3}
  .card{text-align:center;padding:2.5rem 3rem;
        background:#161b22;border:1px solid #30363d;border-radius:12px;
        max-width:420px;width:90%}
  .icon{font-size:2.8rem;margin-bottom:1rem}
  h2{font-size:1.4rem;margin-bottom:.5rem;font-weight:600}
  p{color:#8b949e;font-size:.9rem;line-height:1.5}
  .badge{display:inline-block;margin-top:1rem;padding:.35rem .75rem;
         background:#21262d;border:1px solid #30363d;border-radius:20px;
         font-size:.75rem;color:#58a6ff}
  .spinner{width:44px;height:44px;border:4px solid #21262d;
           border-top-color:#58a6ff;border-radius:50%;
           animation:spin 1s linear infinite;margin:0 auto 1.2rem}
  @keyframes spin{to{transform:rotate(360deg)}}
</style>
"""

BOOTING_HTML = f"""<!DOCTYPE html><html lang="ko"><head>
<meta charset="UTF-8"><meta http-equiv="refresh" content="15">
<title>서버 시작 중…</title>{_STYLE}</head><body>
<div class="card">
  <div class="spinner"></div>
  <h2>서버 기동 명령 전송됨</h2>
  <p>EC2 인스턴스가 시작되고 있습니다.<br>약 1~2분이 소요됩니다.</p>
  <span class="badge">15초마다 자동으로 상태를 확인합니다</span>
</div></body></html>"""

PENDING_HTML = f"""<!DOCTYPE html><html lang="ko"><head>
<meta charset="UTF-8"><meta http-equiv="refresh" content="10">
<title>서버 시작 중…</title>{_STYLE}</head><body>
<div class="card">
  <div class="spinner"></div>
  <h2>인스턴스 준비 중</h2>
  <p>EC2가 시작되고 있습니다. 잠시만 기다려 주세요.</p>
  <span class="badge">10초마다 자동으로 상태를 확인합니다</span>
</div></body></html>"""

ERROR_HTML = f"""<!DOCTYPE html><html lang="ko"><head>
<meta charset="UTF-8"><title>오류</title>{_STYLE}</head><body>
<div class="card">
  <div class="icon">⚠️</div>
  <h2>인스턴스를 찾을 수 없습니다</h2>
  <p>INSTANCE_ID 환경변수를 확인해 주세요.</p>
</div></body></html>"""


# ── Lambda 핸들러 ─────────────────────────────────────────────
def lambda_handler(event, context, _client=None):
    if not INSTANCE_ID:
        return html_response(ERROR_HTML)

    try:
        state, public_ip = get_instance_info(_client)
    except Exception as e:
        return html_response(ERROR_HTML)

    if state == "running":
        if public_ip:
            url = f"http://{public_ip}:{CODE_SERVER_PORT}"
            return redirect_response(url)
        # IP 미할당 상태 (극히 짧은 순간) → 대기
        return html_response(PENDING_HTML)

    if state == "stopped":
        start_instance(_client)
        return html_response(BOOTING_HTML)

    # pending / stopping / shutting-down
    return html_response(PENDING_HTML)
