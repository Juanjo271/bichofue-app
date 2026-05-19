"""
caliguia-backend/database.py
============================
Utilidades de base de datos compartidas.
Evita circular imports entre app.py y los blueprints.
"""

import sqlite3
from config import Config


def get_db_connection():
    """Crea una conexión SQLite con row_factory=sqlite3.Row."""
    conn = sqlite3.connect(Config.DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def dict_from_row(row) -> dict:
    """Convierte una sqlite3.Row en dict."""
    return {key: row[key] for key in row.keys()}


def init_usuarios_table():
    """Crea o migra la tabla usuarios al schema completo."""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Tabla usuarios expandida
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            nombre TEXT,
            edad INTEGER,
            genero TEXT,
            origen TEXT,
            hospedaje TEXT,
            grupo TEXT,
            duracion TEXT,
            presupuesto TEXT,
            intereses TEXT,
            perfil_id INTEGER DEFAULT 0,
            perfil_name TEXT,
            created_at TEXT,
            updated_at TEXT
        )
    """)

    # Migración: si la tabla vieja 'usuario' existe, copiar datos y eliminar
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='usuario'")
    if cursor.fetchone():
        try:
            cursor.execute("""
                INSERT OR IGNORE INTO usuarios (id, nombre, perfil_id, created_at)
                SELECT id, nombre, perfil_id, datetime('now') FROM usuario
            """)
            cursor.execute("DROP TABLE usuario")
        except Exception as e:
            print(f'[Database] Migración usuario -> usuarios: {e}')

    conn.commit()
    conn.close()
    print('[Database] Tabla usuarios lista.')


def init_estampas_tables():
    """Crea tablas de estampas, logros y progreso de gamificación."""
    conn = get_db_connection()
    cursor = conn.cursor()

    # Catálogo de estampas coleccionables
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS estampas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            atractivo_id INTEGER,
            imagen_url TEXT,
            rareza TEXT DEFAULT 'comun',
            categoria TEXT,
            condicion TEXT DEFAULT 'identificar',
            puntos INTEGER DEFAULT 10,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (atractivo_id) REFERENCES atractivos(id)
        )
    """)

    # Estampas obtenidas por usuarios
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuario_estampas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            estampa_id INTEGER NOT NULL,
            atractivo_id INTEGER,
            unlocked_at TEXT DEFAULT CURRENT_TIMESTAMP,
            compartida INTEGER DEFAULT 0,
            FOREIGN KEY (user_id) REFERENCES usuarios(id),
            FOREIGN KEY (estampa_id) REFERENCES estampas(id),
            UNIQUE(user_id, estampa_id)
        )
    """)

    # Logros/insignias
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS logros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            imagen_url TEXT,
            tipo TEXT NOT NULL,
            meta INTEGER DEFAULT 1,
            puntos INTEGER DEFAULT 20,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Logros desbloqueados por usuarios
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usuario_logros (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            logro_id INTEGER NOT NULL,
            progreso INTEGER DEFAULT 0,
            unlocked_at TEXT,
            FOREIGN KEY (user_id) REFERENCES usuarios(id),
            FOREIGN KEY (logro_id) REFERENCES logros(id),
            UNIQUE(user_id, logro_id)
        )
    """)

    # Visitas/registro de actividad
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS visitas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            atractivo_id INTEGER NOT NULL,
            tipo TEXT DEFAULT 'identificacion',
            lat REAL,
            lon REAL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id),
            FOREIGN KEY (atractivo_id) REFERENCES atractivos(id)
        )
    """)

    conn.commit()
    conn.close()
    print('[Database] Tablas de gamificación listas.')


def seed_default_stamps():
    """Inserta estampas por defecto para los atractivos emblemáticos."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as count FROM estampas")
    if cursor.fetchone()['count'] > 0:
        conn.close()
        return

    # Obtener atractivos emblemáticos
    cursor.execute("SELECT id, nombre, descripcion, grupo FROM atractivos WHERE es_emblematico = 1")
    emblematicos = cursor.fetchall()

    for atr in emblematicos:
        nombre_estampa = f"{atr['nombre']} - Descubrimiento"
        descripcion = f"Identificaste {atr['nombre']}. {atr['descripcion'][:100] if atr['descripcion'] else ''}"
        categoria = 'monumento' if 'arquitect' in (atr['grupo'] or '').lower() else 'naturaleza'
        rareza = 'epica' if atr['id'] <= 3 else 'rara'

        cursor.execute("""
            INSERT INTO estampas (nombre, descripcion, atractivo_id, rareza, categoria, condicion, puntos)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (nombre_estampa, descripcion, atr['id'], rareza, categoria, 'identificar', 25 if rareza == 'epica' else 15))

    conn.commit()
    conn.close()
    print(f'[Database] Seed: {len(emblematicos)} estampas creadas.')


def seed_default_achievements():
    """Inserta logros por defecto."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as count FROM logros")
    if cursor.fetchone()['count'] > 0:
        conn.close()
        return

    logros_default = [
        ('Primer Paso', 'Identifica tu primer monumento', 'visitas', 1, 20),
        ('Ojo de Águila', 'Identifica 3 monumentos emblemáticos', 'visitas', 3, 50),
        ('Coleccionista', 'Obtén 5 estampas diferentes', 'estampas', 5, 100),
        ('Explorador Nativo', 'Obtén 10 estampas diferentes', 'estampas', 10, 200),
        ('Maestro Bichofué', 'Obtén todas las estampas', 'estampas', 999, 500),
        ('Compartir es Vivir', 'Comparte 3 descubrimientos', 'compartir', 3, 30),
        ('Ruta Completa', 'Completa tu primera ruta', 'rutas', 1, 75),
        ('Nocturno', 'Visita un lugar después de las 6pm', 'horario', 1, 40),
    ]

    for nombre, desc, tipo, meta, puntos in logros_default:
        cursor.execute("""
            INSERT INTO logros (nombre, descripcion, tipo, meta, puntos)
            VALUES (?, ?, ?, ?, ?)
        """, (nombre, desc, tipo, meta, puntos))

    conn.commit()
    conn.close()
    print(f'[Database] Seed: {len(logros_default)} logros creados.')


