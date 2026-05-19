#!/usr/bin/env python3
"""
Script de procesamiento de datos turisticos para CaliGuia.
Convierte BD ATRACTIVOS.xls en SQLite embebida y seed_data.json.
"""

import json
import sqlite3
import os
import re
from datetime import datetime

try:
    import pandas as pd
except ImportError:
    print("ERROR: Instala pandas")
    raise

try:
    import xlrd
except ImportError:
    xlrd = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
DATA_DIR = os.path.join(PROJECT_ROOT, "assets", "data")
os.makedirs(DATA_DIR, exist_ok=True)

BD_ATRACTIVOS = os.path.join(PROJECT_ROOT, "..", "BD ATRACTIVOS.xls")
DB_PATH = os.path.join(DATA_DIR, "caliguia.db")
SEED_JSON = os.path.join(DATA_DIR, "seed_data.json")


def parse_coordenada(coord_str):
    if not coord_str or (hasattr(coord_str, 'isna') and pd.isna(coord_str)):
        return None, None
    parts = re.split(r'\s+', str(coord_str).strip())
    parts = [p for p in parts if p]
    if len(parts) >= 2:
        try:
            lat = float(parts[0])
            lon = float(parts[1])
            if 3.0 <= lat <= 4.0 and -77.5 <= lon <= -76.0:
                return lat, lon
        except ValueError:
            pass
    return None, None


def procesar_bd_atractivos():
    print("Leyendo BD ATRACTIVOS.xls...")
    if not os.path.exists(BD_ATRACTIVOS):
        print(f"No encontrado: {BD_ATRACTIVOS}")
        return []
    try:
        if xlrd:
            book = xlrd.open_workbook(BD_ATRACTIVOS)
            sheet = book.sheet_by_index(0)
            headers = [str(sheet.cell_value(0, col)).strip() for col in range(sheet.ncols)]
            atractivos = []
            for row_idx in range(1, min(sheet.nrows, 200)):
                row = sheet.row_values(row_idx)
                data = {headers[col_idx]: row[col_idx] for col_idx in range(min(len(headers), len(row)))}
                atractivos.append(data)
            print(f"  {len(atractivos)} registros leidos")
            return atractivos
        else:
            df = pd.read_excel(BD_ATRACTIVOS, engine='openpyxl')
            return df.to_dict('records')
    except Exception as e:
        print(f"Error leyendo BD ATRACTIVOS: {e}")
        return []


def limpiar_atractivos(atractivos_raw):
    print("Limpiando datos...")
    atractivos = []
    EMBLEMATICOS = {
        'cristo rey', 'iglesia la ermita', 'el gato del rio', 'gato del rio',
        'sebastian de belalcazar', 'catedral metropolitana',
        'plaza de caycedo', 'plaza de caicedo', 'barrio san antonio',
        'zoologico de cali', 'tres cruces', 'cerro de las tres cruces',
        'bulevar del rio', 'la tertulia', 'museo de arte moderno la tertulia',
        'jardin botanico', 'parque nacional natural los farallones',
        'farallones de cali', 'plazoleta jairo varela', 'estadio pascual guerrero',
        'estadio olimpico pascual guerrero'
    }
    for idx, item in enumerate(atractivos_raw):
        try:
            nombre = str(item.get('Nombre del Bien', item.get('Nombre del Inventario', ''))).strip()
            if not nombre or nombre.lower() == 'nan':
                continue
            descripcion = str(item.get('Descripcion', '')).strip()
            if descripcion.lower() == 'nan':
                descripcion = ''
            direccion = str(item.get('Direccion', '')).strip()
            if direccion.lower() == 'nan':
                direccion = ''
            lat, lon = None, None
            for col in ['Georefenciacion1', 'Georefenciacion2', 'Georefenciacion3']:
                val = item.get(col)
                if val and not (hasattr(val, 'isna') and pd.isna(val)):
                    lat, lon = parse_coordenada(val)
                    if lat is not None:
                        break
            patrimonio = str(item.get('Patrimonio', '')).strip()
            tipo_patrimonio = str(item.get('Tipo de Patrimonio', '')).strip()
            grupo = str(item.get('Grupo', '')).strip()
            componente = str(item.get('Componente', '')).strip()
            elemento = str(item.get('Elemento', '')).strip()
            nombre_lower = nombre.lower()
            es_emblematico = 1 if any(emb in nombre_lower for emb in EMBLEMATICOS) else 0
            intereses = []
            if 'salsa' in nombre_lower or 'musica' in descripcion.lower() or 'baile' in descripcion.lower():
                intereses.append('salsa')
            if any(x in patrimonio.lower() for x in ['natural', 'montana', 'rio', 'parque']):
                intereses.append('naturaleza')
            if any(x in componente.lower() for x in ['arquitectura', 'monumento', 'iglesia']):
                intereses.append('historia')
            if 'gastronomia' in grupo.lower() or 'comida' in descripcion.lower():
                intereses.append('gastronomia')
            if 'deport' in nombre_lower or 'estadio' in nombre_lower:
                intereses.append('deportivo')
            atractivos.append({
                'id': idx + 1,
                'nombre': nombre,
                'descripcion': descripcion,
                'descripcion_caleña': '',
                'direccion': direccion,
                'latitud': lat,
                'longitud': lon,
                'patrimonio': patrimonio,
                'tipo_patrimonio': tipo_patrimonio,
                'grupo': grupo,
                'componente': componente,
                'elemento': elemento,
                'es_emblematico': es_emblematico,
                'intereses': json.dumps(intereses),
                'horario': str(item.get('Horario de Atencion', '')).strip(),
                'tarifas': str(item.get('Tarifa Adulto Colombiano', '')).strip(),
                'url_imagen_local': None
            })
        except Exception as e:
            print(f"  Error en registro {idx}: {e}")
            continue
    print(f"  {len(atractivos)} atractivos limpios")
    return atractivos


