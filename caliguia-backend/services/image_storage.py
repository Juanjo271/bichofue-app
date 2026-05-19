import os
import shutil
from werkzeug.utils import secure_filename
from config import Config

class ImageStorageService:
    """Servicio para almacenar y servir imágenes de atractivos turísticos."""
    
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp'}
    UPLOAD_FOLDER = os.path.join(Config.BASE_DIR, 'static', 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max
    
    @staticmethod
    def init_storage():
        """Inicializa el directorio de almacenamiento."""
        os.makedirs(ImageStorageService.UPLOAD_FOLDER, exist_ok=True)
    
    @staticmethod
    def allowed_file(filename: str) -> bool:
        """Verifica si la extensión del archivo es permitida."""
        return '.' in filename and \
               filename.rsplit('.', 1)[1].lower() in ImageStorageService.ALLOWED_EXTENSIONS
    
    @staticmethod
    def save_image(file, atractivo_id: int) -> str:
        """Guarda una imagen para un atractivo específico.
        
        Args:
            file: Objeto File de Flask (request.files['image'])
            atractivo_id: ID del atractivo
            
        Returns:
            Ruta relativa de la imagen guardada
        """
        ImageStorageService.init_storage()
        
        if not file or not file.filename:
            return None
        
        if not ImageStorageService.allowed_file(file.filename):
            return None
        
        # Generar nombre seguro
        ext = file.filename.rsplit('.', 1)[1].lower()
        filename = f"atractivo_{atractivo_id}.{ext}"
        filepath = os.path.join(ImageStorageService.UPLOAD_FOLDER, filename)
        
        # Guardar archivo
        file.save(filepath)
        
        # Retornar URL relativa
        return f"/static/uploads/{filename}"
    
    @staticmethod
    def get_image_path(atractivo_id: int) -> str:
        """Obtiene la ruta de la imagen de un atractivo si existe."""
        for ext in ImageStorageService.ALLOWED_EXTENSIONS:
            filepath = os.path.join(ImageStorageService.UPLOAD_FOLDER, f"atractivo_{atractivo_id}.{ext}")
            if os.path.exists(filepath):
                return f"/static/uploads/atractivo_{atractivo_id}.{ext}"
        return None
    
    @staticmethod
    def delete_image(atractivo_id: int) -> bool:
        """Elimina la imagen de un atractivo."""
        for ext in ImageStorageService.ALLOWED_EXTENSIONS:
            filepath = os.path.join(ImageStorageService.UPLOAD_FOLDER, f"atractivo_{atractivo_id}.{ext}")
            if os.path.exists(filepath):
                os.remove(filepath)
                return True
        return False
