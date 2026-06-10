#!/usr/bin/env bash
# =============================================================================
# deploy-linux.sh - Déploiement FILE01 (Ubuntu Server 24.04)
# Intègre le serveur au domaine pme.local et configure les partages Samba.
# Auteur : mustapha
# Projet : 1PRJ2 - Mini-DSI PME
# =============================================================================
set -euo pipefail
 
# --- VARIABLES ---------------------------------------------------------------
DOMAIN="PME.LOCAL"
DOMAIN_LOWER="pme.local"
DC_IP="192.168.10.10"
SAMBA_IP="192.168.10.11"
INTERFACE="enp0s3"
ADMIN_USER="Administrator"
SHARES=("direction" "tech" "commercial")
 
# --- COULEURS ----------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
err()  { echo -e "${RED}[ERR ]${NC} $*"; exit 1; }
 
# --- ROOT CHECK --------------------------------------------------------------
[[ $EUID -ne 0 ]] && err "Ce script doit être exécuté en root (sudo)."
 
# --- ÉTAPE 1 : IP statique ---------------------------------------------------
info "Configuration IP statique sur $INTERFACE..."
cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    ${INTERFACE}:
      dhcp4: no
      addresses:
        - ${SAMBA_IP}/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [${DC_IP}]
        search: [${DOMAIN_LOWER}]
EOF
chmod 600 /etc/netplan/01-netcfg.yaml
netplan apply
ok "IP statique appliquée : $SAMBA_IP"
 
# --- ÉTAPE 2 : Mise à jour + paquets -----------------------------------------
info "Mise à jour du système et installation des paquets..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    samba samba-dsdb-modules samba-vfs-modules \
    winbind libnss-winbind libpam-winbind \
    krb5-user sssd sssd-ad \
    realmd adcli \
    acl attr \
    systemd-timesyncd
ok "Paquets installés."
 
# --- ÉTAPE 3 : NTP (synchronisation avec le DC) ------------------------------
info "Configuration NTP vers le DC..."
sed -i "s/^#NTP=.*/NTP=${DC_IP}/" /etc/systemd/timesyncd.conf
timedatectl set-ntp true
timedatectl set-timezone Europe/Paris
ok "NTP configuré."
 
# --- ÉTAPE 4 : Kerberos ------------------------------------------------------
info "Configuration Kerberos..."
cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${DOMAIN}
    dns_lookup_realm = true
    dns_lookup_kdc = true
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
 
[realms]
    ${DOMAIN} = {
        kdc = DC01.${DOMAIN_LOWER}
        admin_server = DC01.${DOMAIN_LOWER}
    }
 
[domain_realm]
    .${DOMAIN_LOWER} = ${DOMAIN}
    ${DOMAIN_LOWER} = ${DOMAIN}
EOF
ok "Kerberos configuré."
 
# --- ÉTAPE 5 : Jonction au domaine -------------------------------------------
info "Jonction au domaine ${DOMAIN}..."
echo "Entrez le mot de passe du compte ${ADMIN_USER}@${DOMAIN} :"
realm join --user="${ADMIN_USER}" "${DOMAIN}" || err "Jonction échouée. Vérifiez le DC et le mot de passe."
ok "FILE01 joint au domaine $DOMAIN."
 
# --- ÉTAPE 6 : Configuration Samba -------------------------------------------
info "Configuration de Samba..."
systemctl stop smbd nmbd winbind 2>/dev/null || true
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true
 
cat > /etc/samba/smb.conf <<EOF
[global]
    workgroup               = PME
    realm                   = ${DOMAIN}
    security                = ADS
    encrypt passwords       = yes
    kerberos method         = secrets and keytab
    winbind use default domain = yes
    winbind enum users      = yes
    winbind enum groups     = yes
    idmap config * : backend  = tdb
    idmap config * : range    = 1000-9999
    idmap config PME : backend = rid
    idmap config PME : range   = 10000-99999
    template shell          = /bin/bash
    template homedir        = /home/%D/%U
    vfs objects             = acl_xattr
    map acl inherit         = yes
    store dos attributes    = yes
    log file                = /var/log/samba/%m.log
    log level               = 1
    max log size            = 50
 
[direction]
    comment      = Partage Direction
    path         = /srv/shares/direction
    valid users  = @"PME\GRP-Direction"
    read only    = no
    browsable    = yes
    create mask  = 0660
    directory mask = 0770
 
[tech]
    comment      = Partage Tech
    path         = /srv/shares/tech
    valid users  = @"PME\GRP-Tech"
    read only    = no
    browsable    = yes
    create mask  = 0660
    directory mask = 0770
 
[commercial]
    comment      = Partage Commercial
    path         = /srv/shares/commercial
    valid users  = @"PME\GRP-Commercial"
    read only    = no
    browsable    = yes
    create mask  = 0660
    directory mask = 0770
EOF
ok "Samba configuré."
 
# --- ÉTAPE 7 : Création des dossiers de partage ------------------------------
info "Création des dossiers de partage..."
for share in "${SHARES[@]}"; do
    mkdir -p "/srv/shares/$share"
    chmod 2770 "/srv/shares/$share"
    chown root:root "/srv/shares/$share"
done
ok "Dossiers créés : ${SHARES[*]}"
 
# --- ÉTAPE 8 : NSS + PAM -----------------------------------------------------
info "Configuration NSS pour la résolution des comptes AD..."
sed -i 's/^passwd:.*/passwd: files winbind systemd/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:  files winbind systemd/'  /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow: files/'                 /etc/nsswitch.conf
pam-auth-update --enable mkhomedir
ok "NSS configuré."
 
# --- ÉTAPE 9 : Démarrage des services ----------------------------------------
info "Activation et démarrage des services Samba..."
systemctl enable --now smbd nmbd winbind
ok "Services Samba démarrés."
 
# --- ÉTAPE 10 : Pare-feu ufw -------------------------------------------------
info "Configuration du pare-feu ufw..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.10.0/24 to any port 22  proto tcp comment "SSH réseau interne"
ufw allow from 192.168.10.0/24 to any port 445 proto tcp comment "Samba SMB"
ufw allow from 192.168.10.0/24 to any port 139 proto tcp comment "Samba NetBIOS"
ufw allow from 192.168.10.0/24 to any port 138 proto udp comment "Samba NetBIOS-dgm"
ufw --force enable
ok "Pare-feu configuré."
 
# --- VÉRIFICATION FINALE -----------------------------------------------------
echo ""
info "=== Vérification finale ==="
wbinfo -u | head -5 && ok "Winbind fonctionnel." || err "Winbind KO - vérifiez la jonction au domaine."
testparm -s 2>/dev/null | grep -E '\[(direction|tech|commercial)\]' && ok "Partages Samba OK."
echo ""
ok "============================================"
ok " Déploiement FILE01 terminé avec succès !"
ok "============================================"