def crear_sqlite(atractivos):
    print(f"Creando SQLite...")
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE atractivos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            descripcion TEXT,
            descripcion_caleña TEXT,
            direccion TEXT,
            latitud REAL,
            longitud REAL,
            patrimonio TEXT,
            tipo_patrimonio TEXT,
            grupo TEXT,
            componente TEXT,
            elemento TEXT,
            es_emblematico INTEGER DEFAULT 0,
            intereses TEXT,
            horario TEXT,
            tarifas TEXT,
            url_imagen_local TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE perfiles (
            id INTEGER PRIMARY KEY,
            nombre TEXT,
            descripcion TEXT,
            color TEXT,
            icono TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE atractivo_perfil (
            atractivo_id INTEGER,
            perfil_id INTEGER,
            peso REAL DEFAULT 1.0,
            PRIMARY KEY (atractivo_id, perfil_id)
        )
    ''')
    cursor.execute('''
        CREATE TABLE eventos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            fecha_inicio TEXT,
            fecha_fin TEXT,
            fecha_texto TEXT,
            tipo TEXT,
            escala TEXT,
            ubicacion TEXT,
            latitud REAL,
            longitud REAL,
            impacto TEXT,
            perfil_dirigido TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE usuario (
            id INTEGER PRIMARY KEY DEFAULT 1,
            nombre TEXT,
            perfil_id INTEGER,
            onboarding_completado INTEGER DEFAULT 0
        )
    ''')
    for atr in atractivos:
        cursor.execute('''
            INSERT INTO atractivos 
            (nombre, descripcion, descripcion_caleña, direccion, latitud, longitud, 
             patrimonio, tipo_patrimonio, grupo, componente, elemento, es_emblematico,
             intereses, horario, tarifas, url_imagen_local)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            atr['nombre'], atr['descripcion'], atr['descripcion_caleña'],
            atr['direccion'], atr['latitud'], atr['longitud'],
            atr['patrimonio'], atr['tipo_patrimonio'], atr['grupo'],
            atr['componente'], atr['elemento'], atr['es_emblematico'],
            atr['intereses'], atr['horario'], atr['tarifas'], atr['url_imagen_local']
        ))
    perfiles = [
        (1, 'Turismo Cultural & Salsa', 'Pa los que le mueven el alma a la musica y el baile', '#D32F2F', 'music_note'),
        (2, 'Naturaleza & Ecoturismo', 'Pa los que disfrutan el aire puro y los paisajes', '#2E7D32', 'forest'),
        (3, 'Turismo Comunitario', 'Pa conocer la fuerza de los barrios y su gente', '#FF8F00', 'people'),
        (4, 'Turismo Deportivo', 'Pa los que no paran quietos ni un momento', '#1565C0', 'sports'),
        (5, 'Turismo Medico y de Bienestar', 'Pa relajarse y recuperarse con calidad', '#00838F', 'spa'),
        (6, 'Turismo de Compras', 'Pa los que les gusta llevarse recuerdos y regalos', '#6A1B9A', 'shopping_bag'),
    ]
    cursor.executemany('INSERT INTO perfiles VALUES (?,?,?,?,?)', perfiles)
    eventos = [
        (1, 'Festival Petronio Alvarez', '2026-08-14', '2026-08-19', '14 al 19 de agosto', 'Cultural', 'Ancla', 'Unidad Deportiva Alberto Galindo', 3.4256, -76.5224, 'Turismo cultural masivo del Pacifico colombiano', 'cultural'),
        (2, 'Festival Mundial de Salsa', '2026-09-15', '2026-10-05', 'Septiembre/Octubre', 'Cultural', 'Ancla', 'Multiples escenarios', 3.4548, -76.5328, 'Delegaciones de 20 ciudades americanas', 'salsa'),
        (3, 'Feria de Cali 2026', '2026-12-25', '2026-12-30', '25 al 30 de diciembre', 'Cultural', 'Ancla', 'Multiples escenarios', 3.4519, -76.5325, 'Evento cultural masivo de fin de ano', 'cultural'),
    ]
    cursor.executemany('''
        INSERT INTO eventos 
        (id, nombre, fecha_inicio, fecha_fin, fecha_texto, tipo, escala, ubicacion, 
         latitud, longitud, impacto, perfil_dirigido)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
    ''', eventos)
    conn.commit()
    conn.close()
    print(f"  Base creada: {DB_PATH}")
    print(f"  Registros: {len(atractivos)} atractivos, 6 perfiles, {len(eventos)} eventos")


