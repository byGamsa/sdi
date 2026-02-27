# 17. Host-Metadaten generieren

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_modules.html#sdi_cloudProvider_modules_qanda_moduleHostMetaGen)

In dieser Übung wird ein wiederverwendbares Terraform-Submodul `HostMetaData` erstellt. Dieses Modul nimmt die Daten eines Servers entgegen und erzeugt daraus eine JSON-Datei mit Hostmetadaten (IPv4, IPv6, Location). 

## Architektur-Komponenten

| Komponente | Beschreibung |
|---|---|
| **Terraform Modul `host-meta-data`** | Wiederverwendbares Submodul mit eigenen Variablen und Templates |
| **JSON Template** | Template-Datei für die strukturierte Ausgabe der Hostdaten |
| **Modul-Einbindung** | Das Hauptprojekt verwendet das Modul über den `module`-Block |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 15](/exercises/15-working-on-cloud-init) auf.

## Übungsschritte

### 1. Submodul HostMetaData erstellen

Zuerst müssen die Dateien neu organisiert werden. Erstelle einen neuen `modules` Ordner auf gleicher Ebene wie das Übungsverzeichnis. Das Modul `host-meta-data` enthält eigene `main.tf`, `variables.tf` und ein Template-Verzeichnis:

```sh
.
├── 17-generating-host-meta-data/
│   ├── main.tf
│   ├── variables.tf
│   └── providers.tf
│   └── ...
└── modules/  # [!code ++:7]
    └── host-meta-data/
        ├── main.tf
        ├── variables.tf
        └── tpl/ 
            └── hostdata.json
```

Im nächsten Schritt befüllen wir die neu erstellten Dateien im Modul `host-meta-data`.

#### 1.1 Template-Datei (`tpl/hostdata.json`)

Dies ist die Template-Datei, die mit `templatefile()` gerendert wird. Die Platzhalter werden später durch die tatsächlichen Server-Daten ersetzt:

```hcl
{
  "network": {
    "ipv4": "${ip4}",
    "ipv6": "${ip6}"
  },
  "location": "${location}"
}
```

#### 1.2 Variablen (`variables.tf`)

Definiere die Eingangsvariablen, die das Modul von außen benötigt. Jede Variable ist als `nullable = false` markiert, da das Modul ohne diese Daten nicht funktionieren kann:

```hcl
variable "location" {
  type     = string
  nullable = false
}

variable "ipv4Address" {
  type     = string
  nullable = false
}
variable "ipv6Address" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}
```

#### 1.3 Hauptdatei (`main.tf`)

Hier wird die JSON-Datei mit den tatsächlichen Werten gerendert und als lokale Datei geschrieben. Der Dateiname wird aus dem übergebenen Servernamen generiert:

```hcl
resource "local_file" "host_data" {
  content = templatefile("${path.module}/tpl/hostData.json", {
    ip4      = var.ipv4Address
    ip6      = var.ipv6Address
    location = var.location
  })
  filename = "gen/${var.name}.json"
}
```

::: tip 
Die Variable `path.module` zeigt immer auf das Verzeichnis des aktuellen Moduls. Das stellt sicher, dass die Template-Datei relativ zum Modul gefunden wird und unabhängig davon, von wo aus das Modul aufgerufen wird.
:::

### 2. Submodul einbinden

Jetzt, wo das Modul aufgebaut ist, muss es in der `main.tf` des Übungsordners eingebunden werden. Über den `module`-Block wird die Quelle (`source`) angegeben und die erforderlichen Variablen mit den Server-Attributen befüllt:

```sh
module "host_metadata" { # [!code ++:7]
  source      = "../modules/host-meta-data"
  name        = hcloud_server.debian_server.name
  location    = hcloud_server.debian_server.location
  ipv4Address = hcloud_server.debian_server.ipv4_address
  ipv6Address = hcloud_server.debian_server.ipv6_address
}
```

::: info
Nach dem Hinzufügen eines neuen Moduls muss `terraform init` erneut ausgeführt werden, damit Terraform das Modul registriert.
:::

### 3. Erwartetes Ergebnis

Nach erfolgreicher Ausführung mit `terraform apply` erzeugt das Submodul im Verzeichnis `gen` die Datei `debian_server.json` mit den Metadaten des Servers:

```sh
{
  "network": {
    "ipv4": "46.62.215.100",
    "ipv6": "2a01:4f9:c013:70f9::1"
  },
  "location": "hel1"
}
``` 