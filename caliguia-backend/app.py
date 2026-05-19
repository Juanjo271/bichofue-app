#!/usr/bin/env python3
"""
CaliGuia Backend
================
Servidor Flask + SocketIO que corre en la laptop/PC.
Expone API REST y WebSocket para la app Flutter.

Como ejecutar:
    python app.py

O con Gunicorn (produccion):
    gunicorn -k eventlet -w 1 -b 0.0.0.0:5000 app:app
"""

import os
import sys
import sqlite3
import json
import requests
import eventlet
from datetime import datetime

from flask import Flask, request, jsonify, send_file, render_template_string, Response
from flask_socketio import SocketIO, emit, disconnect
from flask_cors import CORS
from werkzeug.utils import secure_filename

from config import Config
from api.crud_attractions import crud_bp
from api.auth import auth_bp, auth_required
from admin.dashboard import ADMIN_HTML
from services.image_storage import ImageStorageService
from services.vision_recognition import recognize_image
import database

# =============================================================================
# INICIALIZACION FLASK + SOCKETIO
# =============================================================================
app = Flask(__name__)
app.config.from_object(Config)
CORS(app, origins="*")  # Permite conexiones desde cualquier origen (red local)

# Registrar blueprints
app.register_blueprint(crud_bp)
app.register_blueprint(auth_bp)

# Inicializar tabla de usuarios (auth)
database.init_usuarios_table()

# Inicializar tablas de gamificación
database.init_estampas_tables()
database.seed_default_stamps()
database.seed_default_achievements()

# Inicializar tablas de eventos masivos y WiFi
database.init_eventos_masivos_table()
database.seed_eventos_masivos()
database.init_wifi_zones_table()
database.seed_wifi_zones()

# Servir archivos estaticos
ImageStorageService.init_storage()

# SocketIO con async_mode='eventlet' para soporte WebSocket estable
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# Asegurar directorios
os.makedirs(Config.AUDIO_CACHE_DIR, exist_ok=True)

# =============================================================================
# UTILIDADES BASE DE DATOS
# =============================================================================
from database import get_db_connection, dict_from_row

# =============================================================================
# API REST: ATRACTIVOS
# =============================================================================

@app.route('/api/discover', methods=['GET'])
def api_discover():
    """Endpoint para descubrimiento manual si mDNS falla."""
    return jsonify({
        'service': 'CaliGuia Backend',
        'version': '1.0.0',
        'status': 'online',
        'timestamp': datetime.now().isoformat(),
        'endpoints': {
            'attractions': '/api/attractions',
            'events': '/api/events',
            'recognize': '/api/recognize',
            'chat': '/api/chat',
            'routes': '/api/routes'
        }
    })


@app.route('/api/attractions', methods=['GET'])
def api_attractions_list():
    """Lista todos los atractivos turisticos."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Parametros opcionales
        profile_id = request.args.get('profile_id', type=int)
        emblematico = request.args.get('emblematico', type=int)
        
        query = "SELECT * FROM atractivos WHERE 1=1"
        params = []
        
        if emblematico is not None:
            query += " AND es_emblematico = ?"
            params.append(emblematico)
        
        query += " ORDER BY es_emblematico DESC, nombre ASC"
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        atractivos = []
        for row in rows:
            atr = dict_from_row(row)
            # Parsear intereses JSON
            if atr.get('intereses'):
                try:
                    atr['intereses'] = json.loads(atr['intereses'])
                except:
                    atr['intereses'] = []
            atractivos.append(atr)
        
        conn.close()
        
        return jsonify({
            'success': True,
            'count': len(atractivos),
            'data': atractivos
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/attractions/<int:atractivo_id>', methods=['GET'])
def api_attraction_detail(atractivo_id):
    """Detalle de un atractivo especifico."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM atractivos WHERE id = ?", (atractivo_id,))
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return jsonify({'success': False, 'error': 'Atractivo no encontrado'}), 404
        
        atr = dict_from_row(row)
        if atr.get('intereses'):
            try:
                atr['intereses'] = json.loads(atr['intereses'])
            except:
                atr['intereses'] = []
        
        return jsonify({'success': True, 'data': atr})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/attractions/nearby', methods=['GET'])
