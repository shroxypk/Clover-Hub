"""Offline regression tests for the deterministic release builder."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build as builder


MODULES = (
    "03_minigames_fix.lua",
    "06_parry_learning.lua",
    "07_attack_catalog.lua",
    "08_parry_timing.lua",
    "09_attack_inference.lua",
    "attack_seed.lua",
)


class BuildTests(unittest.TestCase):
    def test_bundle_is_deterministic_and_detects_stale_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            hub = "".join(
                f'loadstring(readfile("CloverRPG/{name}"),"{name}")()\n'
                for name in MODULES
            )
            (root / "00_hub.lua").write_text(hub, encoding="utf-8")
            for name in MODULES:
                # Real source files may use Windows CRLF; release must be LF-only.
                line = b"return {}\r\n" if name == "attack_seed.lua" else b"return {}\n"
                (root / name).write_bytes(line)

            with patch.object(builder, "ROOT", root):
                builder.build()
                first = (root / "main.lua").read_bytes()
                self.assertNotIn(b"\r", first)
                builder.build(check=True)
                self.assertEqual((root / "main.lua").read_bytes(), first)

                (root / "03_minigames_fix.lua").write_text(
                    "return {changed = true}\n", encoding="utf-8"
                )
                with self.assertRaises(SystemExit):
                    builder.build(check=True)
                self.assertEqual((root / "main.lua").read_bytes(), first)

                builder.build()
                builder.build(check=True)
                self.assertNotEqual((root / "main.lua").read_bytes(), first)


if __name__ == "__main__":
    unittest.main()
