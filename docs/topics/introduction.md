# Einführung

## Was ist Software Defined Infrastructure?

Software Defined Infrastructure (SDI) beschreibt einen Ansatz, bei dem die gesamte IT-Infrastruktur, also Server, Netzwerke, Speicher und Konfigurationen, durch Software und Code verwaltet wird, anstatt manuell über grafische Oberflächen oder Kommandozeilen. Das Ziel ist es, Infrastruktur **reproduzierbar**, **versionierbar** und **automatisierbar** zu machen.

In der klassischen Systemadministration werden Server manuell eingerichtet: Man loggt sich per SSH ein, installiert Pakete, bearbeitet Konfigurationsdateien und startet Dienste. Das funktioniert bei wenigen Servern, skaliert aber schlecht. Sobald man dutzende oder hunderte Server verwalten muss, werden manuelle Prozesse fehleranfällig und zeitaufwändig.

## Infrastructure as Code (IaC)

Infrastructure as Code ist das zentrale Konzept hinter SDI. Statt Infrastruktur manuell zu konfigurieren, beschreibt man den gewünschten Zustand in Konfigurationsdateien. Diese Dateien können:

- **Versioniert** werden (z.B. mit Git)
- **Überprüft** werden (Code Reviews)
- **Automatisiert** ausgeführt werden (CI/CD Pipelines)
- **Reproduziert** werden (gleiche Konfiguration → gleiches Ergebnis)

## Was ist Terraform?

[Terraform](https://www.terraform.io/) ist ein Open-Source-Tool von HashiCorp und eines der am weitesten verbreiteten IaC-Werkzeuge. Es ermöglicht es, Cloud-Infrastruktur deklarativ zu beschreiben:

```hcl
resource "hcloud_server" "web" {
  name        = "web-server"
  server_type = "cx22"
  image       = "ubuntu-24.04"
}
```

Mit diesem simplen Code-Block wird ein vollständiger Server in der Hetzner Cloud erstellt. Terraform kümmert sich um die Kommunikation mit der Cloud-API, das Erstellen, Aktualisieren und Löschen von Ressourcen.

### Warum Terraform?

- **Deklarativ**: Man beschreibt *was* man haben möchte, nicht *wie* es erstellt wird.
- **Provider-Ökosystem**: Unterstützt hunderte Cloud-Anbieter (AWS, Azure, Hetzner, etc.)
- **State Management**: Terraform merkt sich den aktuellen Zustand der Infrastruktur und kann Änderungen gezielt anwenden.
- **Plan & Apply**: Vor jeder Änderung zeigt `terraform plan`, was genau passieren wird erst nach Bestätigung wird `terraform apply` ausgeführt.

## Warum ist das relevant?

In der modernen Softwareentwicklung ist die Grenze zwischen Entwicklung und Betrieb zunehmend verschwommen. DevOps, Cloud-native Architekturen und Microservices erfordern, dass Entwickler ihre Infrastruktur verstehen und mitgestalten können. SDI-Kenntnisse sind daher eine wichtige Kompetenz:

- **Reproduzierbarkeit**: Entwicklungsumgebungen können identisch zur Produktion aufgesetzt werden.
- **Skalierbarkeit**: Neue Server und Dienste können in Minuten statt Tagen bereitgestellt werden.
- **Zusammenarbeit**: Infrastruktur-Änderungen durchlaufen denselben Review-Prozess wie Code.
- **Disaster Recovery**: Komplette Umgebungen können aus dem Code neu erstellt werden.