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