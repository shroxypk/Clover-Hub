"""Guard the read-only mechanics probe against accidental remote calls."""
import unittest
from pathlib import Path
SRC=Path(__file__).resolve().parents[2]/"tools/diagnostics/mechanics_probe.lua"

class MechanicsProbeTests(unittest.TestCase):
 def test_passive_recording_contract(self):
  text=SRC.read_text(encoding="utf-8")
  for required in ('GetDescendants()', 'GetAttributes()', 'AssemblyLinearVelocity',
                   'VeyraMechanicsProbe', 'JSONEncode(report)', '35 second capture complete'):
   self.assertIn(required,text)
  for forbidden in (':FireServer(', ':InvokeServer(', 'packet.send(', 'hookmetamethod(', 'sethiddenproperty('):
   self.assertNotIn(forbidden,text)

if __name__=="__main__":
 unittest.main()
