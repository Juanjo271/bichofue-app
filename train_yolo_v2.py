#!/usr/bin/env python3
"""
Bichofué - Entrenamiento YOLOv2.6 Monumentos de Cali
Modelo: yolo26n.pt (NMS-free, optimizado edge)
Dataset: 3 clases - LA TERTULIA, cristo rey, la ermita
"""

import os
import sys
from pathlib import Path

# Usar el modelo base desde YOLO26_Ermita
BASE_MODEL = '/home/juan/Escritorio/YOLO26_Ermita/yolo26n.pt'
DATA_YAML = '/home/juan/Escritorio/ProyectoFInal/Dataset/data.yaml'

def main():
    print("=" * 70)
    print("🐦 Bichofué - Entrenamiento YOLOv2.6 Monumentos de Cali")
    print("=" * 70)
    
    # Verificar dependencias
    try:
        from ultralytics import YOLO
    except ImportError:
        print("❌ Error: ultralytics no instalado")
        print("   Ejecuta: pip install ultralytics")
        sys.exit(1)
    
    # Verificar archivos necesarios
    if not os.path.exists(BASE_MODEL):
        print(f"❌ Error: No se encontró el modelo base en {BASE_MODEL}")
        sys.exit(1)
    
    if not os.path.exists(DATA_YAML):
        print(f"❌ Error: No se encontró {DATA_YAML}")
        sys.exit(1)
    
    # Verificar estructura del dataset
    dataset_dir = Path(DATA_YAML).parent
    for split in ['train', 'valid', 'test']:
        img_dir = dataset_dir / split / 'images'
        if not img_dir.exists():
            print(f"❌ Error: No existe {img_dir}")
            sys.exit(1)
        n_images = len(list(img_dir.glob('*')))
        print(f"   📁 {split}: {n_images} imágenes")
    
    print(f"   📄 data.yaml: {DATA_YAML}")
    print(f"   🧠 Modelo base: {BASE_MODEL}")
    print("-" * 70)
    
    # Cargar modelo YOLOv2.6
    print("\n📥 Cargando YOLOv2.6n...")
    model = YOLO(BASE_MODEL)
    
    print("\n🚀 Iniciando entrenamiento...")
    print("   Modelo: YOLOv2.6n (NMS-free, optimizado edge)")
    print("   Clases: LA TERTULIA, cristo rey, la ermita")
    print("   Epochs: 100")
    print("   Batch: 4")
    print("   GPU: RTX 3050")
    print("-" * 70)
    
    # Entrenar
    results = model.train(
        data=DATA_YAML,
        epochs=100,
        imgsz=640,
        batch=4,
        device=0,
        patience=20,
        augment=True,
        project='/home/juan/Escritorio/ProyectoFInal/runs/detect',
        name='monumentos_cali_v2',
        exist_ok=True,
    )
    
    # Resultados
    print("\n" + "=" * 70)
    print("✅ ENTRENAMIENTO COMPLETADO")
    print("=" * 70)
    
    metrics = results.results_dict
    print(f"\n📊 Métricas:")
    print(f"   mAP50:     {metrics.get('metrics/mAP50(B)', 'N/A')}")
    print(f"   mAP50-95:  {metrics.get('metrics/mAP50-95(B)', 'N/A')}")
    print(f"   Precision: {metrics.get('metrics/precision(B)', 'N/A')}")
    print(f"   Recall:    {metrics.get('metrics/recall(B)', 'N/A')}")
    
    # Mostrar métricas por clase si están disponibles
    try:
        import pandas as pd
        results_path = Path(results.save_dir) / 'results.csv'
        if results_path.exists():
            print(f"\n📁 Resultados guardados en: {results.save_dir}")
    except Exception:
        pass
    
    # Exportar a TFLite (opcional, para móvil)
    print("\n📦 Exportando a TensorFlow Lite (INT8)...")
    try:
        model.export(
            format='tflite',
            int8=True,
            data=DATA_YAML,
        )
        print("   ✅ TFLite exportado")
    except Exception as e:
        print(f"   ⚠️  Error exportando TFLite: {e}")
    
    # Copiar modelo final al Escritorio
    best_pt = Path(results.save_dir) / 'weights' / 'best.pt'
    dest_path = '/home/juan/Escritorio/YOLO26_Ermita/models/monumentos_cali.pt'
    
    if best_pt.exists():
        import shutil
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        shutil.copy(str(best_pt), dest_path)
        print(f"\n📋 Modelo copiado a:")
        print(f"   {dest_path}")
    
    print("\n" + "=" * 70)
    print("🎉 TODO LISTO")
    print("=" * 70)
    print("\n📁 Archivos generados:")
    print(f"   {results.save_dir}/weights/best.pt     (PyTorch)")
    print(f"   {results.save_dir}/weights/best.tflite (TFLite)")
    print(f"   {dest_path} (copiado para backend)")

if __name__ == '__main__':
    main()
