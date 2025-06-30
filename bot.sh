#!/bin/bash

# -------------------- CONFIGURACIÓN INICIAL ----------------------

REPO_URL="https://github.com/DeekshithSH/TG-FileStreamBot.git"
REPO_BRANCH="Old-v2.0"
FOLDER_NAME="TG-FileStreamBot"
NGROK_DOMAIN_DEFAULT="ready-unlikely-osprey.ngrok-free.app"
PYTHON_EXEC="python3"

echo "🚀 Despliegue automático de TG-FileStreamBot"

# -------------------- CLONAR REPOSITORIO -------------------------

if [ ! -d "$FOLDER_NAME" ]; then
    echo "📥 Clonando repositorio $REPO_URL ..."
    git clone -b $REPO_BRANCH $REPO_URL || { echo "❌ Error al clonar el repositorio."; exit 1; }
else
    echo "📁 El repositorio ya está clonado: $FOLDER_NAME"
fi

cd "$FOLDER_NAME" || { echo "❌ No se pudo acceder al directorio $FOLDER_NAME"; exit 1; }

# -------------------- INPUT INTERACTIVO --------------------------

read -p "🔢 API_ID: " API_ID
read -p "🔐 API_HASH: " API_HASH
read -p "🤖 BOT_TOKEN: " BOT_TOKEN
read -p "📡 Puerto del bot [8080]: " PORT
PORT=${PORT:-8080}
read -p "🌍 Subdominio NGROK [$NGROK_DOMAIN_DEFAULT]: " STREAM_DOMAIN
STREAM_DOMAIN=${STREAM_DOMAIN:-$NGROK_DOMAIN_DEFAULT}

# -------------------- CREAR ARCHIVO .env --------------------------

echo "📄 Generando archivo .env..."
cat > .env <<EOF
API_ID=$API_ID
API_HASH=$API_HASH
BOT_TOKEN=$BOT_TOKEN
DATABASE_URL=sqlite:///streambot.db
PORT=$PORT
STREAM_DOMAIN=https://$STREAM_DOMAIN
PING_INTERVAL=1200
EOF

# -------------------- CREAR ENTORNO VIRTUAL -----------------------

if [ ! -d "venv" ]; then
    echo "🐍 Creando entorno virtual..."
    $PYTHON_EXEC -m venv venv || virtualenv -p /usr/bin/python3 venv
fi

echo "⚙️ Activando entorno virtual..."
source venv/bin/activate

# -------------------- INSTALAR DEPENDENCIAS -----------------------

echo "📦 Instalando dependencias..."
pip install --upgrade pip
pip install -r requirements.txt || pip install --no-cache-dir --compile pycurl
pip install python-dotenv

# -------------------- AÑADIR SOPORTE ENV ---------------------------

MAIN_FILE="WebStreamer/__main__.py"
ENV_CODE="from dotenv import load_dotenv; load_dotenv()"

if ! grep -q "load_dotenv()" "$MAIN_FILE"; then
    echo "🧩 Añadiendo soporte .env en $MAIN_FILE"
    sed -i "1i$ENV_CODE" "$MAIN_FILE"
fi

# -------------------- DESCARGAR NGROK ------------------------------

if [ ! -f "./ngrok" ]; then
    echo "📥 Descargando ngrok..."
    wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
    unzip ngrok-stable-linux-amd64.zip
    rm ngrok-stable-linux-amd64.zip
    chmod +x ngrok
fi

# -------------------- CONFIGURAR AUTHTOKEN NGROK -------------------

if [ ! -f "$HOME/.ngrok2/ngrok.yml" ]; then
    read -p "🔑 Ingresa tu Ngrok Authtoken: " NGROK_TOKEN
    ./ngrok authtoken $NGROK_TOKEN
fi

# -------------------- EJECUTAR NGROK -------------------------------

echo "🚪 Iniciando túnel Ngrok en https://$STREAM_DOMAIN ..."
./ngrok http --hostname=$STREAM_DOMAIN $PORT > /dev/null 2>&1 &

sleep 5

# -------------------- INICIAR BOT EN SEGUNDO PLANO -----------------

echo "🤖 Iniciando TG-FileStreamBot..."
nohup python3 -m WebStreamer > bot.log 2>&1 &

echo "✅ Bot desplegado exitosamente."
echo "🌐 Accede desde: https://$STREAM_DOMAIN"
echo "📄 Ver logs con: tail -f bot.log"
