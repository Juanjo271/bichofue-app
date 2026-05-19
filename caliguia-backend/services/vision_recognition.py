"""
Servicio de reconocimiento visual usando YOLOv2.6.

Características:
- Carga lazy del modelo (solo cuando se necesita)
- Fallback a GPS si el modelo no detecta con confianza suficiente
- Detecta 3 monumentos: La Tertulia, Cristo Rey, La Ermita
- Umbral de confianza 0.25 (modelo entrenado con 48 imágenes)
- Marca resultados como 'experimental' para gestionar expectativas
"""

import os
import tempfile
from PIL import Image
import io

# Lazy loading del modelo
_yolo_model = None

def get_model():
    """Carga el modelo YOLO26 de forma lazy."""
    global _yolo_model
    if _yolo_model is None:
        try:
            from ultralytics import YOLO
            model_path = os.path.join(os.path.dirname(__file__), '..', 'models', 'monumentos_cali.pt')
            print(f"[Vision] Cargando modelo desde: {model_path}")
            _yolo_model = YOLO(model_path)
            print("[Vision] Modelo cargado correctamente")
        except Exception as e:
            print(f"[Vision] Error cargando modelo: {e}")
            _yolo_model = False  # Marcar como fallido
    return _yolo_model if _yolo_model is not False else None

def recognize_image(image_file, user_lat=None, user_lon=None):
    """
    Intenta reconocer el monumento en la imagen usando YOLO26.
    
    Args:
        image_file: Archivo de imagen (werkzeug FileStorage)
        user_lat: Latitud del usuario (opcional)
        user_lon: Longitud del usuario (opcional)
    
    Returns:
        dict con:
            - detected: bool - si YOLO detectó algo
            - class_name: str - nombre de la clase detectada
            - confidence: float - confianza de la detección
            - experimental: bool - siempre True para gestionar expectativas
            - method: str - 'yolo26_experimental' o 'gps_fallback'
    """
    model = get_model()
    
    if model is None:
        return {
            'detected': False,
            'class_name': None,
            'confidence': 0.0,
            'experimental': True,
            'method': 'gps_fallback',
            'reason': 'modelo_no_disponible'
        }
    
    try:
        # Guardar imagen temporalmente
        img_bytes = image_file.read()
        image_file.seek(0)  # Reset para que pueda leerse de nuevo si es necesario
        
        # Convertir a PIL Image
        image = Image.open(io.BytesIO(img_bytes)).convert('RGB')
        
        # Inferencia con YOLOv2.6
        # Umbral 0.15 - balance entre detección y falsos positivos
        # Modelo entrenado con 48 imágenes de 3 monumentos
        results = model(image, conf=0.15, verbose=False)
        
        best_detection = None
        best_conf = 0.0
        
        for r in results:
            boxes = r.boxes
            if len(boxes) > 0:
                # Encontrar la detección con mayor confianza
                for box in boxes:
                    conf = box.conf.item()
                    if conf > best_conf:
                        best_conf = conf
                        cls_id = int(box.cls.item())
                        cls_name = r.names.get(cls_id, 'unknown')
                        best_detection = {
                            'class_name': cls_name,
                            'confidence': conf
                        }
        
        if best_detection:
            print(f"[Vision] Detección YOLO: {best_detection['class_name']} @ {best_detection['confidence']:.3f}")
            
            # Solo confiar si confianza >= 0.15
            # Modelo entrenado con 48 imágenes (La Tertulia, Cristo Rey, La Ermita)
            if best_detection['confidence'] >= 0.15:
                return {
                    'detected': True,
                    'class_name': best_detection['class_name'],
                    'confidence': round(best_detection['confidence'], 3),
                    'experimental': True,
                    'method': 'yolo26_experimental'
                }
        
        return {
            'detected': False,
            'class_name': None,
            'confidence': 0.0,
            'experimental': True,
            'method': 'gps_fallback',
            'reason': 'yolo_sin_deteccion_confiable'
        }
        
    except Exception as e:
        print(f"[Vision] Error en inferencia: {e}")
        return {
            'detected': False,
            'class_name': None,
            'confidence': 0.0,
            'experimental': True,
            'method': 'gps_fallback',
            'reason': f'error_inferencia: {str(e)}'
        }
