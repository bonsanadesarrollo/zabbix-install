#!/bin/bash

confirm() {
    read -p "$1 (Y/n): " response
    case "$response" in
        [nN][oO]|[nN])
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

echo "Este script instalará Zabbix en tu sistema Ubuntu 22.04."
sudo systemctl stop ufw
sudo systemctl disable ufw

# Pedir confirmación para comenzar la instalación
if confirm "¿Quieres continuar con la actualización del sistema y la instalación de MariaDB?"; then
    echo "Actualizando el sistema..."
    apt update && apt upgrade -y
else
    echo "Actualización cancelada."
    exit 1
fi

# Instalación de MariaDB
if confirm "¿Quieres añadir el repositorio de MariaDB y proceder con su instalación?"; then
    echo "Instalando dependencias necesarias..."
    apt -y install software-properties-common curl
    echo "Añadiendo el repositorio de MariaDB..."
    curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-11.0"
    echo "Instalando MariaDB..."
    apt update
    apt -y install mariadb-server mariadb-client
else
    echo "Instalación de MariaDB cancelada."
    exit 1
fi

# Configuración de la base de datos
if confirm "¿Quieres crear la base de datos y el usuario para Zabbix?"; then
    echo "Configurando la base de datos de Zabbix..."
    mariadb -u root -e "
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost' IDENTIFIED BY 'B0ns4n4';
FLUSH PRIVILEGES;
"
else
    echo "Configuración de la base de datos cancelada."
    exit 1
fi


# Instalación de Zabbix
if confirm "¿Quieres descargar e instalar Zabbix?"; then
    echo "Descargando e instalando el repositorio de Zabbix..."
    wget https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu22.04_all.deb
    dpkg -i zabbix-release_6.0-4+ubuntu22.04_all.deb
    apt update
    echo "Instalando Zabbix..."
    apt install zabbix-agent zabbix-server-mysql php-mysql zabbix-frontend-php zabbix-sql-scripts zabbix-apache-conf
else
    echo "Instalación de Zabbix cancelada."
    exit 1
fi

# Verificación de la versión de Zabbix
if confirm "¿Quieres verificar la versión instalada de Zabbix?"; then
    apt-cache policy zabbix-server-mysql
else
    echo "Verificación de la versión omitida."
fi

# Importación de la base de datos
if confirm "¿Quieres importar la base de datos inicial para Zabbix?"; then
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mariadb --default-character-set=utf8mb4 -uzabbix -p'B0ns4n4' zabbix
else
    echo "Importación de la base de datos omitida."
fi

# Configuración del servidor Zabbix
if confirm "¿Quieres editar la configuración del servidor Zabbix?"; then
    sed -i 's/# DBPassword=/DBPassword=B0ns4n4/g' /etc/zabbix/zabbix_server.conf
    sed -i 's/# DBName=zabbix/DBName=zabbix/g' /etc/zabbix/zabbix_server.conf
    sed -i 's/# DBUser=zabbix/DBUser=zabbix/g' /etc/zabbix/zabbix_server.conf

    systemctl restart zabbix-server zabbix-agent apache2
    systemctl enable zabbix-server zabbix-agent apache2
    echo "Zabbix ha sido instalado y configurado correctamente."
else
    echo "Configuración del servidor Zabbix omitida."
fi

echo "Instalación completada."