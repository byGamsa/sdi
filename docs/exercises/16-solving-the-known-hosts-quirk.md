# 16. Das `~/.ssh/known_hosts` Problem lösen

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_cloudInit.html#sdi_cloudProvider_cloudInit_qanda_solveSshKnownHosts)

Wenn Server bei Hetzner Cloud zerstört und neu erstellt werden, erhalten sie neue Host Keys. Das führt zur bekannten SSH-Warnung: `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`. In dieser Übung lösen wir dieses Problem, indem wir eigene SSH Host Keys generieren, sie dem Server über Cloud-Init übergeben und Wrapper-Skripte erstellen, die ein separates `known_hosts`-File verwenden.

## Architektur-Komponenten

| Komponente                  | Beschreibung                                                                |
| --------------------------- | --------------------------------------------------------------------------- |
| **TLS Private Key**         | Von Terraform generierter ED25519 SSH Host Key                              |
| **`gen/known_hosts`**       | Eigenes Known-Hosts-File mit dem generierten Public Key                     |
| **`bin/ssh` und `bin/scp`** | Wrapper-Skripte, die das eigene Known-Hosts-File verwenden                  |
| **Cloud-Init Template**     | Übergibt den Private Key an den Server, damit er den richtigen Host Key hat |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 15](/exercises/15-working-on-cloud-init) auf. Die dort erstellte Cloud-Init Konfiguration wird hier um den SSH Host Key erweitert.

## Übungsschritte

### 1. Wrapper-Skripte erstellen

Zuerst erstellen wir im Ordner `tpl` zwei Template-Skripte für SSH und SCP. Diese verwenden die Option `-o UserKnownHostsFile`, um ein eigenes Known-Hosts-File statt des systemweiten `~/.ssh/known_hosts` zu nutzen.

::: code-group

```bash [ssh.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${devopsUsername}@${ip} "$@"
```

```bash [scp.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ${devopsUsername}@${ip} ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
```

:::

Die Platzhalter `${devopsUsername}` und `${ip}` werden später durch `templatefile()` mit den tatsächlichen Werten ersetzt.

### 2. Host Key und known_hosts generieren

Jetzt erstellen wir einen TLS-Schlüssel mit dem ED25519-Algorithmus. Aus dessen öffentlichem Teil und der Server-IP-Adresse wird eine eigene `known_hosts`-Datei zusammengesetzt und im Ordner `gen` abgelegt.

::: code-group

```hcl [main.tf]
resource "tls_private_key" "host_key" { // [!code ++]
  algorithm = "ED25519" // [!code ++]
} // [!code ++]

resource "local_file" "known_hosts" { // [!code ++]
  content = join(" " // [!code ++]
    ,[ hcloud_server.helloServer.ipv4_address // [!code ++]
    , tls_private_key.host_key.public_key_openssh ] // [!code ++]
  ) // [!code ++]
  filename        = "gen/known_hosts" // [!code ++]
  file_permission = "644"// [!code ++]
} // [!code ++]

```

:::

### 3. Ausführbare Skripte generieren

Aus den Templates müssen noch ausführbare Dateien im Ordner `bin` generiert werden. Der Username wurde ebenfalls als Variable ausgelagert (`var.loginUser`) und muss deshalb ebenfalls angepasst werden:

::: code-group

```hcl [main.tf]
resource "local_file" "ssh_script" { //[!code ++]
  content = templatefile("${path.module}/tpl/ssh.sh", {// [!code ++]
    devopsUsername = var.loginUser, //[!code ++]
    ip = hcloud_server.helloServer.ipv4_address //[!code ++]
  }) //[!code ++]
  filename        = "bin/ssh" //[!code ++]
  file_permission = "755"//[!code ++]
}//[!code ++]

resource "local_file" "scp_script" { //[!code ++]
  content = templatefile("${path.module}/tpl/scp.sh", { //[!code ++]
    devopsUsername = var.loginUser, //[!code ++]
    ip = hcloud_server.helloServer.ipv4_address //[!code ++]
  }) // [!code ++]
  filename        = "bin/scp" //[!code ++]
  file_permission = "755" //[!code ++]
} //[!code ++]
```

:::

### 4. Private Key an Cloud-Init übergeben

Damit der Server auch tatsächlich den von uns generierten Host Key verwendet, muss der Private Key über die `userData.yml` an den Server übergeben werden. Cloud-Init kann über das `ssh_keys` Modul Host Keys setzen.

Zuletzt muss der Private Key der `userData.yml` hinzugefügt und der SSH-Service neugestartet werden, damit der Key aktiv wird:

::: code-group

```hcl [main.tf]
resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh) //[!code ++]
  })

  filename = "gen/userData.yml"
}
```

```yaml [tpl/userData.yaml]
#cloud-config
package_update: true
package_upgrade: true

packages:
  - nginx

ssh_pwauth: false
disable_root: true

ssh_keys:  //[!code ++:3]
  ed25519_private: |
    ${tls_private_key}

ssh_pwauth: false

runcmd:
  - systemctl restart ssh
  - systemctl start nginx
  - systemctl enable nginx

users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```

:::

::: info
Die Funktion `indent(4, ...)` sorgt dafür, dass der mehrzeilige Private Key korrekt eingerückt in die YAML-Datei eingefügt wird. Ohne korrekte Einrückung wäre die YAML-Datei ungültig.
:::

### 5. Ergebnis überprüfen

Nach `terraform apply` werden folgende Dateien generiert:

| Datei              | Beschreibung                                   |
| ------------------ | ---------------------------------------------- |
| `bin/ssh`          | SSH-Wrapper mit eigenem Known-Hosts-File       |
| `bin/scp`          | SCP-Wrapper mit eigenem Known-Hosts-File       |
| `gen/known_hosts`  | Known-Hosts-Datei mit Server-IP und Public Key |
| `gen/userData.yml` | Generiertes Cloud-Init Template                |

Verbinde dich mit dem Server über den Wrapper:

```bash
./bin/ssh
```

Das `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` Problem sollte damit behoben sein, da der SSH-Client nun den von uns generierten Key gegen die eigene `known_hosts`-Datei prüft.

Dateien können mit dem SCP-Wrapper kopiert werden (IP, Name und Pfade entsprechend anpassen):

```bash
./bin/scp test.txt devops@<SERVER_IP>:/home/devops
```
