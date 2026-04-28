#!/usr/bin/env python3
"""Interactive configuration using prettyconfi."""

import sys
from pathlib import Path

try:
    import prettyconfi
except ImportError:
    print("Error: prettyconfi not installed. Run: pip install prettyconfi[cli]")
    sys.exit(1)

def main():
    config_dir = Path(__file__).resolve().parent / "config"
    config_dir.mkdir(exist_ok=True)
    
    schema_path = config_dir / "setup.toml"
    out_path = config_dir / "db_config.env"
    
    print("=======================================================")
    print("   NATURAL GROUNDING VIDEO MANAGER - CONFIGURATION")
    print("=======================================================\n")
    
    schemas = prettyconfi.load_schemas([schema_path])
    composed = prettyconfi.compose(schemas)
    
    runner = prettyconfi.CLIRunner(composed)
    answers = runner.run()
    
    prettyconfi.to_env(answers, out_path)
    print(f"\n✓ Configuration saved to {out_path.relative_to(Path.cwd())}")

if __name__ == "__main__":
    main()