def crear_seed_json(atractivos):
    print("Creando seed_data.json...")
    data = {
        'version': '1.0.0',
        'fecha_generacion': datetime.now().isoformat(),
        'atractivos': atractivos,
        'perfiles': [
            {'id': 1, 'nombre': 'Turismo Cultural & Salsa', 'color': '#D32F2F'},
            {'id': 2, 'nombre': 'Naturaleza & Ecoturismo', 'color': '#2E7D32'},
            {'id': 3, 'nombre': 'Turismo Comunitario', 'color': '#FF8F00'},
            {'id': 4, 'nombre': 'Turismo Deportivo', 'color': '#1565C0'},
            {'id': 5, 'nombre': 'Turismo Medico y de Bienestar', 'color': '#00838F'},
            {'id': 6, 'nombre': 'Turismo de Compras', 'color': '#6A1B9A'},
        ],
        'eventos': [
            {'nombre': 'Festival Petronio Alvarez', 'fecha_texto': '14 al 19 de agosto', 'tipo': 'Cultural'},
            {'nombre': 'Feria de Cali 2026', 'fecha_texto': '25 al 30 de diciembre', 'tipo': 'Cultural'},
        ]
    }
    with open(SEED_JSON, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  JSON creado: {SEED_JSON}")


def main():
    print("=" * 60)
    print("CALIGUIA - Procesamiento de Datos Turisticos")
    print("=" * 60)
    print()
    atractivos_raw = procesar_bd_atractivos()
    if not atractivos_raw:
        print("No se pudieron leer datos. Abortando.")
        return
    atractivos = limpiar_atractivos(atractivos_raw)
    crear_sqlite(atractivos)
    crear_seed_json(atractivos)
    emblematicos = [a for a in atractivos if a['es_emblematico'] == 1]
    print(f"\nAtractivos emblematicos para reconocimiento visual: {len(emblematicos)}")
    for a in emblematicos[:20]:
        print(f"  - {a['nombre']} ({a['latitud']}, {a['longitud']})")
    print("\n" + "=" * 60)
    print("Procesamiento completado")
    print("=" * 60)


if __name__ == '__main__':
    main()