def api_attractions_nearby():
    """Atractivos cercanos a una coordenada GPS."""
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        radius = request.args.get('radius', default=2000, type=float)  # metros
        
        if lat is None or lon is None:
            return jsonify({'success': False, 'error': 'Se requieren lat y lon'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Obtener todos los atractivos con coordenadas y calcular distancia en Python
        # (SQLite basico no siempre tiene funciones trigonométricas)
        import math
        
        cursor.execute("""
            SELECT * FROM atractivos
            WHERE latitud IS NOT NULL AND longitud IS NOT NULL
        """)
        
        rows = cursor.fetchall()
        atractivos = []
        
        for row in rows:
            atr = dict_from_row(row)
            a_lat = atr.get('latitud')
            a_lon = atr.get('longitud')
            
            if a_lat is None or a_lon is None:
                continue
            
            # Fórmula de Haversine en Python
            R = 6371000  # Radio de la Tierra en metros
            phi1 = math.radians(lat)
            phi2 = math.radians(a_lat)
            dphi = math.radians(a_lat - lat)
            dlambda = math.radians(a_lon - lon)
            
            a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            distancia = R * c
            
            if distancia < radius:
                atr['distancia'] = round(distancia, 1)
                if atr.get('intereses'):
                    try:
                        atr['intereses'] = json.loads(atr['intereses'])
                    except:
                        atr['intereses'] = []
                atractivos.append(atr)
        
        # Ordenar por distancia
        atractivos.sort(key=lambda x: x['distancia'])
        atractivos = atractivos[:20]
        
        conn.close()
        
        return jsonify({
            'success': True,
            'count': len(atractivos),
            'center': {'lat': lat, 'lon': lon},
            'data': atractivos
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: EVENTOS
# =============================================================================

@app.route('/api/events', methods=['GET'])
def api_events_list():
    """Lista todos los eventos turisticos."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM eventos ORDER BY fecha_inicio ASC")
        rows = cursor.fetchall()
        eventos = [dict_from_row(row) for row in rows]
        conn.close()
        
        return jsonify({
            'success': True,
            'count': len(eventos),
            'data': eventos
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/events/current', methods=['GET'])
def api_events_current():
    """Eventos que estan ocurriendo actualmente (segun fecha del servidor)."""
    try:
        hoy = datetime.now().strftime('%Y-%m-%d')
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM eventos WHERE fecha_inicio <= ? AND fecha_fin >= ? ORDER BY fecha_inicio",
            (hoy, hoy)
        )
        rows = cursor.fetchall()
        eventos = [dict_from_row(row) for row in rows]
        conn.close()
        
        return jsonify({
            'success': True,
            'count': len(eventos),
            'today': hoy,
            'data': eventos
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: PERFILES
# =============================================================================

@app.route('/api/profiles', methods=['GET'])
def api_profiles_list():
    """Lista los perfiles de usuario disponibles."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM perfiles ORDER BY id")
        rows = cursor.fetchall()
        perfiles = [dict_from_row(row) for row in rows]
        conn.close()
        
        return jsonify({
            'success': True,
            'count': len(perfiles),
            'data': perfiles
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: RECONOCIMIENTO VISUAL (YOLO26 Experimental)
# =============================================================================

@app.route('/api/recognize', methods=['POST'])
def api_recognize():
    """
    Recibe una imagen y devuelve el atractivo identificado.
    
    Flujo:
    1. Intentar reconocimiento con YOLO26 (experimental)
    2. Si YOLO detecta algo y usuario está cerca: usar resultado
    3. Fallback a GPS siempre disponible
    """
    try:
        if 'image' not in request.files:
            return jsonify({'success': False, 'error': 'No se envio imagen'}), 400
        
        file = request.files['image']
        lat = request.form.get('lat', type=float)
        lon = request.form.get('lon', type=float)
        
        # === PASO 1: Intentar YOLO26 ===
        yolo_result = recognize_image(file, lat, lon)
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Buscar atractivo que corresponda a la detección YOLO
        detected_atr = None
        yolo_confidence = 0.0
        method = 'gps_fallback'
        experimental = False
        
        if yolo_result['detected'] and yolo_result['class_name']:
            experimental = True
            yolo_confidence = yolo_result['confidence']
            
            # Buscar atractivo que coincida con la clase detectada
            search_term = yolo_result['class_name'].replace('_', '%').replace('-', '%')
            cursor.execute("""
                SELECT *, 
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(latitud)) * 
                        cos(radians(longitud) - radians(?)) + 
                        sin(radians(?)) * sin(radians(latitud))
                    )) AS distancia
                FROM atractivos
                WHERE (nombre LIKE ? OR descripcion LIKE ? OR intereses LIKE ?)
                AND latitud IS NOT NULL AND longitud IS NOT NULL
                ORDER BY 
                    CASE 
                        WHEN nombre LIKE ? THEN 1
                        WHEN descripcion LIKE ? THEN 2
                        ELSE 3
                    END
                LIMIT 1
            """, (lat or 0, lon or 0, lat or 0, 
                  f'%{search_term}%', f'%{search_term}%', f'%{search_term}%',
                  f'%{search_term}%', f'%{search_term}%'))
            
            row = cursor.fetchone()
            if row:
                atr = dict_from_row(row)
                distance = atr.get('distancia', 9999)
                
                # Siempre confiar en YOLO cuando detecta algo con confianza suficiente
                # Esto permite reconocer monumentos desde cualquier ubicación (demo/testing)
                detected_atr = atr
                method = 'yolo26_experimental'
                print(f"[Recognize] YOLO detectó {yolo_result['class_name']} @ {yolo_confidence}, "
                      f"lugar identificado: {atr['nombre']}")
        
        # === PASO 2: Fallback GPS si YOLO no funcionó ===
        if detected_atr is None:
            if lat and lon:
                cursor.execute("""
                    SELECT *, 
                        (6371000 * acos(
                            cos(radians(?)) * cos(radians(latitud)) * 
                            cos(radians(longitud) - radians(?)) + 
                            sin(radians(?)) * sin(radians(latitud))
                        )) AS distancia
                    FROM atractivos
                    WHERE es_emblematico = 1 AND latitud IS NOT NULL AND longitud IS NOT NULL
                    ORDER BY distancia ASC
                    LIMIT 1
                """, (lat, lon, lat))
            else:
                cursor.execute("""
                    SELECT * FROM atractivos 
                    WHERE es_emblematico = 1 
                    ORDER BY RANDOM() 
                    LIMIT 1
                """)
            
            row = cursor.fetchone()
            if row:
                detected_atr = dict_from_row(row)
                distance = detected_atr.get('distancia', 9999)
                
                # Simular confianza basada en distancia
                if distance < 100:
                    yolo_confidence = 0.92
                    method = 'gps_precise'
                elif distance < 300:
                    yolo_confidence = 0.78
                    method = 'gps_hybrid'
                else:
                    yolo_confidence = 0.65
                    method = 'gps_fallback'
            else:
                conn.close()
                return jsonify({
                    'success': False,
                    'method': 'unknown',
                    'error': 'No se encontro ningun monumento emblematico'
                })
        
        atr = detected_atr
        raw_distance = atr.get('distancia', 0)
        # Si no hay GPS, no mostrar distancia (evita números gigantes de 0,0)
        distance = int(raw_distance) if lat is not None and lon is not None else None
        
        # === PASO 3: Verificar estampa asociada ===
        stamp_data = None
        stamp_unlocked = False
        already_claimed = False
        
        cursor.execute("SELECT * FROM estampas WHERE atractivo_id = ?", (atr['id'],))
        stamp_row = cursor.fetchone()
        
        # Umbral de confianza adaptativo: más permisivo para YOLO experimental
        confidence_threshold = 0.05 if method == 'yolo26_experimental' else 0.6
        
        if stamp_row and yolo_confidence >= confidence_threshold:
            stamp_data = database.dict_from_row(stamp_row)
            
            # Verificar si usuario autenticado ya tiene la estampa
            user_id = None
            try:
                from api.auth import get_current_user_id
                user_id = get_current_user_id()
            except:
                pass
            
            if user_id:
                cursor.execute(
                    "SELECT id FROM usuario_estampas WHERE user_id = ? AND estampa_id = ?",
                    (user_id, stamp_data['id'])
                )
                if cursor.fetchone():
                    already_claimed = True
                else:
                    # Reclamar automáticamente si confianza supera el umbral
                    cursor.execute(
                        "INSERT INTO visitas (user_id, atractivo_id, tipo, lat, lon) VALUES (?, ?, 'identificacion', ?, ?)",
                        (user_id, atr['id'], lat, lon)
                    )
                    cursor.execute(
                        "INSERT INTO usuario_estampas (user_id, estampa_id, atractivo_id) VALUES (?, ?, ?)",
                        (user_id, stamp_data['id'], atr['id'])
                    )
                    _update_achievement_progress(cursor, user_id, 'estampas')
                    _update_achievement_progress(cursor, user_id, 'visitas')
                    conn.commit()
                    stamp_unlocked = True
        
        conn.close()
        
        # Mensaje descriptivo para el usuario según el método usado
        if method == 'yolo26_experimental':
            detection_note = f"¡Detectado por la cámara! ({yolo_confidence:.0%} de confianza)"
        elif method == 'gps_precise':
            detection_note = f"¡Estás muy cerca! Te reconocí por proximidad ({int(distance)}m)"
        elif method == 'gps_hybrid':
            detection_note = f"Te reconocí por proximidad ({int(distance)}m)"
        else:
            detection_note = f"Lugar cercano encontrado ({int(distance)}m)" if distance else "Lugar encontrado"
        
        return jsonify({
            'success': True,
            'method': method,
            'confidence': round(yolo_confidence, 2),
            'experimental': experimental,
            'detection_note': detection_note,
            'stamp_unlocked': stamp_unlocked,
            'already_claimed': already_claimed,
            'data': {
                'place': atr['nombre'],
                'distance_meters': int(distance) if distance is not None else None,
                'atraction': atr,
                'stamp': stamp_data
            }
        })
        
    except Exception as e:
        import traceback
        print(f"[Recognize] Error: {e}")
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: RUTAS (Dia 6 - Waze Turistico MVP)
# =============================================================================

@app.route('/api/routes', methods=['POST'])
def api_route():
    """
    Calcula ruta entre posicion actual y destino.
    Usa Mapbox Directions API para rutas reales por calles.
    Fallback a linea recta si Mapbox falla.
    """
    try:
        data = request.get_json() or {}
        origin = data.get('origin')  # {lat, lon}
        destination = data.get('destination')  # {lat, lon}
        atraction_id = data.get('atraction_id')
        
        if not origin or not destination:
            if atraction_id:
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute("SELECT latitud, longitud FROM atractivos WHERE id = ?", (atraction_id,))
                row = cursor.fetchone()
                conn.close()
                if row:
                    destination = {'lat': row['latitud'], 'lon': row['longitud']}
                else:
                    return jsonify({'success': False, 'error': 'Atractivo no encontrado'}), 404
            else:
                return jsonify({'success': False, 'error': 'Se requiere origin+destination o atraction_id'}), 400
        
        lat1, lon1 = origin['lat'], origin['lon']
        lat2, lon2 = destination['lat'], destination['lon']
        
        # Intentar Mapbox Directions API
        mapbox_token = Config.MAPBOX_API_KEY
        mapbox_url = (
            f"https://api.mapbox.com/directions/v5/mapbox/walking/"
            f"{lon1},{lat1};{lon2},{lat2}"
        )
        
        try:
            import requests
            mb_response = requests.get(mapbox_url, params={
                'access_token': mapbox_token,
                'geometries': 'geojson',
                'steps': 'true',
                'language': 'es',
                'overview': 'full'
            }, timeout=5)
            
            if mb_response.status_code == 200:
                mb_data = mb_response.json()
                if 'routes' in mb_data and len(mb_data['routes']) > 0:
                    route = mb_data['routes'][0]
                    geometry = route['geometry']
                    coords = geometry['coordinates']  # [[lon, lat], ...]
                    distance = route['distance']
                    duration = route['duration']
                    
                    # Extraer instrucciones de navegacion
                    steps = []
                    for leg in route.get('legs', []):
                        for step in leg.get('steps', []):
                            steps.append({
                                'instruction': step.get('maneuver', {}).get('instruction', ''),
                                'distance': step.get('distance', 0),
                                'duration': step.get('duration', 0),
                            })
                    
                    return jsonify({
                        'success': True,
                        'data': {
                            'distance_meters': round(distance),
                            'duration_minutes': round(duration / 60),
                            'method': 'mapbox_directions',
                            'coordinates': coords,
                            'steps': steps
                        }
                    })
        except Exception as e:
            print(f'[Routes] Mapbox fallo: {e}, usando fallback')
        
        # Fallback: linea recta Haversine
        import math
        R = 6371000
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lon2 - lon1)
        a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        distance = R * c
        
        steps_fallback = 20
        coordinates = []
        for i in range(steps_fallback + 1):
            t = i / steps_fallback
            lat = lat1 + (lat2 - lat1) * t
            lon = lon1 + (lon2 - lon1) * t
            coordinates.append([lon, lat])
        
        duration_min = (distance / 1000) / 5 * 60
        
        return jsonify({
            'success': True,
            'data': {
                'distance_meters': round(distance),
                'duration_minutes': round(duration_min),
                'method': 'straight_line_fallback',
                'coordinates': coordinates,
                'steps': [{'instruction': f'Camina hacia el destino ({round(distance)}m)', 'distance': round(distance), 'duration': round(duration_min * 60)}]
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: EVENTOS (Dia 6 - Geofencing)
# =============================================================================

@app.route('/api/events/nearby', methods=['GET'])
def api_events_nearby():
    """
    Devuelve eventos activos cerca de una posicion (geofencing).
    """
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        radius = request.args.get('radius', default=200, type=float)
        
        if not lat or not lon:
            return jsonify({'success': False, 'error': 'Se requiere lat y lon'}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM (
                SELECT *,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(latitud)) * 
                        cos(radians(longitud) - radians(?)) + 
                        sin(radians(?)) * sin(radians(latitud))
                    )) AS distancia
                FROM eventos
                WHERE latitud IS NOT NULL AND longitud IS NOT NULL
                    AND fecha_inicio <= datetime('now')
                    AND fecha_fin >= datetime('now')
            )
            WHERE distancia < ?
            ORDER BY distancia ASC
        """, (lat, lon, lat, radius))
        rows = cursor.fetchall()
        conn.close()
        
        return jsonify({
            'success': True,
            'count': len(rows),
            'data': [dict_from_row(r) for r in rows]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: EVENTOS MASIVOS (Modo Evento)
# =============================================================================

@app.route('/api/events/massive', methods=['GET'])
def api_events_massive():
    """Devuelve todos los eventos masivos de Cali."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM eventos_masivos ORDER BY fecha_inicio DESC")
        rows = cursor.fetchall()
        conn.close()
        return jsonify({
            'success': True,
            'count': len(rows),
            'data': [dict_from_row(r) for r in rows]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/events/massive/active', methods=['GET'])
def api_events_massive_active():
    """Devuelve eventos masivos activos hoy."""
    try:
        today = datetime.now().strftime('%Y-%m-%d')
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM eventos_masivos
            WHERE activo = 1
            AND fecha_inicio <= ?
            AND fecha_fin >= ?
            ORDER BY fecha_inicio ASC
        """, (today, today))
        rows = cursor.fetchall()
        conn.close()
        return jsonify({
            'success': True,
            'count': len(rows),
            'data': [dict_from_row(r) for r in rows]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/events/massive/nearby', methods=['GET'])
def api_events_massive_nearby():
    """Devuelve eventos masivos activos cerca del usuario."""
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        if not lat or not lon:
            return jsonify({'success': False, 'error': 'Se requiere lat y lon'}), 400

        today = datetime.now().strftime('%Y-%m-%d')
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT *,
                (6371000 * acos(
                    cos(radians(?)) * cos(radians(lat)) *
                    cos(radians(lon) - radians(?)) +
                    sin(radians(?)) * sin(radians(lat))
                )) AS distancia
            FROM eventos_masivos
            WHERE activo = 1
            AND fecha_inicio <= ?
            AND fecha_fin >= ?
            HAVING distancia < radio_meters
            ORDER BY distancia ASC
        """, (lat, lon, lat, today, today))
        rows = cursor.fetchall()
        conn.close()
        return jsonify({
            'success': True,
            'count': len(rows),
            'data': [dict_from_row(r) for r in rows]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: ZONAS WIFI
# =============================================================================

@app.route('/api/wifi/zones', methods=['GET'])
def api_wifi_zones():
    """Devuelve zonas WiFi cercanas al usuario."""
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        radius = request.args.get('radius', default=2000, type=float)

        conn = get_db_connection()
        cursor = conn.cursor()

        if lat and lon:
            cursor.execute("""
                SELECT *,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(lat)) *
                        cos(radians(lon) - radians(?)) +
                        sin(radians(?)) * sin(radians(lat))
                    )) AS distancia
                FROM wifi_zones
                HAVING distancia < ?
                ORDER BY distancia ASC
                LIMIT 20
            """, (lat, lon, lat, radius))
        else:
            cursor.execute("SELECT * FROM wifi_zones LIMIT 20")

        rows = cursor.fetchall()
        conn.close()
        return jsonify({
            'success': True,
            'count': len(rows),
            'data': [dict_from_row(r) for r in rows]
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# SERVIR ARCHIVOS DE AUDIO
# =============================================================================

@app.route('/audio/<path:filename>')
def serve_audio(filename):
    """Sirve archivos de audio TTS generados."""
    try:
        audio_path = os.path.join(Config.AUDIO_CACHE_DIR, filename)
        if os.path.exists(audio_path):
            return send_file(audio_path, mimetype='audio/mpeg')
        return jsonify({'success': False, 'error': 'Audio no encontrado'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/tts/<int:atractivo_id>', methods=['GET'])
def api_tts(atractivo_id):
    """Genera y sirve audio TTS para un atractivo."""
    print(f'[TTS] 📞 Solicitud recibida: atractivo_id={atractivo_id}')
    try:
        from services.tts_service import EdgeTTSService
        
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT descripcion, descripcion_caleña FROM atractivos WHERE id = ?", (atractivo_id,))
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            print(f'[TTS] ❌ Atractivo {atractivo_id} no encontrado')
            return jsonify({'success': False, 'error': 'Atractivo no encontrado'}), 404
        
        # Usar descripción caleña si existe, sino la descripción normal
        text = row['descripcion_caleña'] or row['descripcion']
        print(f'[TTS] 📝 Texto para TTS ({len(text)} chars): {text[:100]}...')
        
        if not text:
            return jsonify({'success': False, 'error': 'Sin descripción para TTS'}), 400
        
        filename = f"atractivo_{atractivo_id}"
        print(f'[TTS] 🎙️ Generando audio con filename={filename}...')
        audio_path = EdgeTTSService.generate_audio(text, filename)
        print(f'[TTS] 📁 Audio generado: {audio_path}')
        
        if audio_path and os.path.exists(audio_path):
            file_size = os.path.getsize(audio_path)
            print(f'[TTS] ✅ Sirviendo audio: {audio_path} ({file_size} bytes)')
            return send_file(audio_path, mimetype='audio/mpeg')
        else:
            print(f'[TTS] ❌ Archivo no existe: {audio_path}')
            return jsonify({'success': False, 'error': 'Error generando audio'}), 500
            
    except Exception as e:
        print(f'[TTS] ❌ Error completo: {e}')
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# API REST: CHATBOT (Placeholder para Dia 4-5)
# =============================================================================

@app.route('/api/chat', methods=['POST'])
def api_chat():
    """
    Chatbot inteligente con identidad caleña.
    Usa OpenCode Go (Kimi K2.6) + contexto de SQLite + TTS.
    """
    try:
        data = request.get_json() or {}
        message = data.get('message', '')
        lat = data.get('lat')
        lon = data.get('lon')
        
        if not message or not message.strip():
            return jsonify({'success': False, 'error': 'Mensaje vacio'}), 400
        
        # Construir contexto desde la base de datos
        context = _build_chat_context(lat, lon)
        print(f'[Chat] Contexto construido: {len(context)} chars')
        
        # Verificar API key
        api_key = Config.OPENCODE_GO_API_KEY
        print(f'[Chat] API key presente: {bool(api_key)}')
        
        if api_key:
            # Usar OpenCode Go (IA real)
            # System prompt con identidad caleña
            system_prompt = f"""Eres "Parce", un guia turistico caleño autentico, calido y divertido. Hablas EXCLUSIVAMENTE con expresiones caleñas como "ve", "parce", "ois", "mijo", "que mas", "bacano", "chimba", "calidoso".

REGLAS:
1. Responde SIEMPRE en espanol colombiano con acento caleño.
2. Usa expresiones locales: "ve" (al final de frases), "parce" (amigo), "ois" (oye), "bacano" (chévere), "chimba" (genial), "calidoso" (agradable).
3. Responde de forma concisa (maximo 3-4 oraciones) pero con calidez.
4. Si preguntan por lugares, usa el contexto de la base de datos proporcionado abajo.
5. Si sugieres un lugar, incluye su nombre exacto para que puedan buscarlo.
6. Si no sabes algo, di "Ois, ve, eso no me lo se bien, pero en Cali siempre hay algo bacano pa hacer".
7. NUNCA uses markdown, listas ni emojis. Solo texto plano con mucho sentimiento caleño.

CONTEXTO DE LA BASE DE DATOS:
{context}

UBICACION DEL USUARIO: {f"Lat {lat}, Lon {lon}" if lat and lon else "Desconocida"}
"""
            
            # Llamar a OpenCode Go API
            headers = {
                'Authorization': f'Bearer {api_key}',
                'Content-Type': 'application/json'
            }
            
            payload = {
                'model': Config.OPENCODE_GO_MODEL,
                'messages': [
                    {'role': 'system', 'content': system_prompt},
                    {'role': 'user', 'content': message}
                ],
                'temperature': 0.8,
                'max_tokens': 300
            }
            
            try:
                print(f'[Chat] Enviando peticion a OpenCode Go: model={Config.OPENCODE_GO_MODEL}')
                response = requests.post(
                    f'{Config.OPENCODE_GO_BASE_URL}/chat/completions',
                    headers=headers,
                    json=payload,
                    timeout=15
                )
                print(f'[Chat] Respuesta recibida: status={response.status_code}')
                
                if response.status_code == 200:
                    result = response.json()
                    msg = result['choices'][0]['message']
                    content = msg.get('content')
                    
                    # Algunos modelos devuelven reasoning en lugar de content
                    if not content and msg.get('reasoning_content'):
                        content = msg['reasoning_content']
                    elif not content and msg.get('reasoning'):
                        content = msg['reasoning']
                    
                    if content and content.strip():
                        response_text = content.strip()
                        print(f'[Chat] Respuesta IA recibida ({len(response_text)} chars)')
                    else:
                        print(f'[Chat] IA devolvio content vacio, usando fallback')
                        response_text = _generate_local_response(message, context)
                else:
                    print(f'[Chat] Error OpenCode Go: {response.status_code} - {response.text[:200]}')
                    response_text = _generate_local_response(message, context)
            except Exception as e:
                print(f'[Chat] Error conectando a OpenCode Go: {e}')
                response_text = _generate_local_response(message, context)
        else:
            # Sin API key: usar respuestas locales inteligentes
            print('[Chat] Sin API key, usando respuestas locales')
            response_text = _generate_local_response(message, context)
        
        # Generar TTS para la respuesta
        audio_url = None
        try:
            from services.tts_service import EdgeTTSService
            audio_path = EdgeTTSService.generate_audio(
                response_text,
                output_filename=f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            )
            if audio_path:
                # Devolver URL relativa para que el Flutter la descargue
                filename = os.path.basename(audio_path)
                audio_url = f"/audio/{filename}"
        except Exception as e:
            print(f'[Chat] Error TTS: {e}')
        
        return jsonify({
            'success': True,
            'data': {
                'response': response_text,
                'tone': 'caleño',
                'audio_url': audio_url,
                'context_used': bool(context.strip())
            }
        })
    except Exception as e:
        print(f'[Chat] Error: {e}')
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/chat/stream', methods=['POST'])
def api_chat_stream():
    """
    Chatbot con streaming SSE usando Ollama (IA local).
    Devuelve la respuesta letra por letra + metadatos de ruta si aplica.
    """
    try:
        data = request.get_json() or {}
        message = data.get('message', '')
        lat = data.get('lat')
        lon = data.get('lon')
        preferences = data.get('preferences', {})
        
        if not message or not message.strip():
            return jsonify({'success': False, 'error': 'Mensaje vacio'}), 400
        
        # Idioma del usuario
        language = data.get('language', 'es')
        
        # Contexto SQLite + parseo de intencion
        context = _build_chat_context(lat, lon)
        route_intent = _parse_route_intent(message)
        
        # Si pide una ruta especifica, buscar lugar en SQLite
        route_meta = None
        if route_intent:
            route_meta = _resolve_route(route_intent, lat, lon, preferences)
        
        # Si pide algo ambiguo, armar circuito segun preferencias
        circuit_meta = None
        if not route_meta and _is_ambiguous_request(message):
            circuit_meta = _build_circuit_from_preferences(lat, lon, preferences)
        
        def generate_sse():
            accumulated_text = ''

            try:
                print(f'[ChatStream] Ollama: {Config.OLLAMA_MODEL} | route={bool(route_meta)} | circuit={bool(circuit_meta)}')

                # ================================================================
                # MODO CIRCUITO: respuesta local directa (sin Ollama)
                # ================================================================
                if circuit_meta:
                    circuit_text = _generate_circuit_response(circuit_meta)
                    accumulated_text = circuit_text
                    print(f'[ChatStream] Modo CIRCUITO — emitiendo respuesta local ({len(circuit_text)} chars)')

                    # Emitir todo el texto como un solo delta
                    yield f'data: {json.dumps({"delta": circuit_text, "done": False})}\n\n'
                    eventlet.sleep(0)

                    # Generar TTS
                    audio_url = None
                    try:
                        from services.tts_service import EdgeTTSService
                        audio_path = EdgeTTSService.generate_audio(
                            accumulated_text,
                            output_filename=f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                        )
                        if audio_path:
                            filename = os.path.basename(audio_path)
                            audio_url = f"/audio/{filename}"
                    except Exception as e:
                        print(f'[ChatStream] TTS error: {e}')

                    # Chunk final
                    final_payload = {
                        'delta': '',
                        'done': True,
                        'audio_url': audio_url,
                        'context_used': bool(context.strip()),
                        'full_response': accumulated_text,
                        'circuit': circuit_meta
                    }
                    yield f'data: {json.dumps(final_payload)}\n\n'
                    eventlet.sleep(0)
                    print(f'[ChatStream] Finalizado CIRCUITO ({len(accumulated_text)} chars)')
                    return

                # ================================================================
                # MODO NORMAL: llamar a Ollama (ruta específica o chat general)
                # ================================================================
                system_prompt = _build_system_prompt(context, preferences, lat, lon, language)
                route_instructions = _build_route_instructions(route_meta, circuit_meta)
                if route_instructions:
                    system_prompt += "\n\n" + route_instructions

                payload = {
                    'model': Config.OLLAMA_MODEL,
                    'messages': [
                        {'role': 'system', 'content': system_prompt},
                        {'role': 'user', 'content': message}
                    ],
                    'temperature': 0.8,
                    'max_tokens': 400,
                    'stream': True
                }

                with requests.post(
                    f'{Config.OLLAMA_BASE_URL}/chat/completions',
                    headers={'Content-Type': 'application/json'},
                    json=payload,
                    timeout=60,
                    stream=True
                ) as resp:
                    print(f'[ChatStream] Ollama status: {resp.status_code}')

                    if resp.status_code != 200:
                        error_msg = resp.text[:300]
                        print(f'[ChatStream] Ollama error: {error_msg}')
                        # Fallback local
                        fallback_text = _generate_local_response(message, context)
                        accumulated_text = fallback_text
                        yield f'data: {json.dumps({"delta": fallback_text, "done": False})}\n\n'
                        eventlet.sleep(0)
                    else:
                        for line in resp.iter_lines():
                            if not line:
                                continue

                            line_str = line.decode('utf-8')

                            if line_str.startswith('data: '):
                                data_str = line_str[6:]

                                if data_str == '[DONE]':
                                    break

                                try:
                                    chunk = json.loads(data_str)
                                    choices = chunk.get('choices', [])
                                    if choices:
                                        delta = choices[0].get('delta', {})
                                        content = delta.get('content', '')

                                        if content:
                                            accumulated_text += content
                                            sse_data = json.dumps({
                                                'delta': content,
                                                'done': False
                                            })
                                            yield f'data: {sse_data}\n\n'
                                            eventlet.sleep(0)
                                except json.JSONDecodeError:
                                    continue

                # Generar TTS
                audio_url = None
                try:
                    from services.tts_service import EdgeTTSService
                    audio_path = EdgeTTSService.generate_audio(
                        accumulated_text,
                        output_filename=f"chat_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                    )
                    if audio_path:
                        filename = os.path.basename(audio_path)
                        audio_url = f"/audio/{filename}"
                except Exception as e:
                    print(f'[ChatStream] TTS error: {e}')

                # Chunk final con metadatos de ruta
                final_payload = {
                    'delta': '',
                    'done': True,
                    'audio_url': audio_url,
                    'context_used': bool(context.strip()),
                    'full_response': accumulated_text
                }

                # Agregar metadatos de ruta si existen
                if route_meta:
                    final_payload['route'] = route_meta

                yield f'data: {json.dumps(final_payload)}\n\n'
                eventlet.sleep(0)
                print(f'[ChatStream] Finalizado ({len(accumulated_text)} chars)')

            except Exception as e:
                print(f'[ChatStream] Error: {e}')
                import traceback
                traceback.print_exc()
                yield f'data: {json.dumps({"delta": "", "done": True, "error": str(e)})}\n\n'
        
        return Response(
            generate_sse(),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
                'X-Accel-Buffering': 'no'
            }
        )
        
    except Exception as e:
        print(f'[ChatStream] Error general: {e}')
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# FUNCIONES AUXILIARES PARA CHAT CON IA LOCAL Y RUTAS INTELIGENTES
# =============================================================================

def _get_active_events_context(lat, lon):
    """Consulta eventos masivos activos cerca del usuario y devuelve contexto."""
    try:
        if not lat or not lon:
            return None
        today = datetime.now().strftime('%Y-%m-%d')
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT *,
                (6371000 * acos(
                    cos(radians(?)) * cos(radians(lat)) *
                    cos(radians(lon) - radians(?)) +
                    sin(radians(?)) * sin(radians(lat))
                )) AS distancia
            FROM eventos_masivos
            WHERE activo = 1
            AND fecha_inicio <= ?
            AND fecha_fin >= ?
            HAVING distancia < radio_meters
            ORDER BY distancia ASC
            LIMIT 1
        """, (lat, lon, lat, today, today))
        row = cursor.fetchone()
        conn.close()
        if row:
            return dict_from_row(row)
        return None
    except Exception as e:
        print(f'[EventsContext] Error: {e}')
        return None


def _build_system_prompt(context, preferences, lat, lon, language='es'):
    """Construye el system prompt dinamico con preferencias del usuario."""
    nombre = preferences.get('nombre', 'parce')
    edad = preferences.get('edad', '')
    genero = preferences.get('genero', '')
    origen = preferences.get('origen', '')
    hospedaje = preferences.get('hospedaje', '')
    grupo = preferences.get('grupo', '')
    duracion = preferences.get('duracion', '')
    presupuesto = preferences.get('presupuesto', '')
    intereses = preferences.get('intereses', [])
    perfil_id = preferences.get('perfil_id', 0)

    # Mapear perfil_id a descripcion
    perfiles_nombres = {
        1: 'Cultural y Salsa',
        2: 'Naturaleza y Ecoturismo',
        3: 'Turismo Comunitario',
        4: 'Turismo Deportivo',
        5: 'Turismo Medico y Bienestar',
        6: 'Turismo de Compras'
    }
    perfil_nombre = perfiles_nombres.get(perfil_id, 'General')

    intereses_str = ', '.join(intereses) if intereses else 'varios'

    # Instrucciones de idioma
    if language == 'en':
        idioma_instruccion = 'IMPORTANT: Respond in English. Use Colombian Cali expressions like "ve", "parce", "ois", "bacano", "chimba" but explain them briefly (e.g., "bacano" means cool/awesome). Keep the warm, authentic Colombian tone.'
    elif language == 'pt':
        idioma_instruccion = 'IMPORTANT: Respond in Portuguese. Use Colombian Cali expressions like "ve", "parce", "ois", "bacano", "chimba" but explain them briefly. Keep the warm, authentic Colombian tone.'
    else:
        idioma_instruccion = 'IMPORTANTE: Responde SIEMPRE en español colombiano con acento caleño.'

    # Detectar eventos activos cerca
    active_event = _get_active_events_context(lat, lon)
    evento_contexto = ""
    if active_event:
        evento_contexto = f"""
EVENTO MASIVO ACTIVO CERCA:
- Nombre: {active_event['nombre']}
- Descripcion: {active_event['descripcion']}
- Zona afectada: {active_event['zona_restringida']}
- Radio: {active_event['radio_meters']} metros
- Alerta: {active_event['alerta_caleña']}
REGLA DE EVENTO: Si el usuario pide una ruta o circuito, y el destino queda dentro de la zona del evento, sugiere rutas alternativas que eviten la congestion. Usa el tono caleño para avisarle: "Ois, ve, hoy hay {active_event['nombre']} y esa zona esta pesada. Te muestro otra vía bacana."
"""

    prompt = f"""Eres "Parce", un guia turistico caleño autentico, calido y divertido. Hablas EXCLUSIVAMENTE con expresiones caleñas como "ve", "parce", "ois", "mijo", "que mas", "bacano", "chimba", "calidoso".

DATOS DEL VIAJERO:
- Nombre: {nombre}
- Perfil turistico: {perfil_nombre}
- Edad: {edad or 'no especificada'}
- Genero: {genero or 'no especificado'}
- Origen: {origen or 'no especificado'}
- Alojamiento: {hospedaje or 'no especificado'}
- Grupo: {grupo or 'no especificado'}
- Duracion del viaje: {duracion or 'no especificada'} dias
- Presupuesto: {presupuesto or 'no especificado'}
- Intereses principales: {intereses_str}

REGLAS:
1. Responde SIEMPRE en espanol colombiano con acento caleño.
2. Usa expresiones locales: "ve" (al final de frases), "parce" (amigo), "ois" (oye), "bacano" (chevere), "chimba" (genial), "calidoso" (agradable).
3. Responde de forma concisa (maximo 3-4 oraciones) pero con calidez.
4. Personaliza las recomendaciones segun los datos del viajero arriba.
5. Si el viajero tiene presupuesto economico, sugiere opciones gratis o baratas.
6. Si el viajero viene en familia, sugiere lugares aptos para ninos.
7. Si el viajero prefiere salsa, menciona sitios de bailongo y rumba.
8. Si no sabes algo, di "Ois, ve, eso no me lo se bien, pero en Cali siempre hay algo bacano pa hacer".
9. NUNCA uses markdown, listas ni emojis. Solo texto plano con mucho sentimiento caleño.

IDIOMA:
{idioma_instruccion}

CONTEXTO DE LA BASE DE DATOS:
{context}
{evento_contexto}

UBICACION ACTUAL: {f"Lat {lat}, Lon {lon}" if lat and lon else "Desconocida"}
"""
    return prompt


def _build_route_instructions(route_meta, circuit_meta):
    """Instrucciones adicionales para formatear rutas en la respuesta."""
    if route_meta:
        destino = route_meta['destination_name']
        lat = route_meta['destination_lat']
        lon = route_meta['destination_lon']
        return f"""INSTRUCCION DE RUTA:
El usuario quiere ir a {destino}. Al final de tu respuesta, agrega EXACTAMENTE esta linea:
RUTA|{destino}|{lat},{lon}
"""
    
    if circuit_meta:
        paradas = circuit_meta['stops']
        stops_text = "\n".join([f"{i+1}. {s['nombre']} ({s['lat']},{s['lon']})" for i, s in enumerate(paradas)])
        return f"""INSTRUCCION DE CIRCUITO:
El usuario quiere un recorrido. Sugierele estas paradas en orden y agrega EXACTAMENTE al final:
CIRCUITO|{circuit_meta['name']}|{len(paradas)}
{stops_text}
"""
    
    return None


def _parse_route_intent(message):
    """Detecta si el usuario pide una ruta a un lugar especifico."""
    msg_lower = message.lower()
    
    # Patrones de ruta especifica
    patterns = [
        r'(?:como|quiero|necesito|puedes|me puedes)\s+(?:ir|llegar|llevar|irme)\s+(?:a|hasta|para)\s+(.+)',
        r'(?:ruta|ruta a|camino a|direccion a)\s+(.+)',
        r'(?:donde queda|como llego a|como voy a)\s+(.+)',
    ]
    
    import re
    for pattern in patterns:
        match = re.search(pattern, msg_lower)
        if match:
            place_name = match.group(1).strip()
            # Limpiar nombre
            place_name = place_name.rstrip('?').strip()
            return {'type': 'specific', 'place_name': place_name}
    
    return None


def _is_ambiguous_request(message):
    """Detecta si el usuario pide algo ambiguo (recomendaciones, que hacer, etc)."""
    import unicodedata
    # Normalizar acentos: qué → que, dónde → donde
    msg_lower = ''.join(
        c for c in unicodedata.normalize('NFKD', message.lower())
        if not unicodedata.combining(c)
    )
    ambiguous_patterns = [
        'que hay pa hacer', 'que me recomiendas', 'que visitar',
        'que hacer en', 'donde ir', 'lugares para', 'mejor de cali',
        'conocer cali', 'recorrido', 'tour', 'circuito', 'plan'
    ]
    return any(p in msg_lower for p in ambiguous_patterns)


def _resolve_route(route_intent, user_lat, user_lon, preferences):
    """Busca el lugar en SQLite y devuelve coordenadas."""
    try:
        place_name = route_intent['place_name']
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Buscar por nombre (LIKE match)
        cursor.execute("""
            SELECT nombre, latitud, longitud, descripcion_caleña
            FROM atractivos
            WHERE latitud IS NOT NULL AND longitud IS NOT NULL
            AND (LOWER(nombre) LIKE ? OR LOWER(descripcion) LIKE ?)
            LIMIT 1
        """, (f'%{place_name}%', f'%{place_name}%'))
        
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return {
                'type': 'specific',
                'destination_name': row['nombre'],
                'destination_lat': row['latitud'],
                'destination_lon': row['longitud'],
                'destination_desc': row['descripcion_caleña']
            }
        return None
    except Exception as e:
        print(f'[RouteResolve] Error: {e}')
        return None


def _build_circuit_from_preferences(user_lat, user_lon, preferences):
    """Arma un circuito de 3 paradas segun preferencias del usuario."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        intereses = preferences.get('intereses', [])
        perfil_id = preferences.get('perfil_id', 0)
        perfil_name = preferences.get('perfil_name', 'Cali')

        # Mapeo completo de los 7 intereses del onboarding a grupos de la DB
        # NOTA: Usar nombres EXACTOS con acentos como están en la base de datos
        INTERESES_A_GRUPOS = {
            'baile': ['Expresiones musicales y sonoras', 'Expresiones dancísticas', 'Festividades y eventos'],
            'gastronomia': ['La gastronomía y los saberes culinarios'],
            'naturaleza': ['Sistema de Parques Nacionales Naturales', 'Lugares de observación de flora y fauna'],
            'comunitario': ['Grupo urbano o rural'],
            'eventos': ['Expresiones musicales y sonoras', 'Festividades y eventos'],
            'cultura': ['Grupo arquitectónico', 'Obras en espacio público'],
            'sancocho': ['La gastronomía y los saberes culinarios'],
        }

        PERFIL_A_GRUPOS = {
            1: ['Expresiones musicales y sonoras', 'Expresiones dancísticas', 'Festividades y eventos'],
            2: ['Sistema de Parques Nacionales Naturales', 'Lugares de observación de flora y fauna'],
            3: ['Grupo urbano o rural'],
            4: ['Sistema de Parques Nacionales Naturales', 'Cerro'],
            5: ['Sistema de Parques Nacionales Naturales'],
            6: ['Grupo urbano o rural', 'Festividades y eventos'],
        }

        # Armar filtros segun intereses + perfil
        grupo_filters = set()
        for key in intereses:
            if key in INTERESES_A_GRUPOS:
                grupo_filters.update(INTERESES_A_GRUPOS[key])
        if perfil_id in PERFIL_A_GRUPOS:
            grupo_filters.update(PERFIL_A_GRUPOS[perfil_id])

        grupo_filters = list(grupo_filters)
        if not grupo_filters:
            grupo_filters = ['Grupo arquitectónico', 'Obras en espacio público', 'Expresiones musicales y sonoras']

        print(f'[CircuitBuild] perfil_id={perfil_id} | intereses={intereses} | grupos={grupo_filters}')

        def _query_atractivos(grupos):
            placeholders = ','.join(['?' for _ in grupos])
            query = f"""
                SELECT nombre, latitud, longitud, descripcion_caleña,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(latitud)) *
                        cos(radians(longitud) - radians(?)) +
                        sin(radians(?)) * sin(radians(latitud))
                    )) AS distancia
                FROM atractivos
                WHERE latitud IS NOT NULL AND longitud IS NOT NULL
                AND grupo IN ({placeholders})
                ORDER BY distancia ASC
                LIMIT 3
            """
            params = [user_lat, user_lon, user_lat] + grupos
            cursor.execute(query, params)
            return cursor.fetchall()

        # Intento 1: con filtros estrictos
        rows = _query_atractivos(grupo_filters)
        print(f'[CircuitBuild] Filtrado estricto: {len(rows)} resultados')

        # Intento 2 (fallback ampliado): incluir grupos relacionados mas amplios
        if len(rows) < 2:
            grupos_amplios = set(grupo_filters)
            # Para naturaleza, tambien incluir: Cerro, Rio, Patrimonio natural
            if any(g in grupo_filters for g in INTERESES_A_GRUPOS['naturaleza']):
                grupos_amplios.update(['Cerro', 'Rio', 'Patrimonio natural'])
            # Para cultura, incluir museos y festividades
            if any(g in grupo_filters for g in INTERESES_A_GRUPOS['cultura']):
                grupos_amplios.update(['Festividades y eventos', 'Grupo urbano o rural'])
            # Para baile/eventos
            if any(g in grupo_filters for g in INTERESES_A_GRUPOS['baile']):
                grupos_amplios.update(['Festividades y eventos'])

            grupos_amplios = list(grupos_amplios)
            if len(grupos_amplios) > len(grupo_filters):
                print(f'[CircuitBuild] Fallback ampliado: {grupos_amplios}')
                rows = _query_atractivos(grupos_amplios)
                print(f'[CircuitBuild] Fallback ampliado: {len(rows)} resultados')

        conn.close()

        if len(rows) >= 2:
            stops = []
            for row in rows:
                stops.append({
                    'nombre': row['nombre'],
                    'lat': row['latitud'],
                    'lon': row['longitud'],
                    'desc': row['descripcion_caleña']
                })
            circuit = {
                'type': 'circuit',
                'name': f'Circuito {perfil_name}',
                'stops': stops
            }
            print(f'[CircuitBuild] Circuito armado: {circuit["name"]} con {len(stops)} paradas')
            return circuit

        print('[CircuitBuild] No se pudo armar circuito (menos de 2 lugares con el perfil). Dejando que Ollama responda.')
        return None
    except Exception as e:
        print(f'[CircuitBuild] Error: {e}')
        import traceback
        traceback.print_exc()
        return None


def _generate_circuit_response(circuit_meta):
    """Genera una respuesta en caleño con los lugares del circuito."""
    stops = circuit_meta['stops']
    name = circuit_meta['name']

    intro_variants = [
        f"Ois, ve! Te arme un {name} bien bacano. Acá te van las paradas, parce:",
        f"Mijo, mira este {name} que te armé, está chimba:",
        f"¡Ay, ve! Este {name} te va a encantar, parce. Dale con estas paradas:",
    ]
    import random
    intro = random.choice(intro_variants)

    lines = [intro]
    for i, stop in enumerate(stops, 1):
        lines.append(f"{i}. {stop['nombre']}")

    outro_variants = [
        "Dale que Cali está calidoso, ve.",
        "¡Eso es puro sabor caleño, parce!",
        "Disfruta el borondo, ve.",
    ]
    lines.append(random.choice(outro_variants))

    return "\n".join(lines)


def _build_chat_context(lat, lon):
    """Construye contexto desde SQLite para el chatbot."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        context_parts = []
        
        # 1. Atractivos cercanos (si hay GPS)
        if lat and lon:
            cursor.execute("""
                SELECT nombre, grupo, descripcion_caleña, latitud, longitud,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(latitud)) * 
                        cos(radians(longitud) - radians(?)) + 
                        sin(radians(?)) * sin(radians(latitud))
                    )) AS distancia
                FROM atractivos
                WHERE latitud IS NOT NULL AND longitud IS NOT NULL
                ORDER BY distancia ASC
                LIMIT 5
            """, (lat, lon, lat))
            rows = cursor.fetchall()
            if rows:
                context_parts.append("LUGARES CERCANOS AL USUARIO:")
                for row in rows:
                    desc = row['descripcion_caleña'] or row['grupo']
                    context_parts.append(f"- {row['nombre']} ({row['distancia']:.0f}m): {desc}")
        
        # 2. Eventos activos
        hoy = datetime.now().strftime('%Y-%m-%d')
        cursor.execute("""
            SELECT nombre, fecha_inicio, fecha_fin, impacto
            FROM eventos
            WHERE fecha_inicio <= ? AND fecha_fin >= ?
            ORDER BY fecha_inicio
            LIMIT 3
        """, (hoy, hoy))
        eventos = cursor.fetchall()
        if eventos:
            context_parts.append("\nEVENTOS ACTIVOS HOY:")
            for ev in eventos:
                context_parts.append(f"- {ev['nombre']}: {ev['impacto'] or 'Evento especial'}")
        
        # 3. Grupos disponibles
        cursor.execute("SELECT DISTINCT grupo FROM atractivos WHERE grupo IS NOT NULL ORDER BY grupo")
        cats = [r['grupo'] for r in cursor.fetchall()]
        if cats:
            context_parts.append(f"\nGRUPOS DISPONIBLES: {', '.join(cats)}")
        
        conn.close()
        return "\n".join(context_parts)
    except Exception as e:
        print(f'[ChatContext] Error: {e}')
        return ""


def _generate_local_response(message, context):
    """Genera respuestas inteligentes locales cuando no hay API key."""
    msg_lower = message.lower()
    
    # Palabras clave para detectar intenciones
    if any(word in msg_lower for word in ['hola', 'buenas', 'que mas', 'saludos']):
        return '¡Ois, ve! Bienvenido a Cali. ¿Que te mueve el corazon, parce?'
    
    if any(word in msg_lower for word in ['salsa', 'baile', 'bailar', 'musica']):
        return '¡Uy, ve! La salsa es el alma de Cali. Te recomiendo la Plazoleta Jairo Varela y el Barrio Obrero. ¡Alla si se baila, parce!'
    
    if any(word in msg_lower for word in ['comida', 'comer', 'restaurante', 'hambre', 'probar']):
        return '¡Eso ve! Tenes que probar la lulada, el aborrajado y el cholado. ¡Delicia, parce! Pregunta en el Mercado Alameda.'
    
    if any(word in msg_lower for word in ['cristo rey', 'cristo', 'cerro']):
        return 'El Cristo Rey es el guardian de la ciudad. Desde ahi se ve todo Cali. ¡Imperdible, ve!'
    
    if any(word in msg_lower for word in ['gato', 'gata', 'tejada']):
        return 'El Gato del Rio es obra del maestro Tejada. Y no es solo un gato, hay mas gatas por ahi. ¡Chimba de lugar, parce!'
    
    if any(word in msg_lower for word in ['tertulia', 'museo', 'arte moderno']):
        return 'El Museo La Tertulia tiene el arte contemporaneo mas chimba de Cali. ¡Pa los que les gusta el arte, ve, es una chimba!'
    
    if any(word in msg_lower for word in ['ermita', 'iglesia']):
        return 'La Iglesia La Ermita es un simbolo de Cali. Ese estilo gotico la hace unica, ve. ¡Bacanisimo para tomar fotos!'
    
    if any(word in msg_lower for word in ['evento', 'feria', 'festival', 'hoy']):
        if context and 'EVENTOS' in context:
            return f'¡Ois, ve! Mira lo que hay pa hoy:\n{context}'
        return 'Ahora mismo no hay eventos en la zona, pero en Cali siempre hay algo bacano pa hacer, parce.'
    
    if any(word in msg_lower for word in ['cerca', 'cercano', 'alrededor', 'donde estoy', 'aqui']):
        if context and 'LUGARES CERCANOS' in context:
            return f'¡Ois! Aca cerca tenes:\n{context}'
        return 'En Cali siempre hay algo chimba cerca, ve. Abri el mapa y fijate los puntitos, parce.'
    
    if any(word in msg_lower for word in ['ruta', 'ir', 'como llegar', 'llegar']):
        return '¡Facil, ve! Toca cualquier lugar en el mapa y dale al boton "Ir". El te dibuja la ruta por las calles reales, parce.'
    
    if any(word in msg_lower for word in ['audio', 'escuchar', 'voz', 'hablar']):
        return '¡Ois! En cada lugar podes tocar el boton "Escuchar en caleño" y te cuento la historia con mi voz, ve.'
    
    if any(word in msg_lower for word in ['gracias', 'thank', 'ty']):
        return '¡De nada, parce! Pa servirte. ¿Algo mas que quieras saber de esta sucursal del cielo?'
    
    # Si hay contexto con lugares cercanos, sugerirlos
    if context and 'LUGARES CERCANOS' in context:
        lines = context.split('\n')
        lugares = [l for l in lines if l.startswith('-')]
        if lugares:
            primeros = lugares[:3]
            return f'¡Ois! Por aca cerca tenes:\n' + '\n'.join(primeros) + '\n\n¿Queres que te cuente mas de alguno, ve?'
    
    # Respuesta por defecto
    return '¡Ois! No entendi bien, pero en Cali siempre hay algo bueno pa hacer. ¿Queres que te recomiende una ruta, parce?'


# =============================================================================
# WEBSOCKET HANDLERS
# =============================================================================

connected_devices = {}

@socketio.on('connect')
def ws_connect():
    print(f'[WebSocket] Cliente conectado: {request.sid}')
    emit('connected', {'status': 'ok', 'message': 'Conectado a CaliGuia Backend'})


@socketio.on('disconnect')
def ws_disconnect():
    if request.sid in connected_devices:
        del connected_devices[request.sid]
    print(f'[WebSocket] Cliente desconectado: {request.sid}')


@socketio.on('location_update')
def ws_location_update(data):
    """Recibe actualizaciones de GPS del celular."""
    try:
        lat = data.get('lat')
        lon = data.get('lon')
        device_id = data.get('device_id', request.sid)
        
        connected_devices[request.sid] = {
            'device_id': device_id,
            'lat': lat,
            'lon': lon,
            'last_update': datetime.now().isoformat()
        }
        
        print(f'[GPS] {device_id}: ({lat}, {lon})')
        
        # Geofencing: revisar si esta cerca de algun evento
        conn = get_db_connection()
        cursor = conn.cursor()
        hoy = datetime.now().strftime('%Y-%m-%d')
        cursor.execute("""
            SELECT *, 
                (6371000 * acos(
                    cos(radians(?)) * cos(radians(latitud)) * 
                    cos(radians(longitud) - radians(?)) + 
                    sin(radians(?)) * sin(radians(latitud))
                )) AS distancia
            FROM eventos
            WHERE fecha_inicio <= ? AND fecha_fin >= ?
                AND latitud IS NOT NULL AND longitud IS NOT NULL
            HAVING distancia < ?
            ORDER BY distancia ASC
            LIMIT 1
        """, (lat, lon, lat, hoy, hoy, Config.GEOFENCING_RADIUS_METERS))
        
        evento = cursor.fetchone()
        conn.close()
        
        if evento:
            ev = dict_from_row(evento)
            emit('nearby_alert', {
                'type': 'event',
                'title': f"¡Ois, ve! Estas cerca de {ev['nombre']}",
                'message': ev.get('impacto', 'Evento especial en la zona'),
                'distance_meters': round(ev['distancia'], 0),
                'event_id': ev['id'],
                'location': {'lat': ev['latitud'], 'lon': ev['longitud']}
            })
        
        emit('location_confirmed', {'status': 'received', 'lat': lat, 'lon': lon})
    except Exception as e:
        print(f'[WebSocket Error] location_update: {e}')
        emit('error', {'message': str(e)})


@socketio.on('register_device')
def ws_register_device(data):
    """Registra el perfil del dispositivo."""
    profile_id = data.get('profile_id')
    device_name = data.get('device_name', 'Dispositivo')
    
    connected_devices[request.sid] = {
        'device_id': request.sid,
        'profile_id': profile_id,
        'name': device_name,
        'connected_at': datetime.now().isoformat()
    }
    
    print(f'[Device] Registrado: {device_name} (perfil: {profile_id})')
    emit('registered', {'status': 'ok', 'device_id': request.sid})


# =============================================================================
# API ESTAMPAS & GAMIFICACION
# =============================================================================

@app.route('/api/stamps', methods=['GET'])
def api_stamps_list():
    """Lista todas las estampas disponibles."""
    try:
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM estampas ORDER BY id")
        rows = cursor.fetchall()
        estampas = [database.dict_from_row(r) for r in rows]
        conn.close()
        return jsonify({'success': True, 'data': estampas})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stamps/<int:estampa_id>', methods=['GET'])
def api_stamp_detail(estampa_id):
    """Detalle de una estampa."""
    try:
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM estampas WHERE id = ?", (estampa_id,))
        row = cursor.fetchone()
        conn.close()
        if row:
            return jsonify({'success': True, 'data': database.dict_from_row(row)})
        return jsonify({'success': False, 'error': 'Estampa no encontrada'}), 404
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/user/stamps', methods=['GET'])
@auth_required
def api_user_stamps():
    """Estampas del usuario autenticado."""
    try:
        user_id = request.current_user_id
        conn = database.get_db_connection()
        cursor = conn.cursor()
        # Obtener estampas desbloqueadas con datos completos
        cursor.execute("""
            SELECT e.*, ue.unlocked_at, ue.compartida
            FROM estampas e
            LEFT JOIN usuario_estampas ue ON e.id = ue.estampa_id AND ue.user_id = ?
            ORDER BY e.id
        """, (user_id,))
        rows = cursor.fetchall()
        estampas = []
        for r in rows:
            d = database.dict_from_row(r)
            d['unlocked'] = d['unlocked_at'] is not None
            estampas.append(d)
        conn.close()
        return jsonify({'success': True, 'data': estampas})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/stamps/claim', methods=['POST'])
@auth_required
def api_stamp_claim():
    """Reclamar una estampa al identificar un monumento."""
    try:
        user_id = request.current_user_id
        data = request.json or {}
        atractivo_id = data.get('atractivo_id')
        estampa_id = data.get('estampa_id')

        if not atractivo_id and not estampa_id:
            return jsonify({'success': False, 'error': 'Se requiere atractivo_id o estampa_id'}), 400

        conn = database.get_db_connection()
        cursor = conn.cursor()

        # Buscar estampa por atractivo si no se proporciona estampa_id
        if not estampa_id and atractivo_id:
            cursor.execute("SELECT id FROM estampas WHERE atractivo_id = ?", (atractivo_id,))
            row = cursor.fetchone()
            if row:
                estampa_id = row['id']
            else:
                conn.close()
                return jsonify({'success': False, 'error': 'No hay estampa para este atractivo'}), 404

        # Verificar si ya tiene la estampa
        cursor.execute(
            "SELECT id FROM usuario_estampas WHERE user_id = ? AND estampa_id = ?",
            (user_id, estampa_id)
        )
        if cursor.fetchone():
            conn.close()
            return jsonify({'success': False, 'error': 'Ya tienes esta estampa', 'already_claimed': True}), 409

        # Registrar visita
        if atractivo_id:
            cursor.execute(
                "INSERT INTO visitas (user_id, atractivo_id, tipo) VALUES (?, ?, 'identificacion')",
                (user_id, atractivo_id)
            )

        # Reclamar estampa
        cursor.execute(
            "INSERT INTO usuario_estampas (user_id, estampa_id, atractivo_id) VALUES (?, ?, ?)",
            (user_id, estampa_id, atractivo_id)
        )

        # Actualizar progreso de logros
        _update_achievement_progress(cursor, user_id, 'estampas')
        _update_achievement_progress(cursor, user_id, 'visitas')

        # Obtener datos de la estampa reclamada
        cursor.execute("SELECT * FROM estampas WHERE id = ?", (estampa_id,))
        estampa = database.dict_from_row(cursor.fetchone())

        conn.commit()
        conn.close()

        return jsonify({
            'success': True,
            'message': '¡Estampa desbloqueada!',
            'data': estampa
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


def _update_achievement_progress(cursor, user_id, tipo):
    """Actualiza progreso de logros del usuario."""
    # Obtener logros del tipo correspondiente
    cursor.execute("SELECT id, meta FROM logros WHERE tipo = ?", (tipo,))
    logros = cursor.fetchall()

    for logro in logros:
        logro_id = logro['id']
        meta = logro['meta']

        # Calcular progreso actual
        if tipo == 'estampas':
            cursor.execute(
                "SELECT COUNT(*) as count FROM usuario_estampas WHERE user_id = ?",
                (user_id,)
            )
        elif tipo == 'visitas':
            cursor.execute(
                "SELECT COUNT(DISTINCT atractivo_id) as count FROM visitas WHERE user_id = ?",
                (user_id,)
            )
        elif tipo == 'compartir':
            cursor.execute(
                "SELECT COUNT(*) as count FROM usuario_estampas WHERE user_id = ? AND compartida = 1",
                (user_id,)
            )
        elif tipo == 'rutas':
            # Por ahora rutas no se trackean, dejar en 0
            continue
        elif tipo == 'horario':
            cursor.execute(
                "SELECT COUNT(*) as count FROM visitas WHERE user_id = ? AND strftime('%H', created_at) >= '18'",
                (user_id,)
            )
        else:
            continue

        progreso = cursor.fetchone()['count']

        # Verificar si ya existe el registro
        cursor.execute(
            "SELECT id, unlocked_at FROM usuario_logros WHERE user_id = ? AND logro_id = ?",
            (user_id, logro_id)
        )
        existing = cursor.fetchone()

        if existing:
            if existing['unlocked_at'] is None:
                # Actualizar progreso
                cursor.execute(
                    "UPDATE usuario_logros SET progreso = ? WHERE user_id = ? AND logro_id = ?",
                    (progreso, user_id, logro_id)
                )
                # Verificar si se desbloqueó
                if progreso >= meta and meta < 999:
                    cursor.execute(
                        "UPDATE usuario_logros SET unlocked_at = datetime('now'), progreso = ? WHERE user_id = ? AND logro_id = ?",
                        (progreso, user_id, logro_id)
                    )
        else:
            # Crear registro
            unlocked = progreso >= meta and meta < 999
            cursor.execute(
                "INSERT INTO usuario_logros (user_id, logro_id, progreso, unlocked_at) VALUES (?, ?, ?, ?)",
                (user_id, logro_id, progreso, datetime.now().isoformat() if unlocked else None)
            )


@app.route('/api/achievements', methods=['GET'])
def api_achievements_list():
    """Lista todos los logros disponibles."""
    try:
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM logros ORDER BY id")
        rows = cursor.fetchall()
        logros = [database.dict_from_row(r) for r in rows]
        conn.close()
        return jsonify({'success': True, 'data': logros})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/user/achievements', methods=['GET'])
@auth_required
def api_user_achievements():
    """Logros del usuario con progreso."""
    try:
        user_id = request.current_user_id
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT l.*, COALESCE(ul.progreso, 0) as progreso, ul.unlocked_at
            FROM logros l
            LEFT JOIN usuario_logros ul ON l.id = ul.logro_id AND ul.user_id = ?
            ORDER BY l.id
        """, (user_id,))
        rows = cursor.fetchall()
        logros = []
        for r in rows:
            d = database.dict_from_row(r)
            d['unlocked'] = d['unlocked_at'] is not None
            logros.append(d)
        conn.close()
        return jsonify({'success': True, 'data': logros})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/user/gamification', methods=['GET'])
@auth_required
def api_user_gamification():
    """Resumen completo de gamificación del usuario."""
    try:
        user_id = request.current_user_id
        conn = database.get_db_connection()
        cursor = conn.cursor()

        # Total estampas
        cursor.execute("SELECT COUNT(*) as count FROM estampas")
        total_estampas = cursor.fetchone()['count']

        cursor.execute("SELECT COUNT(*) as count FROM usuario_estampas WHERE user_id = ?", (user_id,))
        estampas_desbloqueadas = cursor.fetchone()['count']

        # Total logros
        cursor.execute("SELECT COUNT(*) as count FROM logros")
        total_logros = cursor.fetchone()['count']

        cursor.execute("SELECT COUNT(*) as count FROM usuario_logros WHERE user_id = ? AND unlocked_at IS NOT NULL", (user_id,))
        logros_desbloqueados = cursor.fetchone()['count']

        # Puntos totales
        cursor.execute("""
            SELECT COALESCE(SUM(e.puntos), 0) as puntos_estampas
            FROM usuario_estampas ue
            JOIN estampas e ON ue.estampa_id = e.id
            WHERE ue.user_id = ?
        """, (user_id,))
        puntos_estampas = cursor.fetchone()['puntos_estampas'] or 0

        cursor.execute("""
            SELECT COALESCE(SUM(l.puntos), 0) as puntos_logros
            FROM usuario_logros ul
            JOIN logros l ON ul.logro_id = l.id
            WHERE ul.user_id = ? AND ul.unlocked_at IS NOT NULL
        """, (user_id,))
        puntos_logros = cursor.fetchone()['puntos_logros'] or 0

        total_puntos = puntos_estampas + puntos_logros

        # Calcular nivel
        nivel = 1
        titulo = 'Turista Curioso'
        if total_puntos >= 500:
            nivel = 5
            titulo = 'Maestro Bichofué'
        elif total_puntos >= 300:
            nivel = 4
            titulo = 'Embajador de Cali'
        elif total_puntos >= 150:
            nivel = 3
            titulo = 'Caleño de Corazón'
        elif total_puntos >= 50:
            nivel = 2
            titulo = 'Explorador Principiante'

        conn.close()

        return jsonify({
            'success': True,
            'data': {
                'total_puntos': total_puntos,
                'nivel': nivel,
                'titulo': titulo,
                'estampas_desbloqueadas': estampas_desbloqueadas,
                'total_estampas': total_estampas,
                'logros_desbloqueados': logros_desbloqueados,
                'total_logros': total_logros,
                'puntos_para_siguiente_nivel': _puntos_para_nivel(nivel + 1) - total_puntos,
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


def _puntos_para_nivel(nivel):
    """Puntos necesarios para alcanzar un nivel."""
    niveles = {1: 0, 2: 50, 3: 150, 4: 300, 5: 500}
    return niveles.get(nivel, 9999)


@app.route('/api/stamps/share', methods=['POST'])
@auth_required
def api_stamp_share():
    """Marca una estampa como compartida."""
    try:
        user_id = request.current_user_id
        data = request.json or {}
        estampa_id = data.get('estampa_id')

        if not estampa_id:
            return jsonify({'success': False, 'error': 'Se requiere estampa_id'}), 400

        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE usuario_estampas SET compartida = 1 WHERE user_id = ? AND estampa_id = ?",
            (user_id, estampa_id)
        )
        conn.commit()
        conn.close()

        # Actualizar progreso de logros de compartir
        conn = database.get_db_connection()
        cursor = conn.cursor()
        _update_achievement_progress(cursor, user_id, 'compartir')
        conn.commit()
        conn.close()

        return jsonify({'success': True, 'message': 'Estampa compartida'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# LIMPIEZA DE AUDIOS TTS
# =============================================================================

@app.route('/api/admin/cleanup-audio', methods=['POST'])
def cleanup_audio():
    """Endpoint admin para limpiar archivos MP3 antiguos."""
    try:
        from services.tts_service import EdgeTTSService
        max_days = request.json.get('max_age_days', 7) if request.json else 7
        deleted, errors, bytes_freed = EdgeTTSService.cleanup_old_files(max_age_days=max_days)
        return jsonify({
            'success': True,
            'deleted': deleted,
            'errors': errors,
            'bytes_freed': bytes_freed,
            'max_age_days': max_days
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

# =============================================================================
# PANEL ADMIN WEB
# =============================================================================

@app.route('/admin')
def admin_dashboard():
    """Panel de administracion web para gestionar atractivos turisticos."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Obtener todos los atractivos
        cursor.execute("SELECT * FROM atractivos ORDER BY id DESC")
        rows = cursor.fetchall()
        
        atractivos = []
        for row in rows:
            atr = dict_from_row(row)
            # Verificar si tiene audio generado
            audio_path = f"audio_cache/atractivo_{atr['id']}.mp3"
            atr['tiene_audio'] = os.path.exists(audio_path)
            atractivos.append(atr)
        
        # Estadisticas
        cursor.execute("SELECT COUNT(*) as total FROM atractivos")
        total = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM atractivos WHERE es_emblematico = 1")
        emblematicos = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM perfiles")
        perfiles_count = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM eventos")
        eventos_count = cursor.fetchone()['total']
        
        # Stats de estampas
        cursor.execute("SELECT COUNT(*) as total FROM estampas")
        total_estampas = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM usuario_estampas")
        total_reclamadas = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(DISTINCT user_id) as total FROM usuario_estampas")
        usuarios_activos = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM usuario_logros WHERE unlocked_at IS NOT NULL")
        logros_count = cursor.fetchone()['total']
        
        conn.close()
        
        # Contar con audio e imagen
        con_audio = sum(1 for a in atractivos if a['tiene_audio'])
        con_imagen = sum(1 for a in atractivos if a['url_imagen_local'])
        
        # Obtener IP local
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
        except:
            local_ip = "127.0.0.1"
        finally:
            s.close()
        
        # Atractivos emblemáticos para dropdown de estampas
        atractivos_emblematicos = [a for a in atractivos if a.get('es_emblematico') == 1]
        
        return render_template_string(
            ADMIN_HTML,
            atractivos=atractivos,
            atractivos_emblematicos=atractivos_emblematicos,
            stats={
                'total': total,
                'emblematicos': emblematicos,
                'perfiles': perfiles_count,
                'eventos': eventos_count,
                'con_audio': con_audio,
                'con_imagen': con_imagen
            },
            stamp_stats={
                'total': total_estampas,
                'reclamadas': total_reclamadas,
                'usuarios_activos': usuarios_activos,
                'logros': logros_count
            },
            backend_ip=local_ip
        )
    except Exception as e:
        return f"<h1>Error cargando panel admin</h1><p>{str(e)}</p>", 500


# =============================================================================
# ADMIN API: CRUD ESTAMPAS
# =============================================================================

@app.route('/admin/stamps', methods=['POST'])
def admin_create_stamp():
    """Crear nueva estampa desde admin."""
    try:
        data = request.json
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO estampas (nombre, descripcion, atractivo_id, rareza, categoria, puntos)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            data.get('nombre'),
            data.get('descripcion'),
            data.get('atractivo_id'),
            data.get('rareza', 'comun'),
            data.get('categoria', 'monumento'),
            data.get('puntos', 10)
        ))
        stamp_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'id': stamp_id})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/admin/stamps/<int:stamp_id>', methods=['PUT'])
def admin_update_stamp(stamp_id):
    """Actualizar estampa desde admin."""
    try:
        data = request.json
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE estampas SET
                nombre = ?, descripcion = ?, atractivo_id = ?,
                rareza = ?, categoria = ?, puntos = ?
            WHERE id = ?
        """, (
            data.get('nombre'),
            data.get('descripcion'),
            data.get('atractivo_id'),
            data.get('rareza'),
            data.get('categoria'),
            data.get('puntos'),
            stamp_id
        ))
        conn.commit()
        conn.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/admin/stamps/<int:stamp_id>', methods=['DELETE'])
def admin_delete_stamp(stamp_id):
    """Eliminar estampa desde admin."""
    try:
        conn = database.get_db_connection()
        cursor = conn.cursor()
        # Primero eliminar reclamaciones
        cursor.execute("DELETE FROM usuario_estampas WHERE estampa_id = ?", (stamp_id,))
        cursor.execute("DELETE FROM estampas WHERE id = ?", (stamp_id,))
        conn.commit()
        conn.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/admin/stamps/<int:stamp_id>/image', methods=['POST'])
def admin_upload_stamp_image(stamp_id):
    """Subir ilustración de estampa."""
    try:
        if 'image' not in request.files:
            return jsonify({'success': False, 'error': 'No se envio imagen'}), 400
        
        file = request.files['image']
        from services.image_storage import ImageStorageService
        image_url = ImageStorageService.save_attraction_image(stamp_id, file)
        
        # Actualizar URL en la estampa
        conn = database.get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE estampas SET imagen_url = ? WHERE id = ?", (image_url, stamp_id))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'image_url': image_url})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


# =============================================================================
# mDNS / ZERCONF (Descubrimiento automatico)
# =============================================================================

def start_mdns_service():
    """Anuncia el servicio en la red local via mDNS."""
    try:
        from zeroconf import Zeroconf, ServiceInfo
        import socket
        
        # Obtener IP local
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        
        info = ServiceInfo(
            type_="_caliguia._tcp.local.",
            name="CaliGuia Backend._caliguia._tcp.local.",
            addresses=[socket.inet_aton(local_ip)],
            port=5000,
            properties={
                'version': '1.0.0',
                'api': '/api/discover'
            }
        )
        
        zeroconf = Zeroconf()
        zeroconf.register_service(info)
        print(f"[mDNS] Servicio anunciado en: {local_ip}:5000")
        return zeroconf
    except Exception as e:
        print(f"[mDNS] Error iniciando servicio: {e}")
        return None


# =============================================================================
# MAIN
# =============================================================================

if __name__ == '__main__':
    print("=" * 60)
    print("  CALIGUIA BACKEND v1.0")
    print("  Flask + SocketIO + mDNS")
    print("=" * 60)
    print(f"  Base de datos: {Config.DATABASE_PATH}")
    print(f"  Mapbox API: Configurada")
    print("=" * 60)
    
    # Verificar que la base de datos existe
    if not os.path.exists(Config.DATABASE_PATH):
        print(f"\n[ERROR] No se encuentra la base de datos: {Config.DATABASE_PATH}")
        print("Copia caliguia.db desde assets/data/ a caliguia-backend/database/")
        sys.exit(1)
    
    # Obtener IP local para mostrarla
    import socket
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
    except:
        local_ip = "127.0.0.1"
    finally:
        s.close()
    
    # Iniciar mDNS
    zeroconf = start_mdns_service()
    
    try:
        # Iniciar servidor
        print(f"\n🚀 Servidor iniciado en: http://{local_ip}:{Config.PORT}")
        print(f"📱 Panel admin: http://{local_ip}:{Config.PORT}/admin")
        print(f"🔌 WebSocket: ws://{local_ip}:{Config.PORT}/socket.io/")
        print("=" * 60)
        print("✅ Listo para recibir conexiones desde tu celular")
        print("=" * 60 + "\n")
        
        socketio.run(
            app,
            host=Config.HOST,
            port=Config.PORT,
            debug=Config.DEBUG,
            use_reloader=False,  # Evita problemas con mDNS en reloader
        )
    finally:
        if zeroconf:
            zeroconf.unregister_all_services()
            zeroconf.close()
            print("[mDNS] Servicio detenido")
