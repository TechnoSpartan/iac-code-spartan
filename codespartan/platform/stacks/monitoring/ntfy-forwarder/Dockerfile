FROM python:3.13-alpine

WORKDIR /app

# Instalar dependencias con versiones fijas para builds reproducibles
RUN pip install --no-cache-dir \
    flask==3.1.2 \
    requests==2.32.5 \
    gunicorn==23.0.0

# Copiar script
COPY forwarder.py /app/

# Hacer ejecutable
RUN chmod +x /app/forwarder.py

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Ejecutar con gunicorn (production-ready)
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "30", "forwarder:app"]