def init_eventos_masivos_table():
    """Crea tabla de eventos masivos (Feria, Petronio, etc)."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS eventos_masivos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            tipo TEXT DEFAULT 'feria',
            fecha_inicio TEXT,
            fecha_fin TEXT,
            lat REAL,
            lon REAL,
            radio_meters INTEGER DEFAULT 1000,
            zona_restringida TEXT,
            activo INTEGER DEFAULT 0,
            alerta_caleña TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    conn.close()
    print('[Database] Tabla eventos_masivos lista.')


def seed_eventos_masivos():
    """Inserta eventos masivos de Cali."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as count FROM eventos_masivos")
    if cursor.fetchone()['count'] > 0:
        conn.close()
        return

    eventos = [
        (
            'Feria de Cali 2026',
            'La feria más grande de Colombia. Conciertos, cabalgata, salsa, toros y cultura caleña.',
            'feria',
            '2026-12-25',
            '2026-12-30',
            3.4372,
            -76.5225,
            2000,
            'Autopista Suroriental, Salsódromo, Estadio Pascual Guerrero',
            1,
            '¡Oís! Estamos en Feria de Cali. El Salsódromo y la Autopista Sur están full. Te armo una ruta alternativa pa que no te quedés stuck.'
        ),
        (
            'Festival Petronio Álvarez 2026',
            'El festival de música del Pacífico más grande del mundo. Marimba, currulao, aguabajo y arrechón.',
            'petronio',
            '2026-08-12',
            '2026-08-17',
            3.4215,
            -76.5320,
            1500,
            'Unidad Deportiva Alberto Galindo, Ciudadela Petronio',
            1,
            '¡Uy, ve! Estamos en Petronio. La Ciudadela está que no cabe un alfiler. Te muestro rutas alternativas pa llegar sin estrés.'
        ),
        (
            'Festival Mundial de Salsa 2026',
            'Competencia de salsa más importante del mundo. Bailarines de todos los continentes.',
            'salsa',
            '2026-09-20',
            '2026-09-27',
            3.4372,
            -76.5225,
            1200,
            'Estadio Olímpico Pascual Guerrero, Teatro Municipal',
            0,
            '¡Se prendió la salsa! El centro está full de bailarines. Te ayudo a navegar la ciudad durante el festival.'
        ),
        (
            'Concierto Masivo Estadio Pascual Guerrero',
            'Evento de gran magnitud en el estadio. Aforo 38,000-42,000 personas.',
            'concierto',
            '2026-06-15',
            '2026-06-15',
            3.4372,
            -76.5225,
            1500,
            'Estadio Pascual Guerrero, Roosevelt, Calle 5ta',
            0,
            '¡Oís! Hay concierto en el Pascual. La Roosevelt y la 5ta están pesadísimas. Mejor evitá esas vías si no vas pal estadio.'
        ),
        (
            'Cumbre Afrodiaspórica Mundial 2026',
            'Evento internacional dentro del marco del Petronio Álvarez. Diáspora africana en el Pacífico.',
            'cultural',
            '2026-08-14',
            '2026-08-16',
            3.4215,
            -76.5320,
            1000,
            'Unidad Deportiva Alberto Galindo',
            0,
            '¡Bienvenido a la Cumbre Afrodiaspórica! Un hito internacional en Cali. La zona de la Ciudadela está con mucho flujo.'
        ),
    ]

    cursor.executemany("""
        INSERT INTO eventos_masivos (nombre, descripcion, tipo, fecha_inicio, fecha_fin, lat, lon, radio_meters, zona_restringida, activo, alerta_caleña)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, eventos)

    conn.commit()
    conn.close()
    print(f'[Database] Seed: {len(eventos)} eventos masivos creados.')


def init_wifi_zones_table():
    """Crea tabla de zonas WiFi gratuitas de Cali."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS wifi_zones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            lat REAL NOT NULL,
            lon REAL NOT NULL,
            direccion TEXT,
            zona TEXT,
            tipo TEXT DEFAULT 'zona_wifi',
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.commit()
    conn.close()
    print('[Database] Tabla wifi_zones lista.')


def seed_wifi_zones():
    """Inserta puntos WiFi gratuitos de Cali (muestra representativa de las 250+ zonas)."""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) as count FROM wifi_zones")
    if cursor.fetchone()['count'] > 0:
        conn.close()
        return

    # 30 puntos representativos de las 250+ zonas WiFi de Cali
    wifi_zones = [
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Unicentro Cali', 3.4525, -76.5263, 'Carrera 100 # 16-50', 'Jardín Plaza', 'zona_wifi'),
        ('Zona WiFi Centro Comercial Palmetto Plaza', 3.4305, -76.5419, 'Calle 9 # 48-50', 'Sur', 'zona_wifi'),
        ('Zona WiFi Parque del Perro', 3.4315, -76.5425, 'Carrera 35 # 3-50', 'San Fernando', 'zona_wifi'),
        ('Zona WiFi Boulevard del Río', 3.4520, -76.5319, 'Carrera 1 # 13-50', 'Centro', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Estadio Olímpico Pascual Guerrero', 3.4372, -76.5225, 'Calle 5 # 35-50', 'San Fernando', 'zona_wifi'),
        ('Zona WiFi Jardín Plaza', 3.4540, -76.5280, 'Carrera 98 # 16-50', 'Jardín Plaza', 'zona_wifi'),
        ('Zona WiFi Parque de los Deseos', 3.4528, -76.5325, 'Carrera 3 # 14-50', 'Centro', 'zona_wifi'),
        ('Zona WiFi Unidad Deportiva Alberto Galindo', 3.4215, -76.5320, 'Calle 5 # 52-50', 'Pampalinda', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Centro Cultural de Cali', 3.4515, -76.5310, 'Calle 12 # 2-50', 'Centro', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi La 14 de Calima', 3.4610, -76.5180, 'Carrera 100 # 14-50', 'Calima', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Terminal de Transportes', 3.4250, -76.5220, 'Calle 30 # 2-50', 'Norte', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Centro Comercial Cosmocentro', 3.4380, -76.5235, 'Calle 5 # 50-50', 'San Fernando', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi La 14 de Pasoancho', 3.4300, -76.5100, 'Carrera 39 # 5-50', 'Pasoancho', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Centro Comercial Único', 3.4550, -76.5250, 'Carrera 85 # 16-50', 'Jardín Plaza', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi CC Holguines Trade Center', 3.4520, -76.5250, 'Carrera 83 # 16-50', 'Jardín Plaza', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
        ('Zona WiFi Parque Artesanal Loma de La Cruz', 3.4497, -76.5351, 'Calle 13 # 8-50', 'San Antonio', 'zona_wifi'),
    ]

    cursor.executemany("""
        INSERT INTO wifi_zones (nombre, lat, lon, direccion, zona, tipo)
        VALUES (?, ?, ?, ?, ?, ?)
    """, wifi_zones)

    conn.commit()
    conn.close()
    print(f'[Database] Seed: {len(wifi_zones)} zonas WiFi creadas.')
