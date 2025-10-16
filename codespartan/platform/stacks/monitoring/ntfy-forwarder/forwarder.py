#!/usr/bin/env python3
"""
Simple webhook forwarder: Alertmanager → ntfy.sh
Convierte webhooks de Alertmanager al formato de ntfy.sh
"""

import json
import requests
from flask import Flask, request
import os

app = Flask(__name__)

NTFY_URL = os.getenv('NTFY_URL', 'https://ntfy.sh/codespartan-mambo-alerts')

def format_alert_message(alert):
    """Formatea una alerta para ntfy.sh"""
    status = alert.get('status', 'unknown')
    labels = alert.get('labels', {})
    annotations = alert.get('annotations', {})

    alertname = labels.get('alertname', 'Unknown Alert')
    severity = labels.get('severity', 'info')
    component = labels.get('component', 'unknown')
    instance = labels.get('instance', 'unknown')

    summary = annotations.get('summary', '')
    description = annotations.get('description', '')

    # Emojis por severidad
    emoji_map = {
        'critical': '🔥',
        'warning': '⚠️',
        'info': 'ℹ️'
    }
    emoji = emoji_map.get(severity, '📢')

    # Título
    if status == 'firing':
        title = f"{emoji} ALERTA: {alertname}"
    else:
        title = f"✅ RESUELTO: {alertname}"

    # Mensaje
    message = f"{summary}\n\n{description}\n\nComponente: {component}\nInstancia: {instance}"

    return title, message, severity

@app.route('/webhook', methods=['POST'])
def webhook():
    """Endpoint principal para todas las alertas"""
    try:
        data = request.json
        alerts = data.get('alerts', [])

        for alert in alerts:
            title, message, severity = format_alert_message(alert)

            # Prioridad para ntfy.sh
            priority_map = {
                'critical': 5,
                'warning': 4,
                'info': 3
            }
            priority = priority_map.get(severity, 3)

            # Enviar a ntfy.sh
            # Nota: ntfy.sh espera headers ASCII, por lo que removemos emojis de títulos
            title_ascii = title.encode('ascii', 'ignore').decode('ascii').strip()

            headers = {
                'Title': title_ascii if title_ascii else 'Alert',
                'Priority': str(priority),
                'Tags': f'{severity},monitoring,codespartan'
            }

            # El mensaje sí puede contener UTF-8
            message_with_emoji = f"{title}\n\n{message}"
            response = requests.post(NTFY_URL, data=message_with_emoji.encode('utf-8'), headers=headers)

            if response.status_code != 200:
                app.logger.error(f'Error sending to ntfy.sh: {response.text}')

        return {'status': 'ok', 'alerts_processed': len(alerts)}, 200

    except Exception as e:
        app.logger.error(f'Error processing webhook: {str(e)}')
        return {'status': 'error', 'message': str(e)}, 500

@app.route('/webhook/critical', methods=['POST'])
def webhook_critical():
    """Endpoint específico para alertas críticas (misma lógica)"""
    return webhook()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return {'status': 'healthy'}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
