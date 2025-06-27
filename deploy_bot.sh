#!/bin/bash

# =========================
# DEPLOY TELEGRAM BOT + WEB UI + NGROK (NO ROOT)
# =========================

# CONFIGURA ESTOS DATOS
BOT_TOKEN="TU_TOKEN_DE_TELEGRAM_AQUI"
PORT=5000

# Nombres de carpetas
APP_DIR="$HOME/tg_bot_stream"
VENV_DIR="$APP_DIR/venv"
MEDIA_DIR="$APP_DIR/media"
NGROK_ZIP="ngrok-stable-linux-amd64.zip"
NGROK_BIN="$APP_DIR/ngrok"

echo "[+] Creando estructura de carpetas en $APP_DIR..."
mkdir -p "$APP_DIR" "$MEDIA_DIR"
cd "$APP_DIR" || exit 1

# =========================
# 1. Instalar entorno virtual (sin root)
# =========================
echo "[+] Creando entorno virtual..."
python3 -m venv venv
source "$VENV_DIR/bin/activate"

echo "[+] Instalando dependencias (Flask, telegram)..."
pip install --upgrade pip
pip install flask python-telegram-bot pyngrok

# =========================
# 2. Descargar NGROK local
# =========================
if [ ! -f "$NGROK_BIN" ]; then
  echo "[+] Descargando ngrok localmente..."
  wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -O "$NGROK_ZIP"
  unzip -q "$NGROK_ZIP" -d "$APP_DIR"
  chmod +x "$NGROK_BIN"
  rm "$NGROK_ZIP"
fi

# =========================
# 3. Crear app.py (servidor web)
# =========================
echo "[+] Generando archivo app.py (Flask)..."

cat > "$APP_DIR/app.py" <<EOF
from flask import Flask, send_from_directory, render_template_string
import os

app = Flask(__name__)
MEDIA_FOLDER = "media"

@app.route("/")
def index():
    files = os.listdir(MEDIA_FOLDER)
    html = "<h2>Archivos Multimedia</h2><ul>"
    for f in files:
        ext = f.split('.')[-1]
        path = f"/file/{f}"
        if ext in ['mp4', 'webm']:
            html += f"<li><video controls width='320'><source src='{path}'></video></li>"
        elif ext in ['mp3', 'wav']:
            html += f"<li><audio controls><source src='{path}'></audio></li>"
        elif ext in ['jpg', 'jpeg', 'png']:
            html += f"<li><img src='{path}' width='200'></li>"
        else:
            html += f"<li><a href='{path}' download>{f}</a></li>"
    html += "</ul>"
    return render_template_string(html)

@app.route("/file/<path:filename>")
def serve_file(filename):
    return send_from_directory(MEDIA_FOLDER, filename)

if __name__ == "__main__":
    app.run(port=$PORT)
EOF

# =========================
# 4. Crear bot.py
# =========================
echo "[+] Generando archivo bot.py (Telegram Bot)..."

cat > "$APP_DIR/bot.py" <<EOF
from telegram.ext import Application, MessageHandler, filters
import os

TOKEN = "$BOT_TOKEN"
MEDIA_FOLDER = "media"

async def handle_file(update, context):
    message = update.message
    if message.document:
        file = await message.document.get_file()
        filename = message.document.file_name
    elif message.photo:
        file = await message.photo[-1].get_file()
        filename = f"photo_{message.message_id}.jpg"
    elif message.video:
        file = await message.video.get_file()
        filename = f"video_{message.message_id}.mp4"
    elif message.audio:
        file = await message.audio.get_file()
        filename = f"audio_{message.message_id}.mp3"
    else:
        return

    path = os.path.join(MEDIA_FOLDER, filename)
    await file.download_to_drive(path)
    await message.reply_text(f"Archivo guardado: {filename}")

app = Application.builder().token(TOKEN).build()
app.add_handler(MessageHandler(filters.ALL & (~filters.COMMAND), handle_file))
app.run_polling()
EOF

# =========================
# 5. Crear script de ngrok
# =========================
echo "[+] Generando script ngrok.sh..."

cat > "$APP_DIR/ngrok.sh" <<EOF
#!/bin/bash
cd "$(dirname "\$0")"
./ngrok http $PORT > ngrok.log &
sleep 3
URL=\$(curl -s http://localhost:4040/api/tunnels | grep -o 'https://[^"]*')
echo "[+] ngrok URL pública: \$URL"
EOF

chmod +x "$APP_DIR/ngrok.sh"

# =========================
# 6. Crear script de arranque general
# =========================
echo "[+] Generando start_all.sh..."

cat > "$APP_DIR/start_all.sh" <<EOF
#!/bin/bash
cd "$(dirname "\$0")"
source venv/bin/activate
./ngrok.sh
gnome-terminal -- bash -c "python3 app.py; exec bash"
gnome-terminal -- bash -c "python3 bot.py; exec bash"
EOF

chmod +x "$APP_DIR/start_all.sh"

# =========================
# 7. Final
# =========================
echo "[✓] Proyecto generado exitosamente en $APP_DIR"
echo "Para iniciar todo, ejecuta:"
echo "  cd $APP_DIR"
echo "  source venv/bin/activate"
echo "  ./start_all.sh"
