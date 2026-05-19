from flask import Blueprint, request, jsonify, send_file
import sqlite3
import json
import os
from config import Config
from services.tts_service import EdgeTTSService
from services.image_storage import ImageStorageService

crud_bp = Blueprint('crud', __name__)

def get_db():
    conn = sqlite3.connect(Config.DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# =============================================================================
# CRUD ATRACTIVOS
# =============================================================================

@crud_bp.route('/api/attractions', methods=['POST'])
def create_attraction():
    """Crea un nuevo atractivo turistico."""
    try:
        data = request.get_json() or {}
        
        required = ['nombre', 'descripcion']
        for field in required:
            if not data.get(field):
                return jsonify({'success': False, 'error': f'Campo requerido: {field}'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO atractivos 
            (nombre, descripcion, descripcion_caleña, direccion, latitud, longitud,
             patrimonio, tipo_patrimonio, grupo, componente, elemento, es_emblematico,
             intereses, horario, tarifas, url_imagen_local)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            data.get('nombre'),
            data.get('descripcion'),
            data.get('descripcion_caleña', ''),
            data.get('direccion', ''),
            data.get('latitud'),
            data.get('longitud'),
            data.get('patrimonio', ''),
            data.get('tipo_patrimonio', ''),
            data.get('grupo', ''),
            data.get('componente', ''),
            data.get('elemento', ''),
            data.get('es_emblematico', 0),
            json.dumps(data.get('intereses', [])),
            data.get('horario', ''),
            data.get('tarifas', ''),
            data.get('url_imagen_local')
        ))
        
        new_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        # Generar audio TTS automaticamente
        texto_para_audio = data.get('descripcion_caleña') or data.get('descripcion')
        audio_path = EdgeTTSService.generate_for_attraction(new_id, texto_para_audio)
        
        return jsonify({
            'success': True,
            'message': 'Atractivo creado exitosamente',
            'id': new_id,
            'audio_generated': audio_path is not None
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@crud_bp.route('/api/attractions/<int:atractivo_id>', methods=['PUT'])
def update_attraction(atractivo_id):
    """Actualiza un atractivo existente."""
    try:
        data = request.get_json() or {}
        
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("SELECT id FROM atractivos WHERE id = ?", (atractivo_id,))
        if not cursor.fetchone():
            conn.close()
            return jsonify({'success': False, 'error': 'Atractivo no encontrado'}), 404
        
        fields = []
        values = []
        
        field_mapping = {
            'nombre': 'nombre',
            'descripcion': 'descripcion',
            'descripcion_caleña': 'descripcion_caleña',
            'direccion': 'direccion',
            'latitud': 'latitud',
            'longitud': 'longitud',
            'patrimonio': 'patrimonio',
            'tipo_patrimonio': 'tipo_patrimonio',
            'grupo': 'grupo',
            'componente': 'componente',
            'elemento': 'elemento',
            'es_emblematico': 'es_emblematico',
            'horario': 'horario',
            'tarifas': 'tarifas',
            'url_imagen_local': 'url_imagen_local'
        }
        
        for key, db_field in field_mapping.items():
            if key in data:
                fields.append(f"{db_field} = ?")
                values.append(data[key])
        
        if 'intereses' in data:
            fields.append("intereses = ?")
            values.append(json.dumps(data['intereses']))
        
        if not fields:
            conn.close()
            return jsonify({'success': False, 'error': 'No hay campos para actualizar'}), 400
        
        values.append(atractivo_id)
        query = f"UPDATE atractivos SET {', '.join(fields)} WHERE id = ?"
        cursor.execute(query, values)
        conn.commit()
        conn.close()
        
        # Solo regenerar audio si cambió la descripción caleña (texto del TTS)
        if 'descripcion_caleña' in data:
            audio_path = os.path.join(Config.AUDIO_CACHE_DIR, f"atractivo_{atractivo_id}.mp3")
            
            # Eliminar audio anterior para forzar regeneración
            if os.path.exists(audio_path):
                os.remove(audio_path)
            
            # Generar nuevo audio con el texto actualizado
            EdgeTTSService.generate_for_attraction(atractivo_id, data['descripcion_caleña'])
        
        return jsonify({
            'success': True,
            'message': 'Atractivo actualizado exitosamente',
            'id': atractivo_id
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@crud_bp.route('/api/attractions/<int:atractivo_id>', methods=['DELETE'])
def delete_attraction(atractivo_id):
    """Elimina un atractivo."""
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        cursor.execute("SELECT id FROM atractivos WHERE id = ?", (atractivo_id,))
        if not cursor.fetchone():
            conn.close()
            return jsonify({'success': False, 'error': 'Atractivo no encontrado'}), 404
        
        ImageStorageService.delete_image(atractivo_id)
        
        audio_path = os.path.join(Config.AUDIO_CACHE_DIR, f"atractivo_{atractivo_id}.mp3")
        if os.path.exists(audio_path):
            os.remove(audio_path)
        
        cursor.execute("DELETE FROM atractivos WHERE id = ?", (atractivo_id,))
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Atractivo eliminado exitosamente'
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@crud_bp.route('/api/attractions/<int:atractivo_id>/image', methods=['POST'])
def upload_image(atractivo_id):
    """Sube una imagen para un atractivo."""
    try:
        if 'image' not in request.files:
            return jsonify({'success': False, 'error': 'No se envio imagen'}), 400
        
        file = request.files['image']
        
        if file.filename == '':
            return jsonify({'success': False, 'error': 'Archivo vacio'}), 400
        
        image_url = ImageStorageService.save_image(file, atractivo_id)
        
        if not image_url:
            return jsonify({'success': False, 'error': 'Formato no permitido'}), 400
        
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute(
            "UPDATE atractivos SET url_imagen_local = ? WHERE id = ?",
            (image_url, atractivo_id)
        )
        conn.commit()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'Imagen subida exitosamente',
            'image_url': image_url
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@crud_bp.route('/api/tts/<int:atractivo_id>', methods=['GET'])
def get_tts_audio(atractivo_id):
    """Obtiene el audio TTS de un atractivo."""
    try:
        audio_path = os.path.join(Config.AUDIO_CACHE_DIR, f"atractivo_{atractivo_id}.mp3")
        
        if not os.path.exists(audio_path):
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT descripcion, descripcion_caleña FROM atractivos WHERE id = ?", (atractivo_id,))
            row = cursor.fetchone()
            conn.close()
            
            if row:
                texto = row['descripcion_caleña'] or row['descripcion']
                audio_path = EdgeTTSService.generate_for_attraction(atractivo_id, texto)
            
            if not audio_path or not os.path.exists(audio_path):
                return jsonify({'success': False, 'error': 'Audio no disponible'}), 404
        
        return send_file(audio_path, mimetype='audio/mpeg')
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500
