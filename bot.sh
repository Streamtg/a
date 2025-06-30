#!/bin/bash

# ---------------- CONFIGURACIÓN GENERAL ----------------
REPO_URL="https://github.com/DeekshithSH/TG-FileStreamBot.git"
REPO_BRANCH="Old-v2.0"
REPO_DIR="TG-FileStreamBot"
NGROK_DOMAIN_DEFAULT="ready-unlikely-osprey.ngrok-free.app"
PYTHON_EXEC="python3"

# ---------------- CLONAR REPOSITORIO ----------------
if [ ! -d "$REPO_DIR" ]; then
    echo "📥 Clonando repositorio $REPO_URL ..."
    git clone -b $REPO_BRANCH $REPO_URL || { echo "❌ Error al clonar el repositorio."; exit 1; }
fi

cd "$REPO_DIR" || { echo "❌ No se pudo acceder al directorio $REPO_DIR"; exit 1; }

# ---------------- PEDIR VARIABLES AL USUARIO ----------------
read -p "🔢 API_ID: " API_ID
read -p "🔐 API_HASH: " API_HASH
read -p "🤖 BOT_TOKEN: " BOT_TOKEN
read -p "📡 Puerto del bot [8080]: " PORT
PORT=${PORT:-8080}
read -p "🌍 Subdominio NGROK [$NGROK_DOMAIN_DEFAULT]: " STREAM_DOMAIN
STREAM_DOMAIN=${STREAM_DOMAIN:-$NGROK_DOMAIN_DEFAULT}

# ---------------- CREAR ARCHIVO .env ----------------
cat > .env <<EOF
API_ID=$API_ID
API_HASH=$API_HASH
BOT_TOKEN=$BOT_TOKEN
DATABASE_URL=sqlite:///streambot.db
PORT=$PORT
STREAM_DOMAIN=https://$STREAM_DOMAIN
PING_INTERVAL=1200
EOF

echo "✅ Archivo .env generado."

# ---------------- ENTORNO VIRTUAL ----------------
if [ ! -d "venv" ]; then
    echo "🐍 Creando entorno virtual..."
    $PYTHON_EXEC -m venv venv || virtualenv -p /usr/bin/python3 venv
fi

source venv/bin/activate

# ---------------- DEPENDENCIAS ----------------
pip install --upgrade pip
pip install -r requirements.txt || pip install --no-cache-dir --compile pycurl
pip install python-dotenv

# ---------------- CARGAR .env EN CÓDIGO ----------------
MAIN_FILE="WebStreamer/__main__.py"
ENV_CODE="from dotenv import load_dotenv; load_dotenv()"
if ! grep -q "load_dotenv()" "$MAIN_FILE"; then
    echo "🧩 Añadiendo soporte para .env en $MAIN_FILE"
    sed -i "1i$ENV_CODE" "$MAIN_FILE"
fi

# ---------------- DESCARGAR NGROK ----------------
if [ ! -f "./ngrok" ]; then
    echo "📥 Descargando ngrok..."
    wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
    unzip ngrok-stable-linux-amd64.zip
    rm ngrok-stable-linux-amd64.zip
    chmod +x ngrok
fi

# ---------------- CONFIGURAR AUTHTOKEN ----------------
if [ ! -f "$HOME/.ngrok2/ngrok.yml" ]; then
    read -p "🔑 Ingresa tu Ngrok Authtoken: " NGROK_TOKEN
    ./ngrok authtoken $NGROK_TOKEN
fi

# ---------------- INICIAR NGROK ----------------
echo "🚪 Iniciando túnel Ngrok en https://$STREAM_DOMAIN ..."
./ngrok http --hostname=$STREAM_DOMAIN $PORT > /dev/null 2>&1 &

sleep 5

# ---------------- EJECUTAR BOT ----------------
echo "🤖 Iniciando TG-FileStreamBot..."
nohup python3 -m WebStreamer > bot.log 2>&1 &

echo ""
echo "✅ Bot desplegado exitosamente."
echo "🌐 Accede desde: https://$STREAM_DOMAIN"
echo "📄 Logs en: tail -f bot.log"
