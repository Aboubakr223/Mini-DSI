#!/usr/bin/env bash
# setup-backup-server.sh — Initialisation de BACKUP01 (192.168.10.30)
# Auteur : ayman
set -euo pipefail

BACKUP_IP="192.168.10.30"
INTERFACE="enp0s3"
BACKUP_USER="backupuser"
SAMBA_IP="192.168.10.20"
BACKUP_DIR="/backups"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
ok()   { echo "[ OK ] $*"; }
err()  { echo "[ERR] $*"; exit 1; }

[[ $EUID -ne 0 ]] && err "Ce script doit être exécuté en root."

# ─── IP STATIQUE ─────────────────────────────────────────────────────────────
log "Configuration IP statique $BACKUP_IP..."
cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    ${INTERFACE}:
      addresses:
        - ${BACKUP_IP}/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [192.168.10.10]
        search: [pme.local]
EOF
netplan apply
ok "IP statique configurée."

# ─── PAQUETS ─────────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y -qq rsync openssh-server ufw fail2ban
ok "Paquets installés."

# ─── UTILISATEUR DE SAUVEGARDE ───────────────────────────────────────────────
log "Création du compte $BACKUP_USER..."
if ! id "$BACKUP_USER" &>/dev/null; then
    useradd -r -m -s /bin/bash "$BACKUP_USER"
    ok "Compte $BACKUP_USER créé."
fi

mkdir -p "${BACKUP_DIR}/samba01"
chown -R "${BACKUP_USER}:${BACKUP_USER}" "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# ─── CLÉS SSH ────────────────────────────────────────────────────────────────
log "Génération de la paire de clés SSH pour SAMBA01 → BACKUP01..."
SSH_DIR="/root/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Générer la clé sur SAMBA01 (à copier manuellement depuis SAMBA01)
# Sur SAMBA01 : ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519_backup -N ""
# Puis : ssh-copy-id -i /root/.ssh/id_ed25519_backup.pub backupuser@192.168.10.30

# Préparer authorized_keys sur BACKUP01
AUTHKEYS="/home/${BACKUP_USER}/.ssh/authorized_keys"
mkdir -p "/home/${BACKUP_USER}/.ssh"
touch "$AUTHKEYS"
chown -R "${BACKUP_USER}:${BACKUP_USER}" "/home/${BACKUP_USER}/.ssh"
chmod 700 "/home/${BACKUP_USER}/.ssh"
chmod 600 "$AUTHKEYS"

ok "Dossier SSH préparé. Copiez la clé publique depuis SAMBA01 dans :"
ok "  $AUTHKEYS"

# ─── SSH DURCI ───────────────────────────────────────────────────────────────
log "Durcissement SSH..."
cat >> /etc/ssh/sshd_config <<'SSHEOF'

# PME hardening
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers backupuser
MaxAuthTries 3
SSHEOF
systemctl restart sshd
ok "SSH durci (clé uniquement, root interdit)."

# ─── PARE-FEU ────────────────────────────────────────────────────────────────
log "Configuration ufw..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$SAMBA_IP" to any port 22 proto tcp comment "SSH depuis SAMBA01"
ufw allow from 192.168.10.0/24 to any port 22 proto tcp comment "SSH admin interne"
ufw --force enable
ok "Pare-feu configuré."

# ─── FAIL2BAN ────────────────────────────────────────────────────────────────
log "Configuration fail2ban..."
cat > /etc/fail2ban/jail.local <<'F2BEOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
F2BEOF
systemctl enable --now fail2ban
ok "fail2ban actif."

# ─── CRON MONITORING ─────────────────────────────────────────────────────────
log "Ajout d'un cron de monitoring sauvegarde..."
cat > /etc/cron.d/backup-check <<'CRONEOF'
# Alerte si aucune sauvegarde depuis 25h
0 6 * * * root test $(find /backups/samba01 -maxdepth 1 -type d -name "20*" -mtime -1 | wc -l) -gt 0 || echo "ALERTE: Aucune sauvegarde depuis 25h" | mail -s "Backup PME - ECHEC" admin@pme.local
CRONEOF
ok "Cron de monitoring installé."

ok ""
ok "=== BACKUP01 prêt ==="
ok "Prochaine étape : copier la clé publique SSH depuis SAMBA01"
