Traefik (reverse proxy)

- Expone puertos 80/443
- Emite certificados Let's Encrypt por HTTP-01
- Dashboard protegido por basic auth en https://${DASHBOARD_HOST}

Pasos:
1) Crea el fichero .env a partir de .env.example (reemplaza ACME_EMAIL, DASHBOARD_HOST, BASIC_AUTH).
2) Asegura que la red docker externa "web" existe: docker network create web || true
3) Arranca: docker compose up -d

