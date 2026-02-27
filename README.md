# Software Defined Infrastructure (SDI) - Übungen

Dieses Repository enthält eine Step-by-Step Anleitung für die Übungen der Seite [freedocs.mi.hdm-stuttgart.de/apf.html](https://freedocs.mi.hdm-stuttgart.de/apf.html).

Das Projekt ist im Rahmen der Vorlesung [Software Defined Infrastructure](https://hdm-stuttgart.de/vorlesung_detail?vorlid=5213729) an der [Hochschule der Medien Stuttgart](https://hdm-stuttgart.de/) entstanden.

## 🚀 Quick Links

- 📖 [Dokumentation (VitePress)](https://byGamsa.github.io/sdi/)
- 💻 [GitHub Repository](https://github.com/byGamsa/sdi)

## 📖 Über den Kurs

In diesem Kurs geht es um die automatisierte Verwaltung und Skalierung von Software-Infrastrukturen. Wir nutzen moderne Tools wie Terraform, um Infrastruktur als Code (IaC) zu verstehen und zu dokumentieren.

---

## 📂 Projektstruktur

```text
.
├── .github/workflows   # CI/CD (GitHub Actions für Docs Deployment)
├── docs                # VitePress Dokumentationsquellen
├── exercises           # Terraform Übungen (nach Themen sortiert)
│   ├── modules         # Wiederverwendbare Terraform Module
│   └── 01-xx           # Einzelne Übungsverzeichnisse
├── package.json        # Node.js Skripte für VitePress
└── README.md           # Diese Übersicht
```

## 🛠 Projekt-Setup

### Voraussetzungen

Stellen Sie sicher, dass folgende Tools installiert sind:

- **Node.js** (v18 oder höher) & **npm**
- **Terraform** ([Download hier](https://developer.hashicorp.com/terraform/downloads))

### Dokumentation bauen

Um die VitePress-Dokumentation lokal anzuzeigen oder zu bauen:

```bash
# Abhängigkeiten installieren
npm install

# Lokaler Entwicklungs-Server
npm run docs:dev

# Statische Dokumentation generieren
npm run docs:build
```

---

## 🏗 Übungen durchführen (Terraform)

Für die meisten Übungen in diesem Kurs benötigen wir Zugriff auf die **Hetzner Cloud**.

### Konfiguration (Secrets)

In jedem Übungsverzeichnis (unter `exercises/`) befindet sich eine Datei namens `secrets.auto.tfvars.template`. Gehen Sie wie folgt vor:

1. Kopieren Sie die Datei: `copy secrets.auto.tfvars.template secrets.auto.tfvars` (oder manuell duplizieren).
2. Öffnen Sie `secrets.auto.tfvars` und ersetzen Sie die Platzhalter:
   - **Hetzner API Token**: Erstellen Sie ein Projekt in der [Hetzner Cloud Console](https://console.hetzner.cloud/), gehen Sie auf "Security" -> "API Tokens" und generieren Sie einen "Read & Write" Token.
   - **SSH Key**: Fügen Sie Ihren Public SSH Key hinzu. Falls Sie noch keinen haben, generieren Sie diesen mit `ssh-keygen`.

### Beispiel: Eine Übung starten

```bash
# In das Verzeichnis der Übung wechseln
cd exercises/13-incrementally-creating-a-base-system

# Terraform initialisieren (lädt Provider herunter)
terraform init

# Plan anzeigen
terraform plan

# Infrastruktur erstellen
terraform apply
```

## ⚖️ Lizenz

Dieses Projekt steht unter der [MIT License](LICENSE).
