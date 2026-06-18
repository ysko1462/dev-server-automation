"""
Lambda 함수 단위 테스트
boto3를 mock으로 대체하여 AWS 없이 실행 가능
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# 환경변수 설정 (테스트용)
os.environ["INSTANCE_ID"] = "i-0test1234567890ab"
os.environ["REGION"] = "ap-northeast-2"
os.environ["CODE_SERVER_PORT"] = "8080"

# lambda 디렉토리를 경로에 추가
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda"))
import lambda_function as lf


def _mock_ec2(state: str, public_ip: str = ""):
    """EC2 describe_instances mock 생성"""
    client = MagicMock()
    client.describe_instances.return_value = {
        "Reservations": [{
            "Instances": [{
                "State": {"Name": state},
                "PublicIpAddress": public_ip,
            }]
        }]
    }
    return client


class TestLambdaStates(unittest.TestCase):

    # ── stopped: EC2 시작 + 부팅 HTML ────────────────────────
    def test_stopped_starts_instance(self):
        client = _mock_ec2("stopped")
        resp = lf.lambda_handler({}, {}, _client=client)
        client.start_instances.assert_called_once_with(
            InstanceIds=[os.environ["INSTANCE_ID"]]
        )
        self.assertEqual(resp["statusCode"], 200)
        self.assertIn("15", resp["body"])           # 15초 새로고침

    # ── pending: 대기 HTML 반환, start 호출 안 함 ────────────
    def test_pending_returns_wait_page(self):
        client = _mock_ec2("pending")
        resp = lf.lambda_handler({}, {}, _client=client)
        client.start_instances.assert_not_called()
        self.assertEqual(resp["statusCode"], 200)
        self.assertIn("text/html", resp["headers"]["Content-Type"])

    # ── running with IP: 302 리다이렉트 ─────────────────────
    def test_running_with_ip_redirects(self):
        client = _mock_ec2("running", "1.2.3.4")
        resp = lf.lambda_handler({}, {}, _client=client)
        client.start_instances.assert_not_called()
        self.assertEqual(resp["statusCode"], 302)
        self.assertEqual(resp["headers"]["Location"], "http://1.2.3.4:8080")

    # ── running without IP: 대기 HTML (IP 미할당 순간) ──────
    def test_running_without_ip_waits(self):
        client = _mock_ec2("running", "")
        resp = lf.lambda_handler({}, {}, _client=client)
        self.assertEqual(resp["statusCode"], 200)

    # ── stopping: 대기 HTML ───────────────────────────────────
    def test_stopping_returns_wait_page(self):
        client = _mock_ec2("stopping")
        resp = lf.lambda_handler({}, {}, _client=client)
        self.assertEqual(resp["statusCode"], 200)

    # ── 환경변수 미설정: 에러 HTML ───────────────────────────
    def test_missing_instance_id_returns_error(self):
        original = lf.INSTANCE_ID
        lf.INSTANCE_ID = ""
        resp = lf.lambda_handler({}, {})
        lf.INSTANCE_ID = original
        self.assertEqual(resp["statusCode"], 200)
        self.assertIn("INSTANCE_ID", resp["body"])

    # ── EC2 API 예외: 에러 HTML ───────────────────────────────
    def test_ec2_exception_returns_error(self):
        client = MagicMock()
        client.describe_instances.side_effect = Exception("Connection error")
        resp = lf.lambda_handler({}, {}, _client=client)
        self.assertEqual(resp["statusCode"], 200)


class TestHelpers(unittest.TestCase):

    def test_redirect_response_structure(self):
        resp = lf.redirect_response("http://1.2.3.4:8080")
        self.assertEqual(resp["statusCode"], 302)
        self.assertEqual(resp["headers"]["Location"], "http://1.2.3.4:8080")
        self.assertEqual(resp["body"], "")

    def test_html_response_content_type(self):
        resp = lf.html_response("<html></html>")
        self.assertEqual(resp["statusCode"], 200)
        self.assertIn("text/html", resp["headers"]["Content-Type"])

    def test_code_server_port_env(self):
        """다른 포트 환경변수 반영 확인"""
        original_port = lf.CODE_SERVER_PORT
        lf.CODE_SERVER_PORT = "9090"
        client = _mock_ec2("running", "10.0.0.1")
        resp = lf.lambda_handler({}, {}, _client=client)
        self.assertIn("9090", resp["headers"]["Location"])
        lf.CODE_SERVER_PORT = original_port

    def test_booting_html_has_refresh(self):
        """부팅 HTML에 meta refresh 태그 포함 확인"""
        self.assertIn("http-equiv=\"refresh\"", lf.BOOTING_HTML)

    def test_pending_html_has_refresh(self):
        self.assertIn("http-equiv=\"refresh\"", lf.PENDING_HTML)


class TestGetInstanceInfo(unittest.TestCase):

    def test_returns_state_and_ip(self):
        client = _mock_ec2("running", "5.6.7.8")
        state, ip = lf.get_instance_info(client)
        self.assertEqual(state, "running")
        self.assertEqual(ip, "5.6.7.8")

    def test_returns_empty_ip_when_not_present(self):
        client = MagicMock()
        client.describe_instances.return_value = {
            "Reservations": [{"Instances": [{"State": {"Name": "stopped"}}]}]
        }
        state, ip = lf.get_instance_info(client)
        self.assertEqual(state, "stopped")
        self.assertEqual(ip, "")


if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(TestLambdaStates))
    suite.addTests(loader.loadTestsFromTestCase(TestHelpers))
    suite.addTests(loader.loadTestsFromTestCase(TestGetInstanceInfo))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
