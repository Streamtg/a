from pyrogram import Client, filters
from pyrogram.types import Message
from PIL import Image
from pydub import AudioSegment
import subprocess
import os
import mimetypes
import shutil

API_ID = 10565113
API_HASH = "d2220b87fb12fc430dc8fcebbb03d95c"
BOT_TOKEN = "8256526472:AAHyvbxwrK1Z8_CcU9p4Odh6y6twjJKEzhc"

app = Client("universal_media_bot", api_id=API_ID, api_hash=API_HASH, bot_token=BOT_TOKEN)

# Funciones de procesamiento
def sanitize_image(path, output_path):
    try:
        img = Image.open(path)
        # Eliminar metadatos EXIF
        data = list(img.getdata())
        img_clean = Image.new(img.mode, img.size)
        img_clean.putdata(data)
        img_clean.save(output_path, optimize=True)
    except Exception as e:
        print(f"Error al procesar imagen: {e}")
        raise

def sanitize_audio(path, output_path):
    try:
        audio = AudioSegment.from_file(path)
        audio.export(output_path, format="mp3", bitrate="192k")
    except Exception as e:
        print(f"Error al procesar audio: {e}")
        raise

def sanitize_video(path, output_path):
    try:
        subprocess.run([
            "ffmpeg", "-i", path,
            "-c:v", "libx264", "-preset", "fast",
            "-c:a", "aac", "-b:a", "128k",
            output_path
        ], check=True)
    except Exception as e:
        print(f"Error al procesar video: {e}")
        raise

@app.on_message(filters.document | filters.audio | filters.video | filters.photo)
async def universal_rewriter(client: Client, message: Message):
    file_path = None
    new_path = None
    try:
        file_path = await message.download()
        if not file_path or not os.path.exists(file_path):
            raise ValueError("No se pudo descargar el archivo o la ruta es inválida.")
        
        filename = os.path.basename(file_path)
        mime_type, _ = mimetypes.guess_type(file_path)

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
                shutil.copy(file_path, new_path)
        else:
            new_path = f"rewritten_{filename}"
            shutil.copy(file_path, new_path)

        if not os.path.exists(new_path):
            raise ValueError("No se generó el archivo procesado.")

        await message.reply_document(new_path)
    except Exception as e:
        print(f"Error general: {e}")
        await message.reply_text("No se pudo procesar el archivo.")
    finally:
        if file_path and os.path.exists(file_path):
            try:
                os.remove(file_path)
            except OSError:
                pass
        if new_path and os.path.exists(new_path):
            try:
                os.remove(new_path)
            except OSError:
                pass

app.run()
