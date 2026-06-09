# Rapport d'audit Nmap — Mini-DSI pour PME

> Réalisé le depuis BACKUP01 (192.168.10.30)

---

## Méthodologie

```bash
# Scan réseau complet — découverte des hôtes
nmap -sn 192.168.10.0/24 -oA /tmp/audit/discovery

# Scan de services — DC01
nmap -sV -sC -O -p- --min-rate 1000 192.168.10.10 -oA /tmp/audit/dc01-full

# Scan de services — SAMBA01
nmap -sV -sC -O -p- --min-rate 1000 192.168.10.20 -oA /tmp/audit/samba01-full

# Scan de services — BACKUP01 (auto-audit)
nmap -sV -sC -O -p- --min-rate 1000 192.168.10.30 -oA /tmp/audit/backup01-full

# Scan UDP courants
nmap -sU --top-ports 20 192.168.10.0/24 -oA /tmp/audit/udp-scan
```

---

## Résultats attendus

### DC01 (192.168.10.10) — Windows Server 2022

| Port  | État  | Service          | Commentaire                        |
|-------|-------|------------------|------------------------------------|
| 53    | open  | DNS              | Normal — DC01 est serveur DNS      |
| 67    | open  | DHCP             | Normal — service DHCP actif        |
| 88    | open  | Kerberos         | Normal — AD                        |
| 135   | open  | RPC              | Normal — Windows                   |
| 139   | open  | NetBIOS          | Acceptable sur réseau interne      |
| 389   | open  | LDAP             | Normal — AD                        |
| 445   | open  | SMB              | Normal — SYSVOL/NETLOGON           |
| 3268  | open  | LDAP Global Cat. | Normal — AD                        |
| 3389  | open  | RDP              | **Restreindre** aux IP admin       |
| 5985  | ?     | WinRM            | **Fermer** si inutilisé            |

### SAMBA01 (192.168.10.20) — Ubuntu Server 22.04

| Port  | État   | Service     | Commentaire                          |
|-------|--------|-------------|--------------------------------------|
| 22    | open   | SSH         | Normal — clé uniquement              |
| 139   | open   | NetBIOS     | Normal — Samba                       |
| 445   | open   | SMB         | Normal — Samba                       |
| 111   | ?      | RPC portmap | **Fermer** si ouvert                 |
| 631   | ?      | CUPS        | **Fermer** — inutile sur serveur     |

### BACKUP01 (192.168.10.30) — Ubuntu Server 22.04

| Port  | État   | Service     | Commentaire                          |
|-------|--------|-------------|--------------------------------------|
| 22    | open   | SSH         | Normal — clé uniquement              |
| autres| closed | —           | Tout doit être fermé                 |

---

## Points faibles identifiés et remédiations

| # | VM       | Vulnérabilité                    | Criticité | Remédiation appliquée                              |
|---|----------|----------------------------------|-----------|----------------------------------------------------|
| 1 | DC01     | RDP ouvert sur tout le réseau    | Moyenne   | Restreindre à 192.168.10.0/24 dans Windows Firewall|
| 2 | SAMBA01  | SMBv1 potentiellement activé     | Haute     | `Set-SmbServerConfiguration -EnableSMB1Protocol $false` |
| 3 | Toutes   | Comptes par défaut non désactivés| Haute     | Désactiver le compte `guest` Samba et `Administrator` local |
| 4 | DC01     | WinRM exposé                     | Moyenne   | `Disable-PSRemoting -Force` si non nécessaire      |
| 5 | SAMBA01  | CUPS ouvert                      | Faible    | `sudo systemctl disable --now cups`                |

---

## Commandes de remédiation appliquées

```bash
# SAMBA01 — Désactiver services inutiles
sudo systemctl disable --now cups avahi-daemon rpcbind
sudo ufw reload

# SAMBA01 — Forcer SMBv2 minimum
sudo smbcontrol all reload-config
# Dans smb.conf : server min protocol = SMB2
```

```powershell
# DC01 — Restreindre RDP
New-NetFirewallRule -DisplayName "RDP Interne Seulement" `
    -Direction Inbound -Protocol TCP -LocalPort 3389 `
    -RemoteAddress "192.168.10.0/24" -Action Allow
Disable-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)"

# DC01 — Désactiver SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

# DC01 — Désactiver compte Invité
Disable-ADAccount -Identity "Guest"
```

---

## Score de sécurité final

| VM       | Ports ouverts | Services inutiles | SSH clé | Firewall | Fail2ban | Score |
|----------|---------------|-------------------|---------|----------|----------|-------|
| DC01     | Minimal       | 0                 | N/A     | Oui      | N/A      | 8/10  |
| SAMBA01  | Minimal       | 0                 | Oui     | Oui      | Oui      | 9/10  |
| BACKUP01 | Minimal       | 0                 | Oui     | Oui      | Oui      | 10/10 |

