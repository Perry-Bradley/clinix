import os
from pathlib import Path

apps_dir = Path('apps')
for app_dir in apps_dir.iterdir():
    if app_dir.is_dir():
        apps_py_path = app_dir / 'apps.py'
        if apps_py_path.exists():
            content = apps_py_path.read_text()
            # replace name = 'app_name' with name = 'apps.app_name'
            app_name = app_dir.name
            if f"name = '{app_name}'" in content:
                content = content.replace(f"name = '{app_name}'", f"name = 'apps.{app_name}'")
                apps_py_path.write_text(content)
                print(f"Fixed {apps_py_path}")
