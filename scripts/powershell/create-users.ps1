#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Création automatique des utilisateurs Active Directory.

.DESCRIPTION
    Crée :
        - 3 unités organisationnelles (OU)
        - 15 utilisateurs
        - 3 groupes de sécurité

#>

Import-Module ActiveDirectory

Set-StrictMode -Version Latest

# ============================================================================
# VARIABLES
# ============================================================================

$Domain      = "pme.local"
$DomainDN    = "DC=pme,DC=local"

$DefaultPwd = ConvertTo-SecureString `
    "Pme@2024!" `
    -AsPlainText `
    -Force

# ============================================================================
# CRÉATION DES UNITÉS ORGANISATIONNELLES
# ============================================================================

$OUs = @(
    @{ Name = "Direction";  DN = "OU=Direction,$DomainDN"  }
    @{ Name = "Tech";       DN = "OU=Tech,$DomainDN"       }
    @{ Name = "Commercial"; DN = "OU=Commercial,$DomainDN" }
)

foreach ($OU in $OUs) {

    if (-not (
        Get-ADOrganizationalUnit `
            -Filter "DistinguishedName -eq '$($OU.DN)'" `
            -ErrorAction SilentlyContinue
    )) {

        New-ADOrganizationalUnit `
            -Name $OU.Name `
            -Path $DomainDN `
            -ProtectedFromAccidentalDeletion $false

        Write-Host "OU créée : $($OU.Name)" `
            -ForegroundColor Green
    }
    else {
        Write-Host "OU déjà existante : $($OU.Name)" `
            -ForegroundColor Yellow
    }
}

# ============================================================================
# DÉFINITION DES UTILISATEURS
# ============================================================================

$Users = @(

    # Direction
    @{ SamAccount="dir01"; GivenName="Alice";    Surname="Martin";   OU="OU=Direction,$DomainDN";  Title="Directrice Générale" }
    @{ SamAccount="dir02"; GivenName="Bernard";  Surname="Dupont";   OU="OU=Direction,$DomainDN";  Title="Directeur Financier" }
    @{ SamAccount="dir03"; GivenName="Claire";   Surname="Leblanc";  OU="OU=Direction,$DomainDN";  Title="DRH" }
    @{ SamAccount="dir04"; GivenName="David";    Surname="Rousseau"; OU="OU=Direction,$DomainDN";  Title="Directeur Commercial" }
    @{ SamAccount="dir05"; GivenName="Emma";     Surname="Bernard";  OU="OU=Direction,$DomainDN";  Title="Assistante de Direction" }

    # Technique
    @{ SamAccount="tech01"; GivenName="François";  Surname="Garnier"; OU="OU=Tech,$DomainDN"; Title="Administrateur Système" }
    @{ SamAccount="tech02"; GivenName="Gabrielle"; Surname="Simon";   OU="OU=Tech,$DomainDN"; Title="Développeur Backend" }
    @{ SamAccount="tech03"; GivenName="Hugo";      Surname="Michel";  OU="OU=Tech,$DomainDN"; Title="Développeur Frontend" }
    @{ SamAccount="tech04"; GivenName="Inès";      Surname="Laurent"; OU="OU=Tech,$DomainDN"; Title="DevOps" }
    @{ SamAccount="tech05"; GivenName="Julien";    Surname="Thomas";  OU="OU=Tech,$DomainDN"; Title="Ingénieur Réseau" }

    # Commercial
    @{ SamAccount="com01"; GivenName="Karine";  Surname="Petit";  OU="OU=Commercial,$DomainDN"; Title="Commercial Senior" }
    @{ SamAccount="com02"; GivenName="Louis";   Surname="Durand"; OU="OU=Commercial,$DomainDN"; Title="Commercial Junior" }
    @{ SamAccount="com03"; GivenName="Marie";   Surname="Moreau"; OU="OU=Commercial,$DomainDN"; Title="Chargée de Clientèle" }
    @{ SamAccount="com04"; GivenName="Nicolas"; Surname="Leroy";  OU="OU=Commercial,$DomainDN"; Title="Technico-Commercial" }
    @{ SamAccount="com05"; GivenName="Olivia";  Surname="Roux";   OU="OU=Commercial,$DomainDN"; Title="Responsable Grands Comptes" }
)

# ============================================================================
# CRÉATION DES UTILISATEURS
# ============================================================================

$Created = 0
$Skipped = 0

foreach ($User in $Users) {

    $UPN = "$($User.SamAccount)@$Domain"

    if (
        Get-ADUser `
            -Filter "SamAccountName -eq '$($User.SamAccount)'" `
            -ErrorAction SilentlyContinue
    ) {
        Write-Host "Existe déjà : $($User.SamAccount)" `
            -ForegroundColor Yellow

        $Skipped++
        continue
    }

    New-ADUser `
        -SamAccountName $User.SamAccount `
        -UserPrincipalName $UPN `
        -GivenName $User.GivenName `
        -Surname $User.Surname `
        -Name "$($User.GivenName) $($User.Surname)" `
        -DisplayName "$($User.GivenName) $($User.Surname)" `
        -Title $User.Title `
        -Path $User.OU `
        -AccountPassword $DefaultPwd `
        -Enabled $true `
        -PasswordNeverExpires $false `
        -ChangePasswordAtLogon $true

    Write-Host `
        "Créé : $($User.SamAccount) - $($User.GivenName) $($User.Surname) ($($User.Title))" `
        -ForegroundColor Green

    $Created++
}

# ============================================================================
# RÉSUMÉ
# ============================================================================

Write-Host "`n=== RÉSUMÉ ===" -ForegroundColor Cyan
Write-Host "Utilisateurs créés : $Created" -ForegroundColor Green
Write-Host "Déjà existants     : $Skipped" -ForegroundColor Yellow
Write-Host "Total attendu      : 15"

# ============================================================================
# GROUPES DE SÉCURITÉ
# ============================================================================

$Groups = @(
    "GRP-Direction"
    "GRP-Tech"
    "GRP-Commercial"
)

foreach ($Group in $Groups) {

    if (-not (
        Get-ADGroup `
            -Filter "Name -eq '$Group'" `
            -ErrorAction SilentlyContinue
    )) {

        New-ADGroup `
            -Name $Group `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $DomainDN

        Write-Host "Groupe créé : $Group" `
            -ForegroundColor Green
    }
}

# ============================================================================
# AJOUT DES MEMBRES
# ============================================================================

$Mapping = @{
    "GRP-Direction"  = $Users | Where-Object { $_.OU -like "*Direction*" }  | ForEach-Object { $_.SamAccount }
    "GRP-Tech"       = $Users | Where-Object { $_.OU -like "*Tech*" }       | ForEach-Object { $_.SamAccount }
    "GRP-Commercial" = $Users | Where-Object { $_.OU -like "*Commercial*" } | ForEach-Object { $_.SamAccount }
}

foreach ($Group in $Mapping.Keys) {

    Add-ADGroupMember `
        -Identity $Group `
        -Members $Mapping[$Group] `
        -ErrorAction SilentlyContinue

    Write-Host "Membres ajoutés : $Group" `
        -ForegroundColor Green
}

Write-Host `
    "`nTerminé. Vérification : Get-ADUser -Filter * | Select Name, Title" `
    -ForegroundColor Cyan
