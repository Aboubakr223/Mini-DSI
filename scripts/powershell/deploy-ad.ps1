#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Déploiement Active Directory - Mini DSI PME

.DESCRIPTION
    Installe Active Directory Domain Services, DNS et DHCP,
    crée le domaine pme.local et configure les services réseau.


#>


# ============================================================================
# VARIABLES
# ============================================================================

$DomainName    = "pme.local"
$DomainNetBIOS = "PME"

$ServerIP      = "192.168.10.10"
$SubnetMask    = "255.255.255.0"
$Gateway       = "192.168.10.1"

$SafeModePwd = ConvertTo-SecureString `
    "P@ssw0rd!DC2024" `
    -AsPlainText `
    -Force

# ============================================================================
# ÉTAPE 1 : CONFIGURATION IP STATIQUE
# ============================================================================

Write-Host "[1/5] Configuration de l'adresse IP statique..." `
    -ForegroundColor Cyan

$Adapter = Get-NetAdapter |
    Where-Object { $_.Status -eq "Up" } |
    Select-Object -First 1

New-NetIPAddress `
    -InterfaceIndex $Adapter.ifIndex `
    -IPAddress $ServerIP `
    -PrefixLength 24 `
    -DefaultGateway $Gateway `
    -ErrorAction SilentlyContinue

Set-DnsClientServerAddress `
    -InterfaceIndex $Adapter.ifIndex `
    -ServerAddresses @(
        "127.0.0.1",
        "192.168.10.1"
    )

Write-Host "IP statique configurée : $ServerIP" `
    -ForegroundColor Green

# ============================================================================
# ÉTAPE 2 : INSTALLATION DES RÔLES
# ============================================================================

Write-Host "[2/5] Installation des rôles Windows..." `
    -ForegroundColor Cyan

Install-WindowsFeature `
    -Name AD-Domain-Services, DNS, DHCP `
    -IncludeManagementTools `
    -Restart:$false |
    Out-Null

Write-Host "Rôles installés." `
    -ForegroundColor Green

# ============================================================================
# ÉTAPE 3 : PROMOTION EN CONTRÔLEUR DE DOMAINE
# ============================================================================

Write-Host "[3/5] Promotion en contrôleur de domaine..." `
    -ForegroundColor Cyan

Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $DomainNetBIOS `
    -DomainMode "WinThreshold" `
    -ForestMode "WinThreshold" `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePwd `
    -InstallDns:$true `
    -NoRebootOnCompletion:$false `
    -Force:$true

# ============================================================================
# ÉTAPE 4 : CONFIGURATION DHCP (APRÈS REDÉMARRAGE)
# ============================================================================

function Configure-DHCP {

    Write-Host "[4/5] Configuration du DHCP..." `
        -ForegroundColor Cyan

    Add-DhcpServerInDC `
        -DnsName "DC01.$DomainName" `
        -IPAddress $ServerIP

    Add-DhcpServerv4Scope `
        -Name "LAN-PME" `
        -StartRange "192.168.10.100" `
        -EndRange "192.168.10.150" `
        -SubnetMask $SubnetMask `
        -State Active

    Set-DhcpServerv4Scope `
        -ScopeId "192.168.10.0" `
        -LeaseDuration "08:00:00"

    Set-DhcpServerv4OptionValue `
        -ScopeId "192.168.10.0" `
        -Router $Gateway `
        -DnsServer $ServerIP `
        -DnsDomain $DomainName

    Add-DhcpServerv4ExclusionRange `
        -ScopeId "192.168.10.0" `
        -StartRange "192.168.10.1" `
        -EndRange "192.168.10.99"

    Set-Service DHCPServer -StartupType Automatic
    Restart-Service DHCPServer

    Write-Host "DHCP configuré : 192.168.10.100 - 192.168.10.150" `
        -ForegroundColor Green
}

# ============================================================================
# ÉTAPE 5 : TÂCHE PLANIFIÉE + REDÉMARRAGE
# ============================================================================

$Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"& { . '$PSCommandPath'; Configure-DHCP }`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask `
    -TaskName "PME-ConfigureDHCP" `
    -Action $Action `
    -Trigger $Trigger `
    -RunLevel Highest `
    -Force |
    Out-Null

Write-Host "[5/5] Redémarrage dans 10 secondes..." `
    -ForegroundColor Yellow

Start-Sleep 10

Restart-Computer -Force
