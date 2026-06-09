# Plan d'adressage IP — Mini-DSI pour PME

## Informations générales

| Paramètre       | Valeur              |
|-----------------|---------------------|
| Réseau          | 192.168.10.0/24     |
| Masque          | 255.255.255.0       |
| Passerelle      | 192.168.10.1        |
| DNS primaire    | 192.168.10.10       |
| Domaine AD      | pme.local           |

---

## Tableau des hôtes

| Hôte        | Rôle                          | OS                    | IP               | VLAN / Réseau     |
|-------------|-------------------------------|-----------------------|------------------|-------------------|
| DC01        | Contrôleur de domaine AD, DNS, DHCP | Windows Server 2022   | 192.168.10.10/24 | LAN-SERV          |
| SAMBA01     | Serveur de fichiers Samba     | Ubuntu Server 22.04   | 192.168.10.20/24 | LAN-SERV          |
| BACKUP01    | Serveur de sauvegarde (rsync) | Ubuntu Server 22.04   | 192.168.10.30/24 | LAN-SERV          |
| CLIENT-01   | Poste client Windows 10       | Windows 10 Pro        | DHCP (100–150)   | LAN-CLIENT        |

---

## Plages DHCP (gérées par DC01)

| Paramètre         | Valeur                    |
|-------------------|---------------------------|
| Plage             | 192.168.10.100 – 192.168.10.150 |
| Masque            | 255.255.255.0             |
| Passerelle        | 192.168.10.1              |
| DNS               | 192.168.10.10             |
| Durée du bail     | 8 heures                  |
| Exclusions        | 192.168.10.1 – 192.168.10.99 |

---

## Réseau virtuel VirtualBox / VMware

| Réseau virtuel | Type          | Sous-réseau          | Utilisé par                    |
|----------------|---------------|----------------------|--------------------------------|
| VMnet LAN      | Internal/NAT  | 192.168.10.0/24      | DC01, SAMBA01, BACKUP01, CLIENT|
| VMnet WAN      | NAT           | 10.0.2.0/24          | DC01 (accès Internet installer) |

---

## Ports et services ouverts par VM

### DC01 (Windows Server 2022)
| Port   | Protocole | Service          |
|--------|-----------|------------------|
| 53     | TCP/UDP   | DNS              |
| 67/68  | UDP       | DHCP             |
| 88     | TCP/UDP   | Kerberos (AD)    |
| 135    | TCP       | RPC              |
| 389    | TCP/UDP   | LDAP             |
| 445    | TCP       | SMB (AD sysvol)  |
| 3268   | TCP       | Global Catalog   |
| 3389   | TCP       | RDP (admin uniquement) |

### SAMBA01 (Ubuntu Server 22.04)
| Port   | Protocole | Service          |
|--------|-----------|------------------|
| 22     | TCP       | SSH (clé uniquement) |
| 139    | TCP       | NetBIOS          |
| 445    | TCP       | SMB/Samba        |

### BACKUP01 (Ubuntu Server 22.04)
| Port   | Protocole | Service          |
|--------|-----------|------------------|
| 22     | TCP       | SSH (clé uniquement) |
| 873    | TCP       | rsync (interne)  |

---

## Schéma simplifié

```
Internet
    |
[Passerelle 192.168.10.1]
    |
[Switch virtuel — 192.168.10.0/24]
    |          |           |          |
[DC01]    [SAMBA01]  [BACKUP01]  [CLIENT-WIN]
.10         .20         .30       DHCP
```
