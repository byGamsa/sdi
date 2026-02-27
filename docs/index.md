---
layout: home

hero:
  name: 'SDI Exercises'
  text: 'Software-Defined Infrastructure'
  tagline: Step-by-Step Anleitungen für die Übungen der Vorlesung Software Defined Infrastructure
  actions:
    - theme: brand
      text: Zu den Übungen
      link: /exercises/
    - theme: alt
      text: Themen erkunden
      link: /topics/

features:
  - title: 📝 Übungen
    details: Step-by-Step Anleitungen für alle Terraform- und Cloud-Übungen
    link: /exercises/
  - title: 📚 Themen
    details: Übergreifende Erklärungen zu den Kurs-Themen.
    link: /topics/
  - title: 🔗 Lecture Notes
    details: Aufgabenstellungen und Vorlesungsunterlagen.
    link: https://freedocs.mi.hdm-stuttgart.de/apf.html
  - title: 💻 GitHub
    details: Quellcode des Repositories mit allen Terraform-Konfigurationen und Modulen.
    link: https://github.com/byGamsa/sdi
---

## Über dieses Projekt

Dieses Projekt enthält eine Step-by-Step Anleitung für die Übungen der Vorlesung [Software Defined Infrastructure](https://hdm-stuttgart.de/vorlesung_detail?vorlid=5213729) an der [Hochschule der Medien Stuttgart](https://hdm-stuttgart.de/).

Die Übungen basieren auf den [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/apf.html) und behandeln Themen wie Hetzner Cloud, SSH, Terraform und Cloud-init. Ziel ist es, Infrastruktur als Code (IaC) zu verstehen und praktisch anzuwenden.

### Schnellstart

1. Repository klonen und Abhängigkeiten installieren
2. [Terraform installieren](https://developer.hashicorp.com/terraform/downloads)
3. In jeder Übung die `secrets.auto.tfvars.template` kopieren und eigene Zugangsdaten eintragen
4. Mit `terraform init`, `terraform plan` und `terraform apply` loslegen

Mehr Details findest du in der [README](https://github.com/byGamsa/sdi#readme).

## AI-Usage

::: info
Diese Dokumentation wurde mit Unterstützung von KI-Tools (Large Language Models) erstellt.

- Sämtliche Übungen, Konzepte und Code-Implementierungen wurden eigenständig auf Basis der [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/apf.html) und der dort genannten Quellen erarbeitet.
- KI wurde ausschließlich zur Optimierung der Texte, für Correctness-Checking / Debugging sowie zur Klärung von Hintergrundfragen verwendet.
  :::
