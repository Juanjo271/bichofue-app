#!/usr/bin/env python3
from app import _build_circuit_from_preferences, _generate_circuit_response

# Test 1: Ecoturismo
print("=" * 50)
print("TEST 1: ECOTURISMO")
print("=" * 50)
prefs = {
    'intereses': ['naturaleza'],
    'perfil_id': 2,
    'perfil_name': 'Naturaleza y Ecoturismo'
}
result = _build_circuit_from_preferences(3.4516, -76.5320, prefs)
print("Circuito:", result)
if result:
    print("\nRespuesta caleña:")
    print(_generate_circuit_response(result))

# Test 2: Cultural & Salsa
print("\n" + "=" * 50)
print("TEST 2: CULTURAL & SALSA")
print("=" * 50)
prefs = {
    'intereses': ['baile', 'gastronomia'],
    'perfil_id': 1,
    'perfil_name': 'Cultural y Salsa'
}
result = _build_circuit_from_preferences(3.4516, -76.5320, prefs)
print("Circuito:", result)
if result:
    print("\nRespuesta caleña:")
    print(_generate_circuit_response(result))

# Test 3: Comunitario
print("\n" + "=" * 50)
print("TEST 3: COMUNITARIO")
print("=" * 50)
prefs = {
    'intereses': ['comunitario'],
    'perfil_id': 3,
    'perfil_name': 'Turismo Comunitario'
}
result = _build_circuit_from_preferences(3.4516, -76.5320, prefs)
print("Circuito:", result)
if result:
    print("\nRespuesta caleña:")
    print(_generate_circuit_response(result))
