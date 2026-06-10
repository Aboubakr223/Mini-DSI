#!/usr/bin/env bash
# backup.sh — Sauvegarde incrémentale rsync vers BACKUP01
# Tourne sur SAMBA01 (192.168.10.20) vers BACKUP01 (192.168.10.30)
# Auteur : ayman
# Cron : 0 2 * * * /opt/pme/backup.sh >> /var/log/pme-backup.log 2>&1
set -euo pipefail

# ─── VARIABLES ────────────────────────────────────────────────────────────────
BACKUP_SERVER="192.168.10.30"
BACKUP_USER="backupuser"
BACKUP_BASE="/backups/samba01"
SSH_KEY="/root/.ssh/id_ed25519_backup"
RETENTION_DAYS=7

# Sources à sauvegarder
SOURCES=(
    "/srv/shares"
    "/etc/samba/smb.conf"
    "/etc/krb5.conf"
)

LOG_FILE="/var/log/pme-backup.log"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
DEST="${BACKUP_BASE}/${DATE}"
LINK_DEST="${BACKUP_BASE}/latest"

# ─── COULEURS / LOGGING ───────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
ok()   { log "[ OK ] $*"; }
warn() { log "[WARN] $*"; }
err()  { log "[ERR ] $*"; exit 1; }

# ─── VÉRIFICATIONS PRÉ-SAUVEGARDE ────────────────────────────────────────────
log "=== Début sauvegarde $DATE ==="

[[ $EUID -ne 0 ]] && err "Doit tourner en root."
[[ -f "$SSH_KEY" ]] || err "Clé SSH absente : $SSH_KEY — voir procedure-restauration.md"

# Test connectivité
ssh -o BatchMode=yes -o ConnectTimeout=5 -i "$SSH_KEY" \
    "${BACKUP_USER}@${BACKUP_SERVER}" "echo ok" > /dev/null 2>&1 \
    || err "Impossible de joindre $BACKUP_SERVER en SSH."

ok "Connectivité BACKUP01 vérifiée."

# ─── SAUVEGARDE RSYNC ─────────────────────────────────────────────────────────
log "Lancement rsync vers ${BACKUP_SERVER}:${DEST}..."

RSYNC_OPTS=(
    --archive
    --compress
    --delete
    --delete-excluded
    --stats
    --human-readable
    --link-dest="${LINK_DEST}"
    -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=accept-new"
)

# Exclusions
EXCLUDES=(
    --exclude="*.tmp"
    --exclude="*.swp"
    --exclude=".Trash*"
)

rsync "${RSYNC_OPTS[@]}" "${EXCLUDES[@]}" \
    "${SOURCES[@]}" \
    "${BACKUP_USER}@${BACKUP_SERVER}:${DEST}/" \
    >> "$LOG_FILE" 2>&1

ok "Transfert rsync terminé."

# ─── MISE À JOUR DU LIEN 'latest' ─────────────────────────────────────────────
ssh -i "$SSH_KEY" "${BACKUP_USER}@${BACKUP_SERVER}" \
    "ln -sfn '${DEST}' '${LINK_DEST}'"
ok "Lien 'latest' mis à jour."

# ─── ROTATION DES ANCIENNES SAUVEGARDES ──────────────────────────────────────
log "Suppression des sauvegardes de plus de ${RETENTION_DAYS} jours..."

ssh -i "$SSH_KEY" "${BACKUP_USER}@${BACKUP_SERVER}" \
    "find '${BACKUP_BASE}' -maxdepth 1 -type d -name '20*' \
     -mtime +${RETENTION_DAYS} -print -exec rm -rf {} + 2>/dev/null || true"

ok "Rotation effectuée (rétention : ${RETENTION_DAYS} jours)."

# ─── RAPPORT ─────────────────────────────────────────────────────────────────
BACKUP_SIZE=$(ssh -i "$SSH_KEY" "${BACKUP_USER}@${BACKUP_SERVER}" \
    "du -sh '${DEST}' 2>/dev/null | cut -f1")

log "Taille sauvegarde : ${BACKUP_SIZE}"
log "Destination       : ${BACKUP_SERVER}:${DEST}"
log "=== Sauvegarde terminée avec succès ==="

exit 0
