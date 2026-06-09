# Procédure de restauration de la Mini-DSI pour PME

> Objectif : restaurer une VM critique en *moins de 15 minutes*.

---

## Architecture de sauvegarde

```
[SAMBA01 192.168.10.20]
  /srv/shares/direction
  /srv/shares/tech
  /srv/shares/commercial
  /etc/samba/smb.conf
  /etc/krb5.conf
         |
    rsync (SSH, chaque nuit Ã  02h00)
         |
         v
[BACKUP01  192.168.10.30]
  /backups/samba01/
    2026-01-15_02-00-01/      sauvegarde incrémentale (hard links)
    2026-01-16_02-00-01/
    latest -> 2026-01-16_02-00-01   lien symbolique vers la dernière sauvegarde
```

---

## Scénario 1 : Restauration d'un fichier unique

**Durée estimée : < 2 minutes**

```bash
# Sur BACKUP01, identifier la sauvegarde voulue
ls /backups/samba01/

# Exemple : restaurer un fichier supprimÃ© accidentellement
scp backupuser@192.168.10.30:/backups/samba01/latest/srv/shares/direction/rapport.docx \
    /srv/shares/direction/rapport.docx

# Vérifier les permissions
chown root:"PME+GRP-Direction" /srv/shares/direction/rapport.docx
chmod 660 /srv/shares/direction/rapport.docx
```

---

## Scénario 2 : Restauration complète de SAMBA01

**Durée estimée : 10 â15 minutes**

### étape 1 : Reconstruire la VM (5 min)

```bash
# Depuis VirtualBox : crÃ©er une nouvelle VM SAMBA01 avec les mÃªmes specs
# Installer Ubuntu Server 22.04 rapidement (voir procedure-installation.md)
# Configurer l'IP statique 192.168.10.20 immÃ©diatement
```

### étape 2 : Installer les paquets minimum (2 min)

```bash
sudo apt-get update -qq
sudo apt-get install -y rsync openssh-server
```

### étape 3 :  Récupérer les données depuis BACKUP01 (3 min)

```bash
# Depuis BACKUP01 vers la nouvelle SAMBA01 :
sudo rsync -avz --delete \
    /backups/samba01/latest/srv/shares/ \
    root@192.168.10.20:/srv/shares/

sudo rsync -avz \
    /backups/samba01/latest/etc/samba/smb.conf \
    root@192.168.10.20:/etc/samba/smb.conf

sudo rsync -avz \
    /backups/samba01/latest/etc/krb5.conf \
    root@192.168.10.20:/etc/krb5.conf
```

### étape 4 : Rejoindre le domaine et relancer les services (3 min)

```bash
# Sur la nouvelle SAMBA01 :
sudo apt-get install -y samba winbind realmd adcli krb5-user

sudo realm join --user=Administrator PME.LOCAL

sudo systemctl enable --now smbd nmbd winbind

# Vérification
wbinfo -u
smbclient -L //localhost -N
```

### étape 5 : Chronomètre (à  noter)

```
Début restauration : _______h_______
Fin restauration   : _______h________
Durée totale       : _______ minutes
Résultat           : [ ] OK  [ ] KO
```

---

## Scénario 3 : Perte du DC01 (Active Directory)

**Durée estimée : 20 minutes (à  préparer comme plan B)**

> Idéalement, un snapshot VirtualBox de DC01 après configuration complète
> permet de restaurer en < 5 minutes.

```bash
# Snapshot VirtualBox avant chaque journée :
VBoxManage snapshot "DC01" take "J2-AD-configure" --description "Après déploiement AD"
VBoxManage snapshot "DC01" take "J3-GPO-configure" --description "Après GPO"
VBoxManage snapshot "DC01" take "J4-DHCP-final"   --description "Final J4"

# Restauration depuis snapshot :
VBoxManage snapshot "DC01" restore "J4-DHCP-final"
VBoxManage startvm "DC01"
```

---

## Vérification post-restauration

```bash
# Test 1 : Résolution DNS
nslookup pme.local 192.168.10.10

# Test 2 : Partages accessibles
smbclient -U "PME\tech01%Pme@2026!" //samba01/tech -c "ls"

# Test 3 : Jonction domaine
realm list

# Test 4 : Ping inter-VMs
ping -c 4 192.168.10.10
ping -c 4 192.168.10.20
ping -c 4 192.168.10.30
```

---

## Log de la restauration

| Champ              | Valeur |
|--------------------|--------|
| Date               |        |
| Heure dÃ©but       |        |
| Heure fin          |        |
| Durée              |        |
| Responsable        | Ayman  |
| Scénario test      |        |
| RÃ©sultat          | OK / KO|
| Observations       |        |


