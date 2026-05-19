import asyncio
import os
import edge_tts
from config import Config

class EdgeTTSService:
    """Servicio de Text-to-Speech usando Edge-TTS (Microsoft Edge voices).
    
    Genera audios neurales de alta calidad en español colombiano.
    Voz por defecto: es-CO-SalomeNeural (mujer, acento colombiano)
    Alternativa: es-CO-GonzaloNeural (hombre)
    """
    
    DEFAULT_VOICE = "es-CO-SalomeNeural"
    ALTERNATIVE_VOICE = "es-CO-GonzaloNeural"
    
    @staticmethod
    def generate_audio(text: str, output_filename: str = None, voice: str = None) -> str:
        """Genera un archivo MP3 a partir de texto.
        
        Args:
            text: Texto a convertir a voz
            output_filename: Nombre del archivo de salida (sin extensión)
            voice: Voz a usar (default: SalomeNeural colombiana)
            
        Returns:
            Ruta al archivo MP3 generado
        """
        if not text or not text.strip():
            return None
            
        voice = voice or EdgeTTSService.DEFAULT_VOICE
        
        # Asegurar que existe el directorio de cache
        os.makedirs(Config.AUDIO_CACHE_DIR, exist_ok=True)
        
        # Generar nombre de archivo si no se proporciona
        if not output_filename:
            import hashlib
            text_hash = hashlib.md5(text.encode()).hexdigest()[:8]
            output_filename = f"audio_{text_hash}"
        
        output_path = os.path.join(Config.AUDIO_CACHE_DIR, f"{output_filename}.mp3")
        
        # Si ya existe, no regenerar
        if os.path.exists(output_path):
            return output_path
        
        try:
            # Ejecutar async en sync
            asyncio.run(EdgeTTSService._generate(text, output_path, voice))
            return output_path
        except Exception as e:
            print(f"[EdgeTTS] Error generando audio: {e}")
            return None
    
    @staticmethod
    async def _generate(text: str, output_path: str, voice: str):
        communicate = edge_tts.Communicate(text, voice=voice)
        await communicate.save(output_path)
        print(f"[EdgeTTS] Audio generado: {output_path}")
    
    @staticmethod
    def generate_for_attraction(atractivo_id: int, text: str) -> str:
        """Genera audio para un atractivo específico."""
        filename = f"atractivo_{atractivo_id}"
        return EdgeTTSService.generate_audio(text, filename)
    
    @staticmethod
    def cleanup_old_files(max_age_days: int = 7, keep_attraction_files: bool = True):
        """Elimina archivos MP3 antiguos del cache.
        
        Args:
            max_age_days: Eliminar archivos más antiguos que X días
            keep_attraction_files: Si True, no borra audios de atractivos (atractivo_*.mp3)
        Returns:
            (eliminados, errores, bytes_liberados)
        """
        import time
        if not os.path.exists(Config.AUDIO_CACHE_DIR):
            return 0, 0, 0
        
        cutoff = time.time() - (max_age_days * 86400)
        deleted = 0
        errors = 0
        bytes_freed = 0
        
        for filename in os.listdir(Config.AUDIO_CACHE_DIR):
            if not filename.endswith('.mp3'):
                continue
            if keep_attraction_files and filename.startswith('atractivo_'):
                continue
            filepath = os.path.join(Config.AUDIO_CACHE_DIR, filename)
            try:
                stat = os.stat(filepath)
                if stat.st_mtime < cutoff:
                    bytes_freed += stat.st_size
                    os.remove(filepath)
                    deleted += 1
                    print(f"[EdgeTTS Cleanup] Eliminado: {filename} ({stat.st_size} bytes)")
            except Exception as e:
                errors += 1
                print(f"[EdgeTTS Cleanup] Error eliminando {filename}: {e}")
        
        print(f"[EdgeTTS Cleanup] Resumen: {deleted} eliminados, {errors} errores, {bytes_freed} bytes liberados")
        return deleted, errors, bytes_freed
    
    @staticmethod
    def list_available_voices():
        """Lista las voces disponibles de Edge-TTS."""
        try:
            voices = asyncio.run(edge_tts.list_voices())
            es_voices = [v for v in voices if v['Locale'].startswith('es')]
            return es_voices
        except Exception as e:
            print(f"[EdgeTTS] Error listando voces: {e}")
            return []


# Función de conveniencia
def generate_tts(text: str, filename: str = None) -> str:
    return EdgeTTSService.generate_audio(text, filename)
