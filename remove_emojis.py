#!/usr/bin/env python3
"""Script para eliminar todos los emojis de agent.py para compatibilidad con Windows cp1252"""

import re


def remove_emojis(text):
    """Eliminar todos los emojis y caracteres especiales Unicode"""
    # Patrón para emojis y símbolos especiales
    emoji_pattern = re.compile(
        "["
        "\U0001f600-\U0001f64f"  # emoticons
        "\U0001f300-\U0001f5ff"  # símbolos & pictogramas
        "\U0001f680-\U0001f6ff"  # transporte & símbolos de mapa
        "\U0001f1e0-\U0001f1ff"  # banderas (iOS)
        "\U00002700-\U000027bf"  # Dingbats
        "\U0001f900-\U0001f9ff"  # Símbolos suplementarios
        "\U00002600-\U000026ff"  # Miscelánea de símbolos
        "\U0001f700-\U0001f77f"  # Símbolos alquímicos
        "]+",
        flags=re.UNICODE,
    )

    # Reemplazar emojis con [ICON]
    cleaned = emoji_pattern.sub("[ICON]", text)

    # Mapeo específico para caracteres problemáticos conocidos
    replacements = {
        "✅": "[OK]",
        "❌": "[FAIL]",
        "⚡": "[FAST]",
        "🧠": "[THINK]",
        "🔧": "[FIX]",
        "📊": "[STATS]",
        "🎯": "[TARGET]",
        "⚙️": "[CONFIG]",
        "💡": "[IDEA]",
        "🔗": "[LINK]",
        "📦": "[PACKAGE]",
        "🔑": "[KEY]",
        "🚀": "[DEPLOY]",
        "⚠️": "[WARNING]",
        "❗": "[ALERT]",
        "📁": "[FOLDER]",
        "💾": "[SAVE]",
        "🗂️": "[FILES]",
        "📄": "[DOC]",
        "🔍": "[SEARCH]",
        "📂": "[DIR]",
        "🔐": "[SECURE]",
        "🌐": "[WEB]",
        "📝": "[NOTE]",
        "🔄": "[REFRESH]",
        "➡️": "->",
        "🏷️": "[TAG]",
        "🔒": "[LOCK]",
        "🔓": "[UNLOCK]",
    }

    for emoji, replacement in replacements.items():
        cleaned = cleaned.replace(emoji, replacement)

    return cleaned


def main():
    agent_file = "my-agents/gcp-invoice-agent-app/agent.py"

    print("🔧 Limpiando emojis de agent.py...")

    try:
        # Leer archivo
        with open(agent_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Remover emojis
        cleaned_content = remove_emojis(content)

        # Guardar archivo limpio
        with open(agent_file, "w", encoding="utf-8") as f:
            f.write(cleaned_content)

        print(f"✅ Archivo limpiado exitosamente: {agent_file}")
        print("\n📋 Ahora reinicia el servidor ADK:")
        print("   1. Presiona Ctrl+C en la terminal 'adk'")
        print(
            '   2. Ejecuta: adk api_server --port 8001 my-agents --allow_origins="*" --log_level DEBUG 2>&1 | Tee-Object -FilePath logs\\logs-adk.txt'
        )

    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())
