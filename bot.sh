#!/bin/bash

# Ejecutar Speedtest infinito directamente desde la terminal (CentOS 7 compatible)

# Instalar speedtest-cli si no está instalado
if ! command -v speedtest-cli &> /dev/null; then
    echo "Instalando speedtest-cli..."
    yum install -y python-pip -q
    pip install speedtest-cli
fi

# Bucle infinito mostrando resultados en pantalla
while true; do
    echo "\n--- $(date '+%Y-%m-%d %H:%M:%S') ---"
    speedtest-cli --simple
    echo "-------------------------------"
    sleep 300
done
