import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


class CoreAIRuntimePackagingTests(unittest.TestCase):
    def test_host_manifest_sdk_and_resources_survive_temporary_build(self):
        script = Path(__file__).resolve().parents[1] / "tools/prepare-coreai-runtime.py"
        spec = importlib.util.spec_from_file_location("coreai_packaging", script)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Vendor/CoreAIRecoveryRuntime").mkdir(parents=True)
            commands = []

            def output(command, **kwargs):
                if command[-1] == "--show-sdk-version":
                    return "27.0\n"
                if command[-1] == "--show-sdk-path":
                    return "/sdk/" + command[2] + "\n"
                return str(Path(command[command.index("--scratch-path") + 1]) / "release")

            def run(command, **kwargs):
                if "build" not in command:
                    return
                commands.append((command, kwargs["env"]))
                destination = Path(output(command))
                destination.mkdir(parents=True)
                (destination / "libCoreAIRecoveryRuntime.dylib").write_bytes(b"synthetic runtime")
                resource = destination / "Tokenizer.bundle"
                resource.mkdir()
                (resource / "tokenizer.json").write_text("{}")

            environment = dict(PLATFORM_NAME="iphoneos", SDKROOT="/sdk/iphoneos",
                               SWIFTC_PASS_SDKROOT="YES", BUILT_PRODUCTS_DIR=str(root),
                               FRAMEWORKS_FOLDER_PATH="Takupoke.app/Frameworks", SRCROOT=str(root),
                               TARGET_TEMP_DIR=str(root), CODE_SIGNING_ALLOWED="NO")
            with patch.dict(os.environ, environment, clear=True), \
                    patch.object(module.subprocess, "check_output", side_effect=output), \
                    patch.object(module.subprocess, "run", side_effect=run):
                module.main()
            command, child_environment = commands[0]
            self.assertEqual(child_environment["SDKROOT"], "/sdk/macosx")
            self.assertNotIn("SWIFTC_PASS_SDKROOT", child_environment)
            self.assertEqual(command[command.index("--triple") + 1], "arm64-apple-ios27.0")
            self.assertEqual(command[command.index("--sdk", 3) + 1], "/sdk/iphoneos")
            self.assertFalse(Path(command[command.index("--scratch-path") + 1]).exists())
            app = root / "Takupoke.app"
            self.assertTrue((app / "Frameworks/CoreAIRecoveryRuntime.framework/CoreAIRecoveryRuntime").is_file())
            self.assertEqual((app / "Tokenizer.bundle/tokenizer.json").read_text(), "{}")


if __name__ == "__main__":
    unittest.main()
