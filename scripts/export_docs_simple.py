#!/usr/bin/env python3
"""
Script para exportar documentación Markdown a HTML y PDF
usando Python con bibliotecas simples.

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


def export_with_pandoc(md_file: Path, output_file: Path, format_type: str):
    """Exporta usando Pandoc"""

    # Opciones comunes
    common_options = [
        "--toc",
        "--toc-depth=3",
        "--number-sections",
        "--highlight-style=tango",
    ]

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
        "html": ["--standalone", "--self-contained"],
    }

    # Construir comando
    cmd = (
        ["pandoc", str(md_file), "-o", str(output_file)]
        + common_options
        + format_options.get(format_type, [])
    )

    try:
        subprocess.run(cmd, check=True, capture_output=True)
        return True, None
    except subprocess.CalledProcessError as e:
        return False, e.stderr.decode("utf-8")


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

            # Exportar
            success, error = export_with_pandoc(md_file, output_file, format_type)

            if success:
                size_kb = output_file.stat().st_size / 1024
                print_colored(f"→ .{format_type} ({size_kb:.1f} KB) ✅", Colors.GREEN)
                stats["success"] += 1
                stats["by_format"][format_type]["success"] += 1
            else:
                print_colored(f"❌ FAILED", Colors.RED)
                if error:
                    print_colored(f"      Error: {error[:100]}", Colors.RED)
                stats["failed"] += 1
                stats["by_format"][format_type]["failed"] += 1

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
