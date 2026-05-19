"""
CaliGuia Authentication API
===========================
Endpoints de registro, login y gestión de perfil de usuario.
Usa tokens firmados con itsdangerous (sin dependencias extras).
"""

import json
from datetime import datetime
from functools import wraps

from flask import Blueprint, request, jsonify, current_app
from werkzeug.security import generate_password_hash, check_password_hash
from itsdangerous import URLSafeTimedSerializer, SignatureExpired, BadSignature

from database import get_db_connection, dict_from_row

auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')

# =============================================================================
# UTILIDADES
# =============================================================================

def get_serializer():
    secret = current_app.config.get('SECRET_KEY', 'caliguia-dev-secret-key')
    return URLSafeTimedSerializer(secret)

def generate_token(user_id: int) -> str:
    """Genera un token firmado con el user_id."""
    return get_serializer().dumps({'user_id': user_id})

def verify_token(token: str, max_age: int = 86400 * 30):
    """
    Verifica un token firmado.
    max_age: segundos (default 30 días).
    Retorna el payload o None si es inválido/expirado.
    """
    try:
        payload = get_serializer().loads(token, max_age=max_age)
        return payload
    except (SignatureExpired, BadSignature):
        return None

def get_current_user_id() -> int | None:
    """Extrae el user_id del header Authorization: Bearer <token>."""
    auth_header = request.headers.get('Authorization', '')
    if not auth_header.startswith('Bearer '):
        return None
    token = auth_header.split(' ', 1)[1]
    payload = verify_token(token)
    if payload and 'user_id' in payload:
        return payload['user_id']
    return None

def auth_required(f):
    """Decorator que requiere un token válido en el request."""
    @wraps(f)
    def decorated(*args, **kwargs):
        user_id = get_current_user_id()
        if user_id is None:
            return jsonify({'success': False, 'error': 'No autorizado. Token inválido o faltante.'}), 401
        # Adjuntar user_id al request para uso interno
        request.current_user_id = user_id
        return f(*args, **kwargs)
    return decorated

# =============================================================================
# ENDPOINTS
# =============================================================================

@auth_bp.route('/register', methods=['POST'])
def api_register():
    """Registra un nuevo usuario. Body: {email, username, password}."""
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()
    username = (data.get('username') or '').strip().lower()
    password = data.get('password', '')

    if not email or not username or not password:
        return jsonify({'success': False, 'error': 'Email, username y password son requeridos.'}), 400
    if len(password) < 4:
        return jsonify({'success': False, 'error': 'La contraseña debe tener al menos 4 caracteres.'}), 400

    conn = get_db_connection()
    cursor = conn.cursor()

    # Verificar duplicados
    cursor.execute("SELECT id FROM usuarios WHERE email = ? OR username = ?", (email, username))
    if cursor.fetchone():
        conn.close()
        return jsonify({'success': False, 'error': 'El email o username ya están registrados.'}), 409

    password_hash = generate_password_hash(password)
    now = datetime.now().isoformat()

    cursor.execute("""
        INSERT INTO usuarios (email, username, password_hash, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
    """, (email, username, password_hash, now, now))

    user_id = cursor.lastrowid
    conn.commit()
    conn.close()

    token = generate_token(user_id)

    return jsonify({
        'success': True,
        'data': {
            'token': token,
            'user_id': user_id,
            'username': username,
        }
    })


@auth_bp.route('/login', methods=['POST'])
def api_login():
    """Login con username + password. Body: {username, password}."""
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip().lower()
    password = data.get('password', '')

    if not username or not password:
        return jsonify({'success': False, 'error': 'Username y password son requeridos.'}), 400

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, username, password_hash FROM usuarios WHERE username = ?", (username,))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return jsonify({'success': False, 'error': 'Usuario no encontrado.'}), 404

    if not check_password_hash(row['password_hash'], password):
        return jsonify({'success': False, 'error': 'Contraseña incorrecta.'}), 401

    token = generate_token(row['id'])

    return jsonify({
        'success': True,
        'data': {
            'token': token,
            'user_id': row['id'],
            'username': row['username'],
        }
    })


@auth_bp.route('/me', methods=['GET'])
@auth_required
def api_me():
    """Devuelve el perfil completo del usuario autenticado."""
    user_id = request.current_user_id

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM usuarios WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return jsonify({'success': False, 'error': 'Usuario no encontrado.'}), 404

    user = dict_from_row(row)
    # Parsear intereses JSON
    if user.get('intereses'):
        try:
            user['intereses'] = json.loads(user['intereses'])
        except:
            user['intereses'] = []
    else:
        user['intereses'] = []
    # Ocultar password_hash
    user.pop('password_hash', None)

    return jsonify({'success': True, 'data': user})


@auth_bp.route('/profile', methods=['PUT'])
@auth_required
def api_update_profile():
    """Actualiza los datos del perfil (onboarding) del usuario autenticado."""
    user_id = request.current_user_id
    data = request.get_json(silent=True) or {}

    campos_permitidos = [
        'nombre', 'edad', 'genero', 'origen', 'hospedaje',
        'grupo', 'duracion', 'presupuesto', 'intereses',
        'perfil_id', 'perfil_name'
    ]

    updates = []
    params = []
    for campo in campos_permitidos:
        if campo in data:
            if campo == 'intereses':
                # Guardar como JSON string
                val = json.dumps(data[campo]) if isinstance(data[campo], list) else data[campo]
            else:
                val = data[campo]
            updates.append(f"{campo} = ?")
            params.append(val)

    if not updates:
        return jsonify({'success': False, 'error': 'No se proporcionaron campos para actualizar.'}), 400

    updates.append("updated_at = ?")
    params.append(datetime.now().isoformat())
    params.append(user_id)

    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(f"UPDATE usuarios SET {', '.join(updates)} WHERE id = ?", params)
    conn.commit()
    conn.close()

    return jsonify({'success': True, 'message': 'Perfil actualizado correctamente.'})


@auth_bp.route('/delete', methods=['DELETE'])
@auth_required
def api_delete_account():
    """Elimina la cuenta del usuario autenticado."""
    user_id = request.current_user_id
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM usuarios WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Cuenta eliminada.'})
