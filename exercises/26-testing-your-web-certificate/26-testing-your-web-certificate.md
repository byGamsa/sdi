# 26. Testing your web certificate

Diese Aufgabe baut auf dem Code von Aufgabe 25 auf.

- Es werden drei DNS Einträge angelegt.
- Ein Nginx Web Server wird angelegt und so konfiguriert, dass https requests mit dem in der letzten Aufgabe erstellten Zertifikat zugelassen werden.
- Falls alles erfolgreich funktioniert, kann das Ganze einmal mit der Production-URL von Let's Encrypt durchgeführt werden.
  In dieser Aufgabe wird dies noch manuell implementiert, in der nächsten Aufgabe erfolgt alles automatisiert.

Da wir bisher zwei Server in unserer Konfiguration gestartet haben, allerdings nur einen brauchen, kann bei der Variablen `serverCount=1` eingestellt werden.

Anschließend kann der Terraform-Code schon ausgeführt werden.

Sobald der Server eingerichtet wurde, können wir mit unserem generierten `scp`-File im Ordner work-1/ unser generiertes Zertifikat und unser generierten private Key auf den Server kopieren.
::: warning
Das öffentliche Zertifikat wird normalerweise in den Ordner /etc/ssl/certs/ kopiert, der private Schlüssel kommt in der Ordner /etc/ssl/private/. Da der devops-User nicht einfach dort seine Dateien ablegen darf und der direkte Weg über den root-User deaktiviert wird, müssen wir als Zwischenschritt die Files zuerst in das Homeverzeichnis des devops-Users speichern, anschließend können wir die Files in den richtigen Speicherort speichern.
:::
Kopieren der zwei Files in das Homeverzeichnis des devops-Users

```bash
./work-1/bin/scp gen/certificate.pem devops@work-1.g1.sdi.hdm-stuttgart.cloud:~
./work-1/bin/scp gen/private.pem devops@work-1.g1.sdi.hdm-stuttgart.cloud:~
```

Anschließend über ssh in den Server einloggen

```bash
./work-1/bin/ssh
```

Kopieren der Files in die richtigen Ordner

```bash
sudo mv ~/certificate.pem /etc/ssl/certs/
sudo mv ~/private.pem /etc/ssl/private/
```

Anschließend muss die Nginx default Konfiguration noch angepasst werden:

```bash
sudo nano /etc/nginx/sites-available/default
```

Hier kann folgendes in den Server-Block hinzugefügt werden:

```bash
listen 443 ssl default_server;
listen [::]:443 ssl default_server;
ssl_certificate /etc/ssl/certs/certificate.pem;
ssl_certificate_key /etc/ssl/private/private.pem;
```

Anschließend kann man die Konfiguration testen, nginx neustarten und überprüfen, ob der Server wieder erfolgreich läuft.

```bash
sudo /usr/sbin/nginx -t
sudo systemctl restart nginx
sudo systemctl status nginx
```

Wenn alles erfolgreich geklappt hat, zeigt der Browser immer noch eine Warnmeldung an. Wenn man sich Details des Zertifikats anschaut, sieht man, dass es sich um das Staging-Zertifikat von Let's Encrypt handelt. Anschließend kann alles neu ausgeführt werden mit der Produktions-URL `https://acme-v02.api.letsencrypt.org/directory` von Let's Encrpyt. Bei erfolgreichem Ausführen sollte der Browser keine Fehlermeldung mehr anzeigen.
::: warning
Hier darf nicht vergessen werden, nach erfolgreichem Ausführen des Codes mit der Produktions-URL, wieder aus die Staging-URL zu wechsel!
:::
