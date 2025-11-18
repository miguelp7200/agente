#!/usr/bin/env python3
"""
Script para exportar documentación Markdown a HTML y PDF
usando Python con bibliotecas simples.
Renderiza diagramas de Mermaid automáticamente.

ESTRATEGIA DE RENDERIZADO MERMAID:
==================================
1. PREFERIDO: mermaid-cli local (mmdc)
   - Mantiene código Mermaid ORIGINAL (emojis, <br/>, estilos)
   - Requiere: npm install -g @mermaid-js/mermaid-cli
   - Funciona en WSL (detectado automáticamente)
   - No funciona en Windows (error ICU de Puppeteer)

2. FALLBACK: mermaid.ink API
   - Limpia código agresivamente (elimina emojis, estilos, <br/>)
   - Puede fallar con sintaxis compleja
   - No requiere instalación local

Uso:
    python scripts/export_docs_simple.py
    python scripts/export_docs_simple.py --format pdf
    python scripts/export_docs_simple.py --format html
"""

import os
import sys
import argparse
from pathlib import Path
from datetime import datetime
import subprocess
import re
import tempfile
import shutil
import base64
import zlib
import requests
import time


# Colores para terminal
class Colors:
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    GRAY = "\033[90m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def print_colored(text, color=Colors.RESET):
    """Imprime texto con color"""
    print(f"{color}{text}{Colors.RESET}")


def check_pandoc():
    """Verifica si Pandoc está instalado"""
    try:
        result = subprocess.run(
            ["pandoc", "--version"], capture_output=True, text=True, check=True
        )
        version = result.stdout.split("\n")[0]
        return True, version
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False, None


def is_wsl():
    """Detecta si estamos corriendo en WSL"""
    try:
        with open('/proc/version', 'r') as f:
            return 'microsoft' in f.read().lower() or 'wsl' in f.read().lower()
    except:
        return False


def check_mermaid_cli():
    """Verifica si mermaid-cli (mmdc) está instalado"""
    # En WSL/Linux, usar mmdc directamente
    # En Windows, probar con .cmd
    commands = ["mmdc"] if is_wsl() else ["mmdc.cmd", "mmdc"]
    
    for cmd in commands:
        try:
            result = subprocess.run(
                [cmd, "--version"], 
                capture_output=True, 
                text=True, 
                check=True,
                shell=False if is_wsl() else True
            )
            version = result.stdout.strip()
            return True, version, cmd
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
    
    return False, None, None


def clean_mermaid_code(mermaid_code: str) -> str:
    """
    Limpia agresivamente el código Mermaid para máxima compatibilidad con mermaid.ink API.
    Elimina elementos problemáticos: estilos, emojis, <br/>, paréntesis especiales.
    """
    # 1. Eliminar TODAS las líneas de estilo
    mermaid_code = re.sub(r'^\s*style\s+.*$', '', mermaid_code, flags=re.MULTILINE)
    
    # 2. Eliminar emojis (causan problemas de encoding)
    # Rango de emojis comunes en Unicode
    emoji_pattern = re.compile(
        "["
        "\U0001F1E0-\U0001F1FF"  # flags
        "\U0001F300-\U0001F5FF"  # symbols & pictographs
        "\U0001F600-\U0001F64F"  # emoticons
        "\U0001F680-\U0001F6FF"  # transport & map
        "\U0001F700-\U0001F77F"  # alchemical
        "\U0001F780-\U0001F7FF"  # Geometric Shapes Extended
        "\U0001F800-\U0001F8FF"  # Supplemental Arrows-C
        "\U0001F900-\U0001F9FF"  # Supplemental Symbols and Pictographs
        "\U0001FA00-\U0001FA6F"  # Chess Symbols
        "\U0001FA70-\U0001FAFF"  # Symbols and Pictographs Extended-A
        "\U00002702-\U000027B0"  # Dingbats
        "\U000024C2-\U0001F251"
        "]+",
        flags=re.UNICODE
    )
    mermaid_code = emoji_pattern.sub('', mermaid_code)
    
    # 3. Simplificar labels: eliminar <br/> y caracteres especiales
    def simplify_label(match):
        content = match.group(1)
        content = content.replace('<br/>', ' ').replace('<br>', ' ')
        # Eliminar dos puntos que pueden causar problemas
        content = content.replace(':', '-')
        # Limpiar espacios múltiples
        content = ' '.join(content.split())
        return f'["{content}"]'
    
    mermaid_code = re.sub(r'\["([^"]+)"\]', simplify_label, mermaid_code)
    
    # 4. Simplificar labels en subgraph (eliminar emojis ya aplicado)
    def simplify_subgraph(match):
        label = match.group(2)
        label = label.replace('<br/>', ' ').replace('<br>', ' ')
        label = label.replace(':', '-')
        label = ' '.join(label.split())
        return f'subgraph {match.group(1)}["{label}"]'
    
    mermaid_code = re.sub(r'subgraph\s+(\w+)\["([^"]+)"\]', simplify_subgraph, mermaid_code)
    
    # 5. Eliminar paréntesis especiales en nodos (("texto")) -> ["texto"]
    # Los paréntesis dobles pueden causar problemas
    mermaid_code = re.sub(r'\(\("([^"]+)"\)\)', r'["\1"]', mermaid_code)
    
    # 6. Limpiar espacios y líneas vacías
    mermaid_code = re.sub(r'\n\s*\n\s*\n+', '\n\n', mermaid_code)
    mermaid_code = '\n'.join(line.rstrip() for line in mermaid_code.split('\n'))
    
    # 7. Eliminar líneas vacías al inicio/final
    lines = [line for line in mermaid_code.split('\n') if line.strip()]
    
    return '\n'.join(lines)


