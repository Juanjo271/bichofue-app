import os
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()

class Config:
    # Flask
    SECRET_KEY = os.environ.get('SECRET_KEY', '')
    DEBUG = True
    PORT = 5000
    HOST = '0.0.0.0'  # Escuchar en todas las interfaces de red
    
    # Mapbox API Key (configurar via variable de entorno o .env)
    MAPBOX_API_KEY = os.environ.get('MAPBOX_API_KEY', '')
    
    # OpenCode Go API (fallback opcional)
    OPENCODE_GO_API_KEY = os.environ.get('OPENCODE_GO_API_KEY', '')
    OPENCODE_GO_MODEL = os.environ.get('OPENCODE_GO_MODEL', 'qwen3.5-plus')
    OPENCODE_GO_BASE_URL = 'https://opencode.ai/zen/go/v1'
    
    # Ollama (IA local - proveedor principal)
    OLLAMA_BASE_URL = os.environ.get('OLLAMA_BASE_URL', 'http://localhost:11434/v1')
    OLLAMA_MODEL = os.environ.get('OLLAMA_MODEL', 'gemma3:4b')
    USE_LOCAL_LLM = os.environ.get('USE_LOCAL_LLM', 'true').lower() == 'true'
    
    # Base de datos SQLite
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    DATABASE_PATH = os.path.join(BASE_DIR, 'database', 'caliguia.db')
    
    # Audio / TTS
    AUDIO_CACHE_DIR = os.path.join(BASE_DIR, 'audio_cache')
    
    # mDNS
    MDNS_SERVICE_NAME = 'CaliGuia Backend'
    MDNS_SERVICE_TYPE = '_caliguia._tcp.local.'
    MDNS_PORT = 5000
    
    # Geofencing
    GEOFENCING_RADIUS_METERS = 500  # Alertar cuando esté a 500m
    
    # Eventos
    EVENT_CHECK_INTERVAL_SECONDS = 30
