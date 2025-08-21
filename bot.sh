from pyrogram import Client, filters
from pyrogram.types import Message
from PIL import Image
from pydub import AudioSegment
import subprocess
import os
import mimetypes

API_ID = 12345
API_HASH = "YOUR_API_HASH"
BOT_TOKEN = "YOUR_BOT_TOKEN"

app = Client("universal_media_bot", api_id=API_ID, api_hash=API_HASH, bot_token=BOT_TOKEN)

# Funciones de procesamiento
def sanitize_image(path, output_path):
    try:
        img = Image.open(path)
        img.save(output_path, optimize=True)
        # Eliminar metadatos EXIF
        data = list(img.getdata())
        img_clean = Image.new(img.mode, img.size)
        img_clean.putdata(data)
        img_clean.save(output_path)
    except Exception as e:
        print(f"Error al procesar imagen: {e}")

def sanitize_audio(path, output_path):
    try:
        audio = AudioSegment.from_file(path)
        audio.export(output_path, format="mp3", bitrate="192k")
    except Exception as e:
        print(f"Error al procesar audio: {e}")

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

@app.on_message(filters.document | filters.audio | filters.video | filters.photo)
async def universal_rewriter(client: Client, message: Message):
    # Descargar archivo
    file_path = await message.download()
    filename = os.path.basename(file_path)
    new_path = f"rewritten_{filename}"

    mime_type, _ = mimetypes.guess_type(file_path)

    # Determinar tipo y procesar
    try:
        if mime_type:
            if mime_type.startswith("image"):
                sanitize_image(file_path, new_path)
            elif mime_type.startswith("audio"):
                sanitize_audio(file_path, new_path)
            elif mime_type.startswith("video"):
                sanitize_video(file_path, new_path)
            else:
                # Si no es multimedia, simplemente lo copia
                subprocess.run(["cp", file_path, new_path])
        else:
            # Desconocido: copiar
            subprocess.run(["cp", file_path, new_path])
    except Exception as e:
        print(f"Error general: {e}")
        await message.reply_text("No se pudo procesar el archivo.")
        os.remove(file_path)
        return

    # Enviar archivo procesado
    await message.reply_document(new_path)

    # Limpiar archivos temporales
    os.remove(file_path)
    os.remove(new_path)

app.run()
