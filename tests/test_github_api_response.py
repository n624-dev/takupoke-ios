"""Exercise the response parser that in-memory release fixtures replace."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import publish


class GitHubAPIResponseTests(unittest.TestCase):
    def test_successful_empty_delete_does_not_fail_after_remote_mutation(self):
        for flag in ("--method", "-X"):
            with self.subTest(flag=flag), patch.object(publish, "gh", return_value="") as command:
                self.assertIsNone(publish.api("repos/fictional/app/releases/assets/123", flag, "DELETE"))
                command.assert_called_once_with("api", "--header", "Cache-Control: no-cache",
                                                flag, "DELETE", "repos/fictional/app/releases/assets/123")

    def test_empty_json_reads_and_writes_are_still_rejected(self):
        for options in ((), ("--method", "GET"), ("--method", "POST"), ("--method", "PATCH"),
                        ("--raw-field", "body=DELETE")):
            with self.subTest(options=options), patch.object(publish, "gh", return_value=""):
                with self.assertRaises(json.JSONDecodeError):
                    publish.api("repos/fictional/app/releases/123", *options)

    def test_failed_delete_propagates_and_valid_json_is_parsed(self):
        error = subprocess.CalledProcessError(1, ["gh", "api"])
        with patch.object(publish, "gh", side_effect=error):
            with self.assertRaises(subprocess.CalledProcessError):
                publish.api("repos/fictional/app/releases/assets/123", "--method", "DELETE")
        with patch.object(publish, "gh", return_value='{"id":123}'):
            self.assertEqual(publish.api("repos/fictional/app/releases/123"), {"id": 123})


if __name__ == "__main__":
    unittest.main()
