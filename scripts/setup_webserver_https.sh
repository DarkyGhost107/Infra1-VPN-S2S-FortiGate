#!/bin/bash
# ============================================================
# setup_webserver_https.sh
# Servidor web HTTPS (Apache + certificado autofirmado) en Ubuntu
# Autor: Diego - Matricula 2023-0316 - ITLA
#
# Requisito previo (con internet):
#   sudo apt update && sudo apt install -y apache2 openssl ufw
#   (Infra 3 tambien: openssh-server)
#
# Uso:  sudo bash setup_webserver_https.sh
#       Infra 3: sudo HABILITAR_SSH=si bash setup_webserver_https.sh
# ============================================================

# ---- Variables ----
IFACE="ens3"                 # nombre de la interfaz (ver con: ip a)
IP_SRV="10.23.16.130/28"
GW_SRV="10.23.16.129"
DNS="8.8.8.8"
HABILITAR_SSH="${HABILITAR_SSH:-no}"
RED_VPN="10.23.16.192/28"    # pool de la VPN de acceso remoto (solo Infra 3)

# ---- Verificar que los paquetes esten instalados ----
for p in apache2 openssl ufw; do
  if ! dpkg -s $p >/dev/null 2>&1; then
    echo "ERROR: falta el paquete $p. Instalelo con internet: sudo apt install -y apache2 openssl ufw"
    exit 1
  fi
done

echo "[1/5] Configurando IP estatica en $IFACE..."
rm -f /etc/netplan/50-cloud-init.yaml /etc/netplan/00-installer-config.yaml
# Evitar que cloud-init vuelva a poner DHCP al reiniciar
mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
cat > /etc/netplan/01-lab.yaml <<NET
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: no
      addresses: [$IP_SRV]
      routes:
        - to: default
          via: $GW_SRV
      nameservers:
        addresses: [$DNS]
NET
chmod 600 /etc/netplan/01-lab.yaml
netplan apply

echo "[2/5] Generando certificado autofirmado..."
mkdir -p /etc/ssl/lab
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/lab/web.key -out /etc/ssl/lab/web.crt \
  -subj "/C=DO/O=ITLA/OU=SeguridadRedes/CN=10.23.16.130"

echo "[3/5] Creando pagina web..."
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8"><title>Servidor Web - Lab VPN</title></head>
<body style="font-family:Arial;background:#1F3864;color:white;text-align:center;padding-top:80px">
<h1>Servidor Web HTTPS</h1>
<p>Laboratorio de VPN - Seguridad de Redes - ITLA</p>
<p>Diego - Matricula 2023-0316</p>
<p>Servidor: 10.23.16.130</p>
</body></html>
HTML

echo "[4/5] Configurando Apache con HTTPS..."
cat > /etc/apache2/sites-available/lab-ssl.conf <<SITE
<VirtualHost *:443>
    ServerName 10.23.16.130
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/lab/web.crt
    SSLCertificateKeyFile /etc/ssl/lab/web.key
</VirtualHost>
SITE
cat > /etc/apache2/sites-available/000-default.conf <<SITE
<VirtualHost *:80>
    Redirect permanent / https://10.23.16.130/
</VirtualHost>
SITE
a2enmod ssl >/dev/null
a2ensite lab-ssl >/dev/null
systemctl enable apache2 >/dev/null 2>&1
systemctl restart apache2

echo "[5/5] Firewall local (ufw)..."
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 80/tcp
ufw allow 443/tcp
if [ "$HABILITAR_SSH" = "si" ]; then
  systemctl enable --now ssh
  ufw allow from $RED_VPN to any port 22 proto tcp
  echo "SSH permitido solo desde $RED_VPN"
else
  ufw allow 22/tcp
fi
ufw --force enable

echo "==== Listo ===="
ip -4 addr show $IFACE | grep inet
ss -tlnp | grep -E ':443|:80|:22'
