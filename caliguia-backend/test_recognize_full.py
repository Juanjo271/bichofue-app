from app import app
import os

client = app.test_client()

img_path = '/home/juan/Escritorio/YOLO26_Ermita/valid/images/1280px-Ermita_Cali_Editada_png.rf.87540cff80e79ca8b4a664cf66a57d6b.jpg'

# Test 1: Muy cerca de La Ermita (debería usar YOLO)
print("=== TEST 1: Cerca de La Ermita (YOLO debería funcionar) ===")
with open(img_path, 'rb') as f:
    data = {
        'image': (f, 'test.jpg'),
        'lat': '3.4540',
        'lon': '-76.5320'
    }
    response = client.post(
        '/api/recognize',
        data=data,
        content_type='multipart/form-data'
    )
    result = response.get_json()
    print(f"Status: {response.status_code}")
    print(f"Method: {result.get('method')}")
    print(f"Experimental: {result.get('experimental')}")
    print(f"Confidence: {result.get('confidence')}")
    print(f"Place: {result['data'].get('place') if result.get('data') else 'N/A'}")
    print(f"Distance: {result['data'].get('distance_meters') if result.get('data') else 'N/A'}m")

print()

# Test 2: Lejos (debería usar GPS fallback)
print("=== TEST 2: Lejos de todo (GPS fallback) ===")
with open(img_path, 'rb') as f:
    data = {
        'image': (f, 'test.jpg'),
        'lat': '3.5000',
        'lon': '-76.6000'
    }
    response = client.post(
        '/api/recognize',
        data=data,
        content_type='multipart/form-data'
    )
    result = response.get_json()
    print(f"Status: {response.status_code}")
    print(f"Method: {result.get('method')}")
    print(f"Experimental: {result.get('experimental')}")
    print(f"Confidence: {result.get('confidence')}")
    print(f"Place: {result['data'].get('place') if result.get('data') else 'N/A'}")

print()

# Test 3: Sin GPS (debería permitir YOLO sin restricción de distancia)
print("=== TEST 3: Sin coordenadas GPS ===")
with open(img_path, 'rb') as f:
    data = {
        'image': (f, 'test.jpg'),
    }
    response = client.post(
        '/api/recognize',
        data=data,
        content_type='multipart/form-data'
    )
    result = response.get_json()
    print(f"Status: {response.status_code}")
    print(f"Method: {result.get('method')}")
    print(f"Experimental: {result.get('experimental')}")
    print(f"Confidence: {result.get('confidence')}")
    print(f"Place: {result['data'].get('place') if result.get('data') else 'N/A'}")
