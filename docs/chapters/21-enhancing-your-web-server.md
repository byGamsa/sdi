# 21. Enhancing your web server.
Diese Aufgabe baut auf der vorherigen Aufgabe 20 auf.

- Zuerst muss der Key aus dem gegebenen File in Moodle geholt werden
- Anschließend muss Variable exportiert werden und es kann geschaut werden, ob die Subdomain existiert und aktiv ist
```bash
# Export your HMAC key as an environment variable
export HMAC="hmac-sha512:g1.key:<YOUR_SECRET_KEY>"

# Perform a full zone transfer (AXFR)
dig @ns1.hdm-stuttgart.cloud -y $HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```

In der Aufgabe geht es darum
- einen A DNS Record an unsere Server-IP anzubinden (einmal mit www., einmal ohne)
- TLS zu konfigurieren

### Anbinden eines A DNS Records an unsere Server-IP

#### Provider-Setup 
Hier wird die Verbindung zum Nameserver ``ns1.sdi.hdm-stuttgart.cloud`` in der ``main.tf`` konfiguriert. Zur Authentifizierung wird der TSIG-Key (``g1.key``) und das zugehörige Secret verwendet, um Schreibrechte auf der DNS-Zone zu erhalten.

::: code-group
```hcl[main.tf]
provider "dns" {  // [!code ++:8]
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "g1.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}
```
:::

#### Hauptdomain setzen
Da der Anbieter hashicorp/dns keine Root-Zone-Einträge erlaubt, brauchen wir hierfür einen manuellen Ansatz. Der Block ``triggers`` überwacht die Server-IP. Ändert sich diese, führt Terraform das Skript erneut aus. Über den ``local-exec`` Provisioner wird das Tool ``nsupdate`` aufgerufen. Es sendet direkt Befehle an den Nameserver, um zuerst eventuell vorhandene Einträge für die Domain zu löschen und anschließend die neue IP-Adresse sauber einzutragen.
::: code-group
```hcl [main.tf]
resource "null_resource" "dns_root" { // [!code ++:15]
  triggers = {
    server_ip = hcloud_server.debian_server.ipv4_address
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete g1.sdi.hdm-stuttgart.cloud. A
      update add g1.sdi.hdm-stuttgart.cloud. 10 A ${hcloud_server.debian_server.ipv4_address}
      send" | nsupdate -y "hmac-sha512:g1.key:${var.dns_secret}"
    EOT
  }
}
```
:::
#### Setzen der Subdomain (www)
Für klassische Subdomains funktioniert der Terraform-Provider problemlos, daher wählen wir hier die native Terraform-Ressource. Diese erstellt automatisch einen A-Record in der Zone ``g1.sdi.hdm-stuttgart.cloud``, der ebenfalls auf die IP-Adresse des Debian-Servers verweist.
::: code-group
```hcl [main.tf]
resource "dns_a_record_set" "www" { // [!code ++:6]
  name = "www"
  zone = "g1.sdi.hdm-stuttgart.cloud."      
  ttl  = 10
  addresses = [hcloud_server.debian_server.ipv4_address]
}
```
:::
#### TLS Konfiguration
Zu Beginn muss die Firewall um Port 443 erweitert werden 
::: code-group
```hcl [main.tf]
resource "hcloud_firewall" "fw" {
  name = "firewall-1"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule { // [!code ++:6]
  direction = "in"
  protocol  = "tcp"
  port      = "443"
  source_ips = ["0.0.0.0/0", "::/0"]
  }
} 
```
:::

Anschließend muss auf den Server zugegriffen werden und letsecrypt muss installiert werden.
```bash
sudo apt install certbot python3-certbot-nginx
```

Sobald die Installation erfolgreich war, kann folgender Code ausgeführt werden:
```bash
sudo certbot --nginx -d g1.sdi.hdm-stuttgart.cloud -d www.g1.sdi.hdm-stuttgart.cloud
```

Sollte alles geklappt haben, sollte der Output so aussehen:
```
Deploying certificate
Successfully deployed certificate for g1.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Successfully deployed certificate for www.g1.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Congratulations! You have successfully enabled HTTPS on https://g1.sdi.hdm-stuttgart.cloud and https://www.g1.sdi.hdm-stuttgart.cloud
```

Anschließend muss noch getestet werden, ob alles erfolgreich geklappt hat. Dies kann direkt über den Browser getestet werden, oder durch folgenden Befehl im Terminal:
```bash
curl -I https://g1.sdi.hdm-stuttgart.cloud
curl -I https://www.g1.sdi.hdm-stuttgart.cloud
```