#!/bin/bash

# Variables configurables
REPO="https://github.com/DeekshithSH/TG-FileStreamBot.git"
BRANCH="Old-v2.0"
DIR="TG-FileStreamBot"
NGROK_URL="ready-unlikely-osprey.ngrok-free.app"
PORT=8080

# Función para leer variables de forma segura
function input {
    local var_name="$1"
    local prompt="$2"
    local default="$3"
    read -p "$prompt" input_value
    if [ -z "$input_value" ]; then
        eval $var_name="$default"
    else
        eval $var_name="$input_value"
    fi
}

echo "=== Preparando entorno para TG-FileStreamBot en CentOS 7 ==="

# Clonar repo si no existe
if [ ! -d "$DIR" ]; then
    echo "Clonando repositorio..."
    git clone -b "$BRANCH" "$REPO" || { echo "Error al clonar"; exit 1; }
else
    echo "Repositorio ya existe."
fi

cd "$DIR" || { echo "No se pudo acceder al directorio"; exit 1; }

# Solicitar credenciales
input API_ID "Ingrese API_ID: "
input API_HASH "Ingrese API_HASH: "
input BOT_TOKEN "Ingrese BOT_TOKEN: "
input PORT "Ingrese puerto para bot (default 8080): " 8080
input NGROK_URL "Ingrese subdominio ngrok (default $NGROK_URL): " "$NGROK_URL"

# Crear archivo .env
cat > .env <<EOF
API_ID=$API_ID
API_HASH=$API_HASH
BOT_TOKEN=$BOT_TOKEN
DATABASE_URL=sqlite:///streambot.db
PORT=$PORT
STREAM_DOMAIN=https://$NGROK_URL
PING_INTERVAL=1200
EOF

echo ".env creado."

# Crear y activar entorno virtual
if [ ! -d "venv" ]; then
    echo "Creando entorno virtual..."
    python3 -m venv venv || virtualenv -p python3 venv
fi

source venv/bin/activate

# Instalar dependencias
pip install --upgrade pip
pip install -r requirements.txt

# Añadir soporte dotenv si no existe
MAIN="WebStreamer/__main__.py"
if ! grep -q "load_dotenv" "$MAIN"; then
    sed -i '1ifrom dotenv import load_dotenv; load_dotenv()' "$MAIN"
fi

# Descargar ngrok si no existe
if [ ! -f "./ngrok" ]; then
    echo "Descargando ngrok..."
    wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
    unzip -o ngrok-stable-linux-amd64.zip
    rm -f ngrok-stable-linux-amd64.zip
    chmod +x ngrok
fi

# Configurar token ngrok si no existe
if [ ! -f "$HOME/.ngrok2/ngrok.yml" ]; then
    read -p "Ingrese ngrok authtoken: " NGROK_TOKEN
    ./ngrok authtoken "$NGROK_TOKEN"
fi

# Iniciar ngrok en background
nohup ./ngrok http --hostname="$NGROK_URL" "$PORT" > /dev/null 2>&1 &

sleep 5

# Iniciar bot en background
nohup python3 -m WebStreamer > bot.log 2>&1 &

echo "Bot iniciado con ngrok en https://$NGROK_URL"
echo "Ver logs: tail -f bot.log"
