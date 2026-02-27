# 21. Webserver mit DNS und TLS erweitern

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdiDnsProjectNameServer.html#_qanda)

In dieser Übung wird der bestehende Webserver um DNS-Einträge und TLS-Verschlüsselung (HTTPS) erweitert. Dabei werden A-Records erstellt, die sowohl die Hauptdomain als auch die `www`-Subdomain auf die Server-IP verweisen. Anschließend wird mit Let's Encrypt ein kostenloses TLS-Zertifikat eingerichtet, sodass der Webserver über HTTPS erreichbar ist.

## Architektur-Komponenten

| Komponente                  | Beschreibung                                                   |
| --------------------------- | -------------------------------------------------------------- |
| **DNS Provider**            | Terraform-Provider für DNS-Updates über TSIG-Authentifizierung |
| **A-Record (Root)**         | Verknüpft die Hauptdomain mit der Server-IP (über `nsupdate`)  |
| **A-Record (www)**          | Verknüpft die `www`-Subdomain mit der Server-IP                |
| **Firewall (Port 443)**     | Erlaubt eingehenden HTTPS-Verkehr                              |
| **Certbot / Let's Encrypt** | Automatische TLS-Zertifikatserstellung und Nginx-Konfiguration |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 20](/exercises/20-mounts-points-name-specification) auf.

## Übungsschritte

### 1. DNS-Zone überprüfen

Bevor wir DNS-Records erstellen, müssen wir den HMAC-Key aus dem in Moodle bereitgestellten File holen. Dieser Schlüssel authentifiziert uns gegenüber dem Nameserver und erlaubt es uns, DNS-Einträge in unserer Zone zu verwalten.

Exportiere den Schlüssel und überprüfe, ob die Zone existiert und aktiv ist:

```bash
# Export your HMAC key as an environment variable
export HMAC="g1.key:<YOUR_SECRET_KEY>"

# Perform a full zone transfer (AXFR)
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```

::: info
Ein AXFR-Request liefert alle DNS-Einträge einer Zone zurück. Das ist nützlich, um den aktuellen Stand zu überprüfen und sicherzustellen, dass keine Konflikte mit bestehenden Einträgen bestehen.
:::

### 2. DNS Provider konfigurieren

Konfiguriere den hashicorp/dns Provider in der `main.tf`. Die Verbindung zum Nameserver `ns1.sdi.hdm-stuttgart.cloud` wird über TSIG-Authentifizierung (HMAC-SHA512) hergestellt:

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

::: warning
Der `key_name` muss mit einem Punkt enden (`g1.key.`). Das ist DNS-Standard für vollqualifizierte Domainnamen (FQDN).
:::

### 3. Hauptdomain setzen (Root-Zone)

Da der hashicorp/dns Provider keine Root-Zone-Einträge direkt unterstützt, verwenden wir einen alternativen Ansatz. Der Block `triggers` überwacht die Server-IP, ändert sich diese, führt Terraform das Script erneut aus. Über den `local-exec` Provisioner wird das Tool `nsupdate` aufgerufen, das direkt Befehle an den Nameserver sendet:

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

Das Script löscht zunächst eventuelle alte A-Records für die Domain und setzt dann einen neuen Eintrag mit der aktuellen Server-IP.

### 4. Subdomain (www) setzen

Für klassische Subdomains funktioniert der Terraform-Provider problemlos. Hier erstellen wir einen A-Record für `www`, der ebenfalls auf die IP des Servers verweist:

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

### 5. TLS konfigurieren

Für HTTPS muss zuerst die Firewall um Port 443 erweitert werden:

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

::: info

Stelle sicher dass `nsupdate` bei dir Lokal installiert ist. 

Falls nicht kannst du es über `sudo apt install bind9-dnsutils` installieren.

:::

:::

Nach erfolgreicher Ausführung mit `terraform apply` muss auf den Server zugegriffen und Certbot (der Let's Encrypt Client) samt dem Nginx-Plugin installiert werden:

```bash
sudo apt install certbot python3-certbot-nginx
```

Sobald die Installation erfolgreich war, kann das Zertifikat angefordert werden. Certbot konfiguriert Nginx automatisch für HTTPS:

```bash
sudo certbot --nginx -d g1.sdi.hdm-stuttgart.cloud -d www.g1.sdi.hdm-stuttgart.cloud
```

Sollte alles geklappt haben, sollte der Output so aussehen:

```text
Deploying certificate
Successfully deployed certificate for g1.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Successfully deployed certificate for www.g1.sdi.hdm-stuttgart.cloud to /etc/nginx/sites-enabled/default
Congratulations! You have successfully enabled HTTPS on https://g1.sdi.hdm-stuttgart.cloud and https://www.g1.sdi.hdm-stuttgart.cloud
```

### 6. Ergebnis überprüfen

Anschließend kann getestet werden, ob alles erfolgreich geklappt hat. Dies kann direkt über den Browser oder per Terminal verifiziert werden:

```bash
curl -I https://g1.sdi.hdm-stuttgart.cloud
curl -I https://www.g1.sdi.hdm-stuttgart.cloud
```

::: tip
Wenn du einen HTTP 200 Status-Code mit `Content-Type: text/html` siehst, ist der Webserver über HTTPS erreichbar und das TLS-Zertifikat ist aktiv.
:::