def render_mermaid_diagrams(md_content: str, output_dir: Path, mmdc_cmd: str = None) -> tuple[str, int]:
    """
    Encuentra bloques de código Mermaid y los renderiza como imágenes PNG.
    
    Estrategia de renderizado (prioridad):
    1. mermaid-cli local (mmdc) - PREFERIDO: mantiene código original con emojis, <br/>, estilos
    2. mermaid.ink API - FALLBACK: requiere limpiar código para compatibilidad
    
    Args:
        md_content: Contenido Markdown con bloques ```mermaid```
        output_dir: Directorio donde guardar las imágenes PNG
        mmdc_cmd: Comando mmdc disponible ('mmdc' o 'mmdc.cmd')
    
    Returns:
        (markdown_modificado, diagramas_renderizados)
    """
    # Patrón para detectar bloques de código Mermaid
    mermaid_pattern = r'```mermaid\n(.*?)```'
    
    diagrams_rendered = 0
    use_mmdc = mmdc_cmd is not None
    
    def render_with_mmdc(mermaid_code: str, img_path: Path) -> bool:
        """Renderizar con mermaid-cli local (NO limpia código - mantiene original)"""
        if not mmdc_cmd:
            return False
        
        # Crear archivo temporal con el código Mermaid
        with tempfile.NamedTemporaryFile(mode='w', suffix='.mmd', delete=False, encoding='utf-8') as f:
            f.write(mermaid_code)
            mmd_file = Path(f.name)
        
        try:
            # Ejecutar mmdc con fondo transparente
            cmd = [mmdc_cmd, "-i", str(mmd_file), "-o", str(img_path), "-b", "transparent"]
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,
                shell=False if is_wsl() else True
            )
            
            success = result.returncode == 0 and img_path.exists()
            if not success and result.stderr:
                print_colored(f"      ⚠️ mmdc stderr: {result.stderr[:100]}", Colors.YELLOW)
            
            return success
        except subprocess.TimeoutExpired:
            print_colored(f"      ⚠️ mmdc timeout (30s)", Colors.YELLOW)
            return False
        except Exception as e:
            print_colored(f"      ⚠️ mmdc error: {str(e)[:100]}", Colors.YELLOW)
            return False
        finally:
            # Limpiar archivo temporal
            try:
                if mmd_file.exists():
                    mmd_file.unlink()
            except:
                pass
    
    def render_with_api(cleaned_code: str, img_path: Path, max_retries: int = 3) -> bool:
        """Fallback: renderizar con mermaid.ink API (requiere código limpio)"""
        for attempt in range(max_retries):
            try:
                # Codificar el código Mermaid para la URL
                encoded = base64.urlsafe_b64encode(
                    zlib.compress(cleaned_code.encode('utf-8'), 9)
                ).decode('ascii')
                url = f"https://mermaid.ink/img/{encoded}"
                
                response = requests.get(url, timeout=15)
                
                if response.status_code == 200:
                    with open(img_path, 'wb') as f:
                        f.write(response.content)
                    return True
                elif attempt < max_retries - 1:
                    time.sleep(1)
            except Exception as e:
                if attempt < max_retries - 1:
                    time.sleep(1)
        
        return False
    
    def replace_mermaid(match):
        nonlocal diagrams_rendered
        mermaid_code = match.group(1)
        
        try:
            # Generar nombre único para la imagen
            img_name = f"mermaid_diagram_{diagrams_rendered + 1}.png"
            img_path = output_dir / img_name
            
            # ESTRATEGIA 1: Intentar con mmdc local (código ORIGINAL)
            if use_mmdc:
                if render_with_mmdc(mermaid_code, img_path):
                    diagrams_rendered += 1
                    return f"\n![Diagrama Mermaid]({img_name})\n"
                else:
                    print_colored(f"      ⚠️ mmdc falló para diagrama {diagrams_rendered + 1}, probando API...", Colors.YELLOW)
            
            # ESTRATEGIA 2: Fallback a API (código LIMPIO)
            cleaned_code = clean_mermaid_code(mermaid_code)
            if render_with_api(cleaned_code, img_path):
                diagrams_rendered += 1
                return f"\n![Diagrama Mermaid]({img_name})\n"
            
            # Si ambos fallan, dejar el código original
            print_colored(f"      ❌ No se pudo renderizar diagrama {diagrams_rendered + 1}", Colors.RED)
            return match.group(0)
        
        except Exception as e:
            print_colored(f"      ⚠️ Error inesperado: {str(e)[:100]}", Colors.YELLOW)
            return match.group(0)
    
    # Reemplazar todos los bloques Mermaid
    modified_content = re.sub(mermaid_pattern, replace_mermaid, md_content, flags=re.DOTALL)
    
    return modified_content, diagrams_rendered


