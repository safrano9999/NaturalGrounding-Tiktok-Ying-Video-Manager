#!/usr/bin/env python3
"""Interactive configuration using prettyconfig."""

import sys
from pathlib import Path

try:
    import prettyconfig
except ImportError:
    print("Error: prettyconfig not installed. Run: pip install prettyconfig[cli]")
    sys.exit(1)

def main():
    config_dir = Path(__file__).resolve().parent / "config"
    config_dir.mkdir(exist_ok=True)
    
    schema_path = config_dir / "setup.toml"
    out_path = config_dir / "db_config.env"
    
    print("=======================================================")
    print("   NATURAL GROUNDING VIDEO MANAGER - CONFIGURATION")
    print("=======================================================\n")
    
    schemas = prettyconfig.load_schemas([schema_path])
    composed = prettyconfig.compose(schemas)
    
    runner = prettyconfig.CLIRunner(composed)
    answers = runner.run()
    
    prettyconfig.to_env(answers, out_path)
    print(f"\n✓ Configuration saved to {out_path.relative_to(Path.cwd())}")

if __name__ == "__main__":
    main()
