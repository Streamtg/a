from pyrogram import Client, filters
from pyrogram.types import Message
from PIL import Image
from pydub import AudioSegment
import subprocess
import os
import mimetypes
import shutil
import logging

# Configurar logging para depuración
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

API_ID = 10565113
API_HASH = "d2220b87fb12fc430dc8fcebbb03d95c"
BOT_TOKEN = "8256526472:AAHyvbxwrK1Z8_CcU9p4Odh6y6twjJKEzhc"

app = Client("universal_media_bot", api_id=API_ID, api_hash=API_HASH, bot_token=BOT_TOKEN)

# Funciones de procesamiento
def sanitize_image(path, output_path):
    try:
        logger.info(f"Procesando imagen: {path}")
        img = Image.open(path)
        # Eliminar metadatos EXIF
        data = list(img.getdata())
        img_clean = Image.new(img.mode, img.size)
        img_clean.putdata(data)
        img_clean.save(output_path, optimize=True)
        logger.info(f"Imagen procesada guardada en: {output_path}")
    except Exception as e:
        logger.error(f"Error al procesar imagen {path}: {e}")
        raise

def sanitize_audio(path, output_path):
    try:
        logger.info(f"Procesando audio: {path}")
        audio = AudioSegment.from_file(path)
        audio.export(output_path, format="mp3", bitrate="192k")
        logger.info(f"Audio procesado guardado en: {output_path}")
    except Exception as e:
        logger.error(f"Error al procesar audio {path}: {e}")
        raise

def sanitize_video(path, output_path):
    try:
        logger.info(f"Procesando video: {path}")
        result = subprocess.run([
            "ffmpeg", "-i", path,
            "-c:v", "libx264", "-preset", "fast",
            "-c:a", "aac", "-b:a", "128k",
            output_path
        ], check=True, capture_output=True, text=True)
        logger.info(f"Video procesado guardado en: {output_path}")
    except subprocess.CalledProcessError as e:
        logger.error(f"Error de FFmpeg al procesar video {path}: {e.stderr}")
        raise
    except Exception as e:
        logger.error(f"Error al procesar video {path}: {e}")
        raise

@app.on_message(filters.document | filters.audio | filters.video | filters.photo)
async def universal_rewriter(client: Client, message: Message):
    file_path = None
    new_path = None
    try:
        # Descargar archivo con un nombre único para evitar conflictos
        file_path = await message.download(file_name=f"download_{message.id}_{message.document.file_name if message.document else 'media'}")
        if not file_path or not os.path.exists(file_path):
            logger.error(f"No se pudo descargar el archivo o la ruta no existe: {file_path}")
            raise ValueError("No se pudo descargar el archivo o la ruta es inválida.")
        
        logger.info(f"Archivo descargado en: {file_path}")
        filename = os.path.basename(file_path)
        mime_type, _ = mimetypes.guess_type(file_path)
        logger.info(f"Tipo MIME detectado: {mime_type}")

        # Determinar tipo y procesar
        if mime_type:
            if mime_type.startswith("image"):
                new_path = f"rewritten_{filename}"
                sanitize_image(file_path, new_path)
            elif mime_type.startswith("audio"):
                base_name = os.path.splitext(filename)[0]
                new_path = f"rewritten_{base_name}.mp3"
                sanitize_audio(file_path, new_path)
            elif mime_type.startswith("video"):
                base_name = os.path.splitext(filename)[0]
                new_path = f"rewritten_{base_name}.mp4"
                sanitize_video(file_path, new_path)
            else:
                new_path = f"rewritten_{filename}"
                logger.info(f"Copiando archivo no multimedia: {file_path}")
                shutil.copy(file_path, new_path)
        else:
            new_path = f"rewritten_{filename}"
            logger.info(f"Tipo MIME desconocido, copiando archivo: {file_path}")
            shutil.copy(file_path, new_path)

        if not os.path.exists(new_path):
            logger.error(f"No se generó el archivo procesado: {new_path}")
            raise ValueError("No se generó el archivo procesado.")

        # Enviar archivo procesado
        logger.info(f"Enviando archivo procesado: {new_path}")
        await message.reply_document(new_path)
    except Exception as e:
        logger.error(f"Error general al procesar archivo {file_path}: {e}")
        await message.reply_text(f"No se pudo procesar el archivo: {str(e)}")
    finally:
        # Limpiar archivos temporales
        for path in [file_path, new_path]:
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                    logger.info(f"Archivo eliminado: {path}")
                except OSError as e:
                    logger.error(f"Error al eliminar archivo {path}: {e}")

if __name__ == "__main__":
    app.run()
