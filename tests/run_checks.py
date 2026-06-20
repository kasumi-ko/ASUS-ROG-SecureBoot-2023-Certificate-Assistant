from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
checks = [
    root / 'tests' / 'test_powershell_syntax.py',
    root / 'tests' / 'test_static.py',
    root / 'tests' / 'test_release_packaging.py',
    root / 'tests' / 'test_ui_v1.py',
    root / 'tests' / 'test_ui_layout.py',
    root / 'tests' / 'test_ui_minimum_geometry.py',
    root / 'tests' / 'test_state_machine.py',
    root / 'tests' / 'test_advanced_recovery.py',
]
for check in checks:
    subprocess.run([sys.executable, str(check)], check=True)
print('PYTHON_CHECKS_OK')
