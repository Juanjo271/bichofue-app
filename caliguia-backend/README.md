# Bichofué Cali - Backend

Servidor Flask + SocketIO para la app Bichofué Cali (Hackathon 2026).
Expone API REST y WebSocket para la app Flutter.

## Requisitos

- Python 3.10+
- pip
- Ollama (opcional, para IA local)

## Instalación

```bash
# 1. Crear entorno virtual
python -m venv venv

# 2. Activar
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# 3. Instalar dependencias
pip install -r requirements.txt
```

## Configuración

Crear archivo `.env` (opcional):

```env
MAPBOX_API_KEY=pk.eyJ1...
OLLAMA_BASE_URL=http://localhost:11434/v1
OLLAMA_MODEL=gemma3:4b
SECRET_KEY=tu-clave-secreta-aqui
```

## Ejecución

```bash
python app.py
```

El servidor arranca en `http://0.0.0.0:5000` y muestra tu IP local.

## Endpoints principales

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/api/discover` | GET | Verificar estado del servidor |
| `/api/attractions` | GET | Listar atractivos turísticos |
| `/api/attractions/nearby` | GET | Atractivos cercanos por GPS |
| `/api/chat` | POST | Chatbot con IA |
| `/api/chat/stream` | POST | Chatbot con streaming SSE |
| `/api/recognize` | POST | Reconocimiento visual de monumentos |
| `/api/tts/<id>` | GET | Audio TTS de atractivo |
| `/api/routes` | POST | Calcular rutas con Mapbox |
| `/api/auth/login` | POST | Login de usuarios |
| `/api/auth/register` | POST | Registro de usuarios |

## Para el demo

1. Conectar laptop y celular a la misma red WiFi (o hotspot)
2. Ejecutar `python app.py`
3. La app Flutter descubre automáticamente el servidor, o ingresar la IP manualmente

## Estructura

```
caliguia-backend/
├── app.py              # Servidor principal Flask + SocketIO
├── config.py           # Configuración
├── database.py         # Utilidades SQLite
├── requirements.txt    # Dependencias Python
├── api/                # Blueprints REST
│   ├── auth.py
│   └── crud_attractions.py
├── services/           # Servicios
│   ├── tts_service.py  # Text-to-Speech (Edge-TTS)
│   └── image_storage.py
├── database/           # Base de datos SQLite
├── static/             # Archivos estáticos
└── audio_cache/        # Cache de audios TTS (generado automáticamente)
```

## Notas

- El servidor usa SQLite (no requiere instalación de base de datos adicional)
- Los audios TTS se generan con Edge-TTS (voz colombiana SalomeNeural)
- El reconocimiento visual usa YOLO/Ultralytics
