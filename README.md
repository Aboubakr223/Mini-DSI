# Mini-DSI pour PME — Projet 1PRJ2

**Module :** 1PRJ2 — Projet d'Intégration Infrastructure & Sécurité  
**Niveau :** Bachelor 1 — Unité 3  
**Durée :** 5 jours / 35 heures  
**Équipe :**

| Personne    | Rôle                              |
|-------------|-----------------------------------|
| aboubakr    | Windows / Active Directory        |
| mustapha    | Linux / Réseau / Samba            |
| ayman       | Backup / Documentation / Git      |

---

## Contexte

Une PME de 30 personnes nous confie le déploiement de son socle IT. Mission : fournir un environnement de travail complet, sécurisé et documenté.

---

## Architecture

```
Internet
    |
[192.168.10.1 — Passerelle]
    |
[Switch virtuel LAN-PME — 192.168.10.0/24]
    |             |              |              |
[DC01]       [FILE01]      [BACKUP01]    [CLIENT-WIN]
192.168.10.10  192.168.10.20  192.168.10.30  DHCP .100-.150
Win Srv 2022   Ubuntu 22.04   Ubuntu 22.04   Windows 10
AD/DNS/DHCP    Samba          rsync/cron
```

**Domaine AD :** `pme.local`

---

## Structure du dépôt

```
Mini-DSI/
├── README.md 
├── docs/ 
│   ├── plan-ip.md                  ← plan d'adressage IP complet
│   ├── procedure-installation.md  ← installation reproductible de A à Z
│   ├── procedure-restauration.md  ← restauration testée (< 15 min)
│   └── audit-nmap.md               ← rapport d'audit sécurité + remédiations
├── scripts/
│   ├── bash/
│   │   ├── deploy-linux.sh         ← déploiement SAMBA01 (intégration domaine)
│   │   ├── setup-backup-server.sh ← initialisation BACKUP01
│   │   └── backup.sh               ← sauvegarde rsync incrémentale (cron 02h)
│   └── powershell/
│       ├── deploy-ad.ps1           ← déploiement AD DS + DNS + DHCP sur DC01
│       └── create-users.ps1        ← création 15 utilisateurs + 3 OU + groupes
├── configs/
│   ├── samba/
│   │   └── smb.conf                ← configuration Samba avec ACL AD
│   └── gpo/
│       └── gpo-description.md      ← politiques GPO documentées

---

## Démarrage rapide

### 1. DC01 — Active Directory
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\powershell\deploy-ad.ps1     # Installe AD + redémarre
# Après redémarrage :
.\scripts\powershell\create-users.ps1  # Crée les 15 utilisateurs
```

### 2. FILE01 — Serveur de fichiers
```bash
sudo ./scripts/bash/deploy-linux.sh
```

### 3. BACKUP01 — Serveur de sauvegarde
```bash
sudo ./scripts/bash/setup-backup-server.sh
# Puis configurer l'échange de clés SSH depuis SAMBA01
```

### 4. Sauvegarde automatique (cron sur SAMBA01)
```bash
sudo crontab -e
# 0 2 * * * /opt/pme/backup.sh >> /var/log/pme-backup.log 2>&1
```

---

## Livrables

| Livrable                        | Responsable | Statut |
|---------------------------------|-------------|--------|
| Schéma d'architecture           | Aboubakr    | ✅  |
| Plan d'adressage IP             | Aboubakr    | ✅  |
| Script PowerShell AD            | Aboubakr    | ✅  |
| Script PowerShell create-users  | Aboubakr    | ✅  |
| Script Bash deploy-linux        | Mustapha    | ✅  |
| smb.conf                        | Mustapha    | ✅  |
| Script rsync backup             | Mustapha    | ✅  |
| Procédure d'installation        | Ayman       | ✅  |                    
| procédure de restauration       | Ayman       | ✅  |
| Audit Nmap                      | tous        | ✅  |         
| Dépôt Git                       | tous        | ✅  |
| Slides soutenance               | tous        | ✅  |

---

## Critères pédagogiques

- Toutes les VMs démarrent et se pinguent selon le plan IP
- CLIENT-01 rejoint le domaine et reçoit une IP par DHCP
- Les partages Samba sont accessibles par le bon groupe AD
- La restauration est démontrée en < 15 minutes 
- Le rapport Nmap contient un plan de remédiation appliqué
- 15+ commits Git répartis sur 5 jours, par auteur identifiable

---

## Commandes de vérification rapide

```bash
# Connectivité
ping 192.168.10.10 && ping 192.168.10.20 && ping 192.168.10.30

# DNS
nslookup pme.local 192.168.10.10
nslookup samba01.pme.local 192.168.10.10

# Samba depuis Linux
smbclient -U "PME\tech01%Pme@2024!" //192.168.10.20/tech -c "ls"

# AD
Get-ADUser -Filter * | Measure-Object  # doit retourner 15+
Get-ADOrganizationalUnit -Filter *     # doit montrer Direction, Tech, Commercial
```
