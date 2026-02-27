# 27. Combining certificate generation and server creation

Diese Aufgabe baut auf den Aufgaben 25 und 26 auf.

Nachdem wir bereits getestet haben, dass unser Zertifikat vollständig funktioniert, wollen wir ab jetzt nicht mehr manuell das Zertifikat zum Server hinzufügen, sondern automatisiert. Hierfür erweitern wir unsere Terraform-Konfiguration.

::: warning
Bevor an dieser Aufgabe weitergearbeitet wird, sollte überprüft werden, dass in der provider.tf wieder die Staging-URL für Let's Encrypt eingetragen ist!
:::

Um das Zertifikat automatisiert hinzuzufügen, müssen wir unsere Cloud-Init anpassen. Hierbei muss auf die Einrückungen der Zertifikate und des private Keys geachtet werden.
::: code-group
```hcl [main.tf]
resource "local_file" "user_data" {
  count = var.serverCount
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key[count.index].private_key_openssh)
    certificate_pem = indent(6, "${acme_certificate.wildcard_cert.certificate_pem}${acme_certificate.wildcard_cert.issuer_pem}") // [!code ++:2]
    private_key_pem = indent(6, acme_certificate.wildcard_cert.private_key_pem)
  })
  filename = "${var.serverName}-${count.index+1}/gen/userData.yml"
}


```
```hcl [tpl/userData.yaml]
package_update: true
package_upgrade: true

packages:
  - nginx

ssh_pwauth: false
disable_root: true

ssh_keys:
  ed25519_private: |
    ${tls_private_key}
packages:
  - nginx

write_files: // [!code ++:24]
  - path: /etc/ssl/certs/certificate.pem
    content: |
      ${certificate_pem}
    permissions: "0644"

  - path: /etc/ssl/private/private.key
    content: |
      ${private_key_pem}
    permissions: "0600"

  - path: /etc/nginx/sites-available/default
    content: |
      server {
          listen 80 default_server;
          listen [::]:80 default_server;
          listen 443 ssl default_server;
          listen [::]:443 ssl default_server;
                    
          ssl_certificate /etc/ssl/certs/certificate.pem;
          ssl_certificate_key /etc/ssl/private/private.key;
          
          root /var/www/html;
          index index.html index.htm index.nginx-debian.html;
      }

runcmd:
  # Host Key wurde geschrieben -> SSH neu starten, damit er aktiv wird
  - systemctl restart ssh
  - systemctl enable nginx # falls entfernt, diese Zeilen erneut hinzufügen // [!code ++:2]
  - systemctl restart nginx

users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```
:::

Um zu überprüfen, ob alles erfolgreich geklappt hat, kann die Web-Adresse ``https://g1.sdi.hdm-stuttgart.cloud`` im Browser aufgerufen und überprüft werden. Alternativ kann über den ``curl``- Befehl überprüft werden, ob alles korrekt erreicht werden kann.
```bash
curl -k https://g1.sdi.hdm-stuttgart.cloud
curl -k https://www.g1.sdi.hdm-stuttgart.cloud
curl -k https://mail.g1.sdi.hdm-stuttgart.cloud
```

Zudem kann die Terraform-Konfiguration noch einmal mit der Production-URL ``https://acme-v02.api.letsencrypt.org/directory`` von Let's Encrypt durchgeführt werden, um zu überprüfen, ob alles erfolgreich geklappt hat, indem keine Warnmeldung mehr im Browser angezeigt wird.
::: warning
Hier darf erneut nicht vergessen werden, die URL zurück auf die Staging-URL zu stellen!
:::