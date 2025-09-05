#!/usr/bin/env python3
"""
🔧 HOMOGENEIZAR TESTS
====================
Convierte todos los archivos de test a formato estándar con 'query'
"""
import os
import json
import glob


def homogenize_test_files():
    """Homogeneizar todos los archivos de test"""
    test_files = glob.glob("*.test.json") + glob.glob("*test*.json")

    print(f"🔧 HOMOGENEIZANDO {len(test_files)} ARCHIVOS DE TEST")
    print("=" * 60)

    converted = 0

    for filename in test_files:
        print(f"📄 Procesando: {filename}")

        try:
            # Leer archivo original
            with open(filename, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Convertir user_content a query
            changed = False
            if "user_content" in data:
                data["query"] = data["user_content"]
                del data["user_content"]
                changed = True
                print(f"   ✅ Convertido: user_content → query")

            # Verificar que tenga query
            if "query" not in data:
                print(f"   ❌ No tiene query ni user_content")
                continue

            # Mostrar la consulta
            print(f"   🤖 Query: {data['query'][:50]}...")

            # Guardar archivo si hubo cambios
            if changed:
                with open(filename, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=4, ensure_ascii=False)
                converted += 1
                print(f"   💾 Guardado")
            else:
                print(f"   ✅ Ya está correcto")

        except Exception as e:
            print(f"   ❌ Error: {e}")

    print("\n" + "=" * 60)
    print(f"📊 RESUMEN:")
    print(f"   📋 Total archivos: {len(test_files)}")
    print(f"   🔧 Convertidos: {converted}")
    print(f"   ✅ Homogeneización completada")


if __name__ == "__main__":
    # Cambiar al directorio de tests
    os.chdir(".")
    homogenize_test_files()
