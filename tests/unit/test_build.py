"""Offline checks for reproducible Veyra builds."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import build as builder


class BuildTests(unittest.TestCase):
    def test_reproducible_bundle_and_stale_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            src = root / "src"
            src.mkdir()
            runtime = "".join(
                f'loadstring(readfile("Veyra/src/{name}"),"{name}")()\n'
                for name, _ in builder.MODULES
            )
            (src / "runtime.lua").write_text(runtime, encoding="utf-8")
            for name, _ in builder.MODULES:
                line = b"return {}\r\n" if name == "attack_seed.lua" else b"return {}\n"
                (src / name).write_bytes(line)

            with patch.object(builder, "ROOT", root):
                builder.build()
                before = (root / "main.lua").read_bytes()
                self.assertNotIn(b"\r", before)
                builder.build(check=True)
                self.assertEqual((root / "main.lua").read_bytes(), before)

                (src / "minigames.lua").write_text("return {changed=true}\n", encoding="utf-8")
                with self.assertRaises(SystemExit):
                    builder.build(check=True)
                self.assertEqual((root / "main.lua").read_bytes(), before)

                builder.build()
                builder.build(check=True)
                self.assertNotEqual((root / "main.lua").read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
