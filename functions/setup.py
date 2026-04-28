import os
from pathlib import Path

try:
    import prettyconfi
    from prettyconfi.web import WebRunner
    PRETTYCONFI_AVAILABLE = True
except ImportError:
    PRETTYCONFI_AVAILABLE = False

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_DIR = BASE_DIR / "config"
SCHEMA_PATH = CONFIG_DIR / "setup.toml"
ENV_PATH = CONFIG_DIR / "db_config.env"

def get_schema_data():
    if not PRETTYCONFI_AVAILABLE:
        return {"error": "prettyconfi not installed."}
    
    try:
        schemas = prettyconfi.load_schemas([SCHEMA_PATH])
        composed = prettyconfi.compose(schemas)
        schema_json = WebRunner.to_json_schema(composed)
        
        # Merge existing values if present
        existing = {}
        if ENV_PATH.is_file():
            from dotenv import dotenv_values
            existing = dotenv_values(ENV_PATH)
        
        for field in schema_json.get("fields", []):
            k = field["key"]
            if k in existing:
                field["current_value"] = existing[k]
            elif k in os.environ:
                field["current_value"] = os.environ[k]
                
        return schema_json
    except Exception as e:
        return {"error": str(e)}

def save_config(data: dict):
    if not PRETTYCONFI_AVAILABLE:
        return {"error": "prettyconfi not installed."}, 500
        
    try:
        schemas = prettyconfi.load_schemas([SCHEMA_PATH])
        composed = prettyconfi.compose(schemas)
        
        answers, errors = WebRunner.validate(composed, data)
        if errors:
            return {"errors": errors}, 400
            
        CONFIG_DIR.mkdir(exist_ok=True)
        prettyconfi.to_env(answers, ENV_PATH)
        
        return {"status": "ok", "message": "Configuration saved."}, 200
    except Exception as e:
        return {"error": str(e)}, 500
