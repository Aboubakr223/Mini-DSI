# GPO — Politiques de sécurité Active Directory

## GPO 1 : Default Domain Policy (modifiée)

| Paramètre                          | Valeur                        |
|------------------------------------|-------------------------------|
| Longueur minimale du mot de passe  | 10 caractères                 |
| Complexité                         | Activée                       |
| Durée max du mot de passe          | 90 jours                      |
| Historique des mots de passe       | 5 anciens mots de passe        |
| Seuil de verrouillage du compte    | 5 tentatives                  |
| Durée de verrouillage              | 30 minutes                    |

**Commandes PowerShell pour appliquer :**
```powershell
Set-ADDefaultDomainPasswordPolicy -Identity pme.local `
    -MinPasswordLength 10 `
    -ComplexityEnabled $true `
    -MaxPasswordAge "90.00:00:00" `
    -PasswordHistoryCount 5 `
    -LockoutThreshold 5 `
    -LockoutDuration "00:30:00" `
    -LockoutObservationWindow "00:10:00"
```

---

## GPO 2 : PME-Securite-Postes

Appliquée à : **OU=Computers** (postes clients)

### Verrouillage de session
| Paramètre                              | Valeur    |
|----------------------------------------|-----------|
| Délai avant verrouillage écran         | 10 min    |
| Exiger CTRL+ALT+SUPPR                  | Oui       |

**Chemin :** `Computer Config > Windows Settings > Security Settings > Local Policies > Security Options`

### Fond d'écran entreprise
| Paramètre                              | Valeur                        |
|----------------------------------------|-------------------------------|
| Fond d'écran                           | \\DC01\NETLOGON\wallpaper.jpg |
| Style                                  | Stretch                       |

**Chemin :** `User Config > Admin Templates > Desktop > Desktop > Desktop Wallpaper`

### Désactivation des ports USB (optionnel)
```
Computer Config > Admin Templates > System > Removable Storage Access
  > All Removable Storage classes: Deny all access = Enabled
```

---

## GPO 3 : PME-Mappage-Lecteurs

Appliquée par OU via **Group Policy Preferences** (User Config > Preferences > Windows Settings > Drive Maps)

| OU          | Lecteur | Chemin UNC              |
|-------------|---------|-------------------------|
| Direction   | D:      | \\SAMBA01\direction     |
| Tech        | T:      | \\SAMBA01\tech          |
| Commercial  | C:      | \\SAMBA01\commercial    |
| Tous        | Z:      | \\SAMBA01\commun        |

---

## Commandes de vérification GPO

```powershell
# Lister toutes les GPO
Get-GPO -All | Select-Object DisplayName, GpoStatus

# Forcer l'application côté client
gpupdate /force

# Rapport HTML
Get-GPOReport -All -ReportType HTML -Path "C:\GPO-Report.html"

# Vérifier la réplication SYSVOL
repadmin /showrepl
```
