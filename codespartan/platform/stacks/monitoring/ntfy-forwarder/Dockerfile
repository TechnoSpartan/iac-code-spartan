FROM python:3.11-alpine

WORKDIR /app

# Instalar dependencias
RUN pip install --no-cache-dir flask requests gunicorn

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
