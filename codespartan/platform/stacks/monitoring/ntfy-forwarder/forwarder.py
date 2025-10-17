#!/usr/bin/env python3
"""
Multi-channel webhook forwarder: Alertmanager → ntfy.sh + Discord
Convierte webhooks de Alertmanager a múltiples formatos
"""

import json
import requests
from flask import Flask, request
import os

app = Flask(__name__)

NTFY_URL = os.getenv('NTFY_URL', 'https://ntfy.sh/codespartan-mambo-alerts')
DISCORD_WEBHOOK = os.getenv('DISCORD_WEBHOOK', '')

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

def send_to_discord(alert):
    """Envía alerta a Discord usando embeds"""
    if not DISCORD_WEBHOOK:
        return False

    status = alert.get('status', 'unknown')
    labels = alert.get('labels', {})
    annotations = alert.get('annotations', {})

    alertname = labels.get('alertname', 'Unknown Alert')
    severity = labels.get('severity', 'info')
    component = labels.get('component', 'unknown')
    instance = labels.get('instance', 'unknown')

    summary = annotations.get('summary', '')
    description = annotations.get('description', '')

    # Color por severidad
    color_map = {
        'critical': 0xFF0000,  # Rojo
        'warning': 0xFFA500,   # Naranja
        'info': 0x00BFFF       # Azul
    }
    color = color_map.get(severity, 0x808080)

    # Emoji por severidad
    emoji_map = {
        'critical': '🔥',
        'warning': '⚠️',
        'info': 'ℹ️'
    }
    emoji = emoji_map.get(severity, '📢')

    # Estado
    if status == 'firing':
        title = f"{emoji} ALERTA: {alertname}"
        footer_text = "Estado: ACTIVA"
    else:
        title = f"✅ RESUELTO: {alertname}"
        footer_text = "Estado: Resuelta"
        color = 0x00FF00  # Verde para resueltas

    # Construir embed
    embed = {
        "title": title,
        "description": summary,
        "color": color,
        "fields": [
            {
                "name": "Descripción",
                "value": description[:1024] if description else "N/A",
                "inline": False
            },
            {
                "name": "Componente",
                "value": component,
                "inline": True
            },
            {
                "name": "Instancia",
                "value": instance,
                "inline": True
            },
            {
                "name": "Severidad",
                "value": severity.upper(),
                "inline": True
            }
        ],
        "footer": {
            "text": footer_text
        },
        "timestamp": alert.get('startsAt', alert.get('endsAt', ''))
    }

    payload = {
        "username": "CodeSpartan Alerts",
        "avatar_url": "https://cdn-icons-png.flaticon.com/512/3114/3114883.png",
        "embeds": [embed]
    }

    try:
        response = requests.post(DISCORD_WEBHOOK, json=payload)
        if response.status_code in [200, 204]:
            return True
        else:
            app.logger.error(f'Discord error: {response.status_code} - {response.text}')
            return False
    except Exception as e:
        app.logger.error(f'Discord exception: {str(e)}')
        return False

@app.route('/webhook', methods=['POST'])
def webhook():
    """Endpoint principal para todas las alertas - envía a ntfy.sh Y Discord"""
    try:
        data = request.json
        alerts = data.get('alerts', [])

        ntfy_success = 0
        discord_success = 0

        for alert in alerts:
            # Enviar a Discord
            if DISCORD_WEBHOOK:
                if send_to_discord(alert):
                    discord_success += 1

            # Enviar a ntfy.sh
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

            if response.status_code == 200:
                ntfy_success += 1
            else:
                app.logger.error(f'Error sending to ntfy.sh: {response.text}')

        result = {
            'status': 'ok',
            'alerts_processed': len(alerts),
            'ntfy_sent': ntfy_success,
            'discord_sent': discord_success
        }

        return result, 200

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
