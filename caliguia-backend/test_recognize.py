from app import app
import os

client = app.test_client()

img_path = '/home/juan/Escritorio/YOLO26_Ermita/valid/images/1280px-Ermita_Cali_Editada_png.rf.87540cff80e79ca8b4a664cf66a57d6b.jpg'

with open(img_path, 'rb') as f:
    data = {
        'image': (f, 'test.jpg'),
        'lat': '3.452',
        'lon': '-76.532'
    }
    response = client.post(
        '/api/recognize',
        data=data,
        content_type='multipart/form-data'
    )
    print(f'Status: {response.status_code}')
    result = response.get_json()
    print(f'Success: {result.get("success")}')
    print(f'Method: {result.get("method")}')
    print(f'Experimental: {result.get("experimental")}')
    print(f'Confidence: {result.get("confidence")}')
    if result.get('data'):
        print(f'Place: {result["data"].get("place")}')
        print(f'Distance: {result["data"].get("distance_meters")}m')
    else:
        print(f'Error: {result.get("error")}')
