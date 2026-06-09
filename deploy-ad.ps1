# renommer le serveur après démarrage de la VM 

```
Rename-Computer -NewName DC01 -Restart
```

# Configuration d'adressage IP

```
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.10.10 -PrefixLength 24 -DefaultGateway 192.168.10.1
```
