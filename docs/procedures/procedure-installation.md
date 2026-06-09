# Procédure d'installation — Mini-DSI pour PME

> Procédure reproductible de A à Z. Un technicien tiers doit pouvoir redéployer l'infrastructure complète en suivant ces étapes.

---

## Prérequis matériel / logiciel

| Logiciel         | Version          | Téléchargement                              |
|------------------|------------------|---------------------------------------------|
| VirtualBox       | 7.0+             | virtualbox.org                              |
| Ubuntu Server    | 22.04.4 LTS      | ubuntu.com/download/server                  |
| Windows Server   | 2022 Eval        | microsoft.com/evalcenter                    |
| Windows 10       | 22H2             | microsoft.com/evalcenter                    |

**RAM minimum hôte :** 8 Go (16 Go recommandé)  
**Disque hôte :** 80 Go libres minimum

---

## Étape 0 — Réseau virtuel VirtualBox

1. Ouvrir **Fichier > Gestionnaire de réseau hôte**
2. Créer un réseau interne nommé `LAN-PME` :
   - Type : **Réseau interne**
   - Adresse : `192.168.10.0/24` (pas de serveur DHCP VirtualBox — DC01 gère le DHCP)

---

## Étape 1 — DC01 (Windows Server 2022)

### 1.1 Création de la VM

| Paramètre | Valeur            |
|-----------|-------------------|
| Nom       | DC01              |
| OS        | Windows 2022 (64) |
| RAM       | 2048 Mo           |
| CPU       | 2                 |
| Disque    | 60 Go             |
| Réseau    | Réseau interne `LAN-PME` |

### 1.2 Installation Windows Server
1. Démarrer sur l'ISO Windows Server 2022
2. Choisir **Windows Server 2022 Standard (expérience bureau)**
3. Partitionnement standard (tout l'espace)
4. Définir le mot de passe Administrateur : `P@ssw0rd!DC2024`
5. Renommer le serveur en **DC01** (Panneau de configuration > Système)

### 1.3 Déploiement automatisé
```powershell
# Exécuter en tant qu'Administrateur :
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\powershell\deploy-ad.ps1
```
> Le serveur redémarre automatiquement à la fin pour promouvoir le DC.

### 1.4 Création des utilisateurs
```powershell
# Après redémarrage :
.\scripts\powershell\create-users.ps1
```

### 1.5 Vérification
```powershell
Get-ADDomain
Get-ADUser -Filter * | Select-Object Name, Title | Format-Table
Get-DhcpServerv4Scope
Resolve-DnsName samba01.pme.local
```

---

## Étape 2 — SAMBA01 (Ubuntu Server 22.04)

### 2.1 Création de la VM

| Paramètre | Valeur            |
|-----------|-------------------|
| Nom       | SAMBA01           |
| OS        | Ubuntu 64-bit     |
| RAM       | 1024 Mo           |
| CPU       | 1                 |
| Disque    | 20 Go             |
| Réseau    | Réseau interne `LAN-PME` |

### 2.2 Installation Ubuntu Server
1. Démarrer sur l'ISO Ubuntu Server 22.04
2. Langue : Français, Clavier : fr
3. Nom de la machine : `samba01`
4. Utilisateur : `mustapha` / mot de passe sécurisé
5. **Cocher** OpenSSH Server
6. Pas de snaps supplémentaires
7. Redémarrer

### 2.3 Déploiement automatisé
```bash
sudo chmod +x ./scripts/bash/deploy-linux.sh
sudo ./scripts/bash/deploy-linux.sh
```
> Le script demande le mot de passe Administrateur AD pour la jonction au domaine.

### 2.4 Copier la configuration Samba
```bash
sudo cp ./configs/samba/smb.conf /etc/samba/smb.conf
sudo systemctl restart smbd nmbd
```

### 2.5 Vérification
```bash
wbinfo -u                    # Lister les utilisateurs AD
wbinfo -g                    # Lister les groupes AD
smbclient -L //localhost -N  # Lister les partages
testparm -s                  # Valider smb.conf
```

---

## Étape 3 — BACKUP01 (Ubuntu Server 22.04)

### 3.1 Création de la VM

| Paramètre | Valeur            |
|-----------|-------------------|
| Nom       | BACKUP01          |
| OS        | Ubuntu 64-bit     |
| RAM       | 1024 Mo           |
| CPU       | 1                 |
| Disque    | 40 Go             |
| Réseau    | Réseau interne `LAN-PME` |

### 3.2 Installation et configuration
```bash
sudo chmod +x ./scripts/bash/setup-backup-server.sh
sudo ./scripts/bash/setup-backup-server.sh
```

### 3.3 Échange de clés SSH (depuis SAMBA01)
```bash
# Sur SAMBA01 :
sudo ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519_backup -N ""
sudo ssh-copy-id -i /root/.ssh/id_ed25519_backup.pub backupuser@192.168.10.30

# Test :
sudo ssh -i /root/.ssh/id_ed25519_backup backupuser@192.168.10.30 "echo connexion OK"
```

### 3.4 Activation du cron de sauvegarde (sur SAMBA01)
```bash
sudo crontab -e
# Ajouter :
# 0 2 * * * /opt/pme/backup.sh >> /var/log/pme-backup.log 2>&1
```

---

## Étape 4 — CLIENT-WIN (Windows 10)

### 4.1 Création de la VM

| Paramètre | Valeur           |
|-----------|------------------|
| Nom       | CLIENT-WIN       |
| OS        | Windows 10 64-bit|
| RAM       | 2048 Mo          |
| Réseau    | Réseau interne `LAN-PME` |

### 4.2 Jointure au domaine
1. Démarrer sur ISO Windows 10
2. Configurer IP en DHCP (DC01 fournit l'IP automatiquement)
3. **Système > Modifier les paramètres > Modifier > Domaine** : `pme.local`
4. Credentials : `PME\Administrator` + mot de passe DC
5. Redémarrer
6. Se connecter avec `PME\dir01` (ou tout autre utilisateur créé)

### 4.3 Vérification des partages
```
Win+R > \\samba01\direction
Win+R > \\samba01\tech
Win+R > \\samba01\commercial
```

---

## Validation finale

```bash
# Depuis n'importe quel poste Linux :
ping -c 4 192.168.10.10  # DC01
ping -c 4 192.168.10.20  # SAMBA01
ping -c 4 192.168.10.30  # BACKUP01

nslookup pme.local 192.168.10.10
nslookup samba01.pme.local 192.168.10.10
```