def export_with_pandoc(md_file: Path, output_file: Path, format_type: str, resource_dir: Path = None):
    """Exporta usando Pandoc con soporte para diagramas Mermaid renderizados"""

    # Opciones comunes (compatibles con Pandoc 3.x)
    common_options = [
        "--toc",
        "--toc-depth=3",
        "--number-sections",
        "--highlight-style=tango",  # Cambio: syntax-highlighting -> highlight-style
        "--from=markdown",
    ]
    
    # Agregar resource path si se especifica (para imágenes)
    if resource_dir:
        common_options.append(f"--resource-path={resource_dir}")

    # Opciones específicas por formato
    format_options = {
        "pdf": [
            "-V",
            "geometry:margin=1in",
            "-V",
            "fontsize=11pt",
            "-V",
            "documentclass=article",
            "-V",
            "lang=es-CL",
        ],
        "docx": [],
        "html": ["--standalone", "--embed-resources"],
    }

    # Construir comando - usar rutas absolutas
    cmd = (
        ["pandoc", str(md_file.resolve()), "-o", str(output_file.resolve())]
        + common_options
        + format_options.get(format_type, [])
    )

    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return True, None, 0
    except subprocess.CalledProcessError as e:
        return False, e.stderr.decode("utf-8"), 0


def main():
    parser = argparse.ArgumentParser(
        description="Exporta documentación Markdown a múltiples formatos"
    )
    parser.add_argument(
        "--format",
        choices=["pdf", "docx", "html", "all"],
        default="all",
        help="Formato de exportación (default: all)",
    )
    parser.add_argument(
        "--output-dir", default="", help="Directorio de salida personalizado"
    )

    args = parser.parse_args()

    # Configuración
    docs_dir = Path("docs/official")
    export_base = Path("docs/exports")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    if args.output_dir:
        export_dir = Path(args.output_dir)
    else:
        export_dir = export_base / f"batch_{timestamp}"

    export_dir.mkdir(parents=True, exist_ok=True)

    # Banner
    print()
    print_colored("═" * 60, Colors.CYAN)
    print_colored("  📄 EXPORTADOR DE DOCUMENTACIÓN - Invoice Chatbot", Colors.CYAN)
    print_colored("═" * 60, Colors.CYAN)
    print()
    print_colored(f"📂 Fuente: {docs_dir}", Colors.GRAY)
    print_colored(f"📂 Destino: {export_dir}", Colors.GRAY)
    print_colored(f"📝 Formato(s): {args.format.upper()}", Colors.YELLOW)
    print()

    # Verificar Pandoc
    print_colored("🔍 Verificando dependencias...", Colors.CYAN)
    pandoc_ok, pandoc_version = check_pandoc()

    if not pandoc_ok:
        print_colored("   ❌ ERROR: Pandoc no está instalado", Colors.RED)
        print()
        print_colored("   Instalar con:", Colors.YELLOW)
        print_colored("   > winget install --id JohnMacFarlane.Pandoc", Colors.GRAY)
        print_colored("   > choco install pandoc", Colors.GRAY)
        print()
        sys.exit(1)

    print_colored(f"   ✅ Pandoc: {pandoc_version}", Colors.GREEN)

    # Verificar Mermaid CLI
    mermaid_ok, mermaid_version, mmdc_cmd = check_mermaid_cli()
    
    if not mermaid_ok:
        print_colored("   ⚠️  Mermaid CLI no disponible - usando mermaid.ink API", Colors.YELLOW)
        print_colored("      (API puede fallar con sintaxis compleja)", Colors.GRAY)
        print_colored("      Instalar en WSL: npm install -g @mermaid-js/mermaid-cli", Colors.GRAY)
        mmdc_cmd = None
    else:
        env_type = "WSL" if is_wsl() else "Windows"
        print_colored(f"   ✅ Mermaid CLI: {mermaid_version} ({env_type}, cmd: {mmdc_cmd})", Colors.GREEN)
    
    print()

    # Buscar archivos Markdown
    print_colored("🔎 Buscando documentos Markdown...", Colors.CYAN)
    md_files = list(docs_dir.rglob("*.md"))

    if not md_files:
        print_colored(f"   ❌ No se encontraron archivos .md en {docs_dir}", Colors.RED)
        sys.exit(1)

    print_colored(f"   📄 {len(md_files)} documentos encontrados", Colors.GREEN)
    print()

    # Determinar formatos
    formats = ["pdf", "docx", "html"] if args.format == "all" else [args.format]

    # Estadísticas
    stats = {
        "total": 0,
        "success": 0,
        "failed": 0,
        "mermaid_diagrams": 0,
        "by_format": {fmt: {"success": 0, "failed": 0} for fmt in formats},
    }

    # Exportar documentos
    for format_type in formats:
        print_colored("─" * 60, Colors.GRAY)
        print_colored(f"📝 Exportando a {format_type.upper()}", Colors.YELLOW)
        print_colored("─" * 60, Colors.GRAY)
        print()

        for md_file in md_files:
            stats["total"] += 1

            # Calcular ruta de salida
            relative_path = md_file.relative_to(docs_dir)
            output_subdir = export_dir / relative_path.parent
            output_subdir.mkdir(parents=True, exist_ok=True)

            output_file = output_subdir / f"{md_file.stem}.{format_type}"

            # Mostrar progreso
            display_path = str(relative_path).replace("\\", "/")
            print(f"   → {display_path}", end=" ")

            # Leer contenido del markdown
            try:
                with open(md_file, 'r', encoding='utf-8') as f:
                    md_content = f.read()
            except Exception as e:
                print_colored(f"❌ Error leyendo archivo: {e}", Colors.RED)
                stats["failed"] += 1
                stats["by_format"][format_type]["failed"] += 1
                continue

            # Crear directorio temporal para imágenes Mermaid en el mismo directorio de salida
            images_dir = output_subdir / "images"
            images_dir.mkdir(parents=True, exist_ok=True)

            try:
                # Renderizar diagramas Mermaid si está disponible
                diagrams_count = 0
                if mermaid_ok:
                    md_content, diagrams_count = render_mermaid_diagrams(md_content, images_dir, mmdc_cmd)
                    if diagrams_count > 0:
                        stats["mermaid_diagrams"] += diagrams_count
                        # Actualizar referencias para que apunten a la subcarpeta images
                        md_content = md_content.replace("](mermaid_", "](images/mermaid_")

                # Guardar markdown modificado temporalmente en el directorio de salida
                temp_md_file = output_subdir / f"_temp_{md_file.name}"
                with open(temp_md_file, 'w', encoding='utf-8') as f:
                    f.write(md_content)

                # Exportar con Pandoc
                success, error, _ = export_with_pandoc(temp_md_file, output_file, format_type, output_subdir)

                if success:
                    size_kb = output_file.stat().st_size / 1024
                    mermaid_info = f" [{diagrams_count} 📊]" if diagrams_count > 0 else ""
                    print_colored(f"→ .{format_type} ({size_kb:.1f} KB){mermaid_info} ✅", Colors.GREEN)
                    stats["success"] += 1
                    stats["by_format"][format_type]["success"] += 1
                else:
                    print_colored(f"❌ FAILED", Colors.RED)
                    if error:
                        print_colored(f"      Error: {error[:100]}", Colors.RED)
                    stats["failed"] += 1
                    stats["by_format"][format_type]["failed"] += 1

            finally:
                # Limpiar archivo markdown temporal
                try:
                    temp_md_path = output_subdir / f"_temp_{md_file.name}"
                    if temp_md_path.exists():
                        temp_md_path.unlink()
                except:
                    pass  # Ignorar errores de limpieza

        print()

    # Crear carpeta "latest"
    latest_dir = export_base / "latest"
    if latest_dir.exists():
        if latest_dir.is_symlink():
            latest_dir.unlink()
        else:
            import shutil

            shutil.rmtree(latest_dir)

    try:
        # Intentar symlink (Unix/Linux/Mac)
        latest_dir.symlink_to(export_dir.resolve(), target_is_directory=True)
        print_colored("🔗 Symlink 'latest' creado", Colors.GREEN)
    except (OSError, NotImplementedError):
        # Windows o sin permisos: copiar directorio
        import shutil

        shutil.copytree(export_dir, latest_dir)
        print_colored("📁 Copia 'latest' creada", Colors.GREEN)

    print()

    # Resumen final
    print_colored("═" * 60, Colors.GREEN)
    print_colored("              ✅ EXPORTACIÓN COMPLETADA", Colors.GREEN)
    print_colored("═" * 60, Colors.GREEN)
    print()

    print_colored("📊 ESTADÍSTICAS GENERALES", Colors.CYAN)
    print_colored("─" * 60, Colors.GRAY)
    print(f"   Total conversiones: {stats['total']}")
    success_pct = (stats["success"] / stats["total"] * 100) if stats["total"] > 0 else 0
    print_colored(f"   Exitosas: {stats['success']} ({success_pct:.1f}%)", Colors.GREEN)
    if stats["failed"] > 0:
        print_colored(f"   Fallidas: {stats['failed']}", Colors.RED)
    else:
        print(f"   Fallidas: {stats['failed']}")
    if stats["mermaid_diagrams"] > 0:
        print_colored(f"   📊 Diagramas Mermaid renderizados: {stats['mermaid_diagrams']}", Colors.CYAN)
    print()

    print_colored("📊 POR FORMATO", Colors.CYAN)
    print_colored("─" * 60, Colors.GRAY)
    for format_type in formats:
        fmt_stats = stats["by_format"][format_type]
        status = Colors.GREEN if fmt_stats["failed"] == 0 else Colors.YELLOW
        print_colored(
            f"   {format_type.upper()}: {fmt_stats['success']} exitosos, {fmt_stats['failed']} fallidos",
            status,
        )
    print()

    print_colored("📂 UBICACIÓN DE ARCHIVOS", Colors.CYAN)
    print_colored("─" * 60, Colors.GRAY)
    print(f"   Batch actual: {export_dir}")
    print(f"   Latest: {latest_dir}")
    print()

    # Calcular tamaño total
    total_size = sum(f.stat().st_size for f in export_dir.rglob("*") if f.is_file())
    total_size_mb = total_size / (1024 * 1024)
    print_colored(f"💾 Tamaño total: {total_size_mb:.2f} MB", Colors.CYAN)
    print()

    print_colored("✨ ¡Exportación completa! ✨", Colors.GREEN)
    print()


if __name__ == "__main__":
    main()
