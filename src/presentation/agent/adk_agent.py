"""
ADK Agent Wrapper - Clean Architecture Integration
===================================================
Thin wrapper that delegates to application services.
Maintains ADK compatibility while using SOLID refactored code.
"""

import sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Import ADK components
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from google.adk.planners import BuiltInPlanner
from toolbox_core import ToolboxSyncClient

# Import service container
from src.container import get_container
from src.core.config import get_config

# ================================================================
# Configuration and Initialization
# ================================================================

# Load configuration
config = get_config()

# Get service container
container = get_container()

# Initialize MCP Toolbox
toolbox_url = config.get("service.mcp_toolbox_url", "http://127.0.0.1:5000")
toolbox_client = ToolboxSyncClient(toolbox_url)

# Load MCP toolsets
invoice_search_tools = toolbox_client.load_toolset("gasco_invoice_search")
zip_management_tools = toolbox_client.load_toolset("gasco_zip_management")
mcp_tools = invoice_search_tools + zip_management_tools

print(f"ADK Agent initialized with service container", file=sys.stderr)
container.print_status()

# ================================================================
# URL Signing Tool - Agent can call this to sign gs:// URLs
# ================================================================


def generate_individual_download_links(pdf_urls: str) -> dict:
    """
    Tool that agent can call to convert gs:// URLs to signed URLs.
    
    Registered as ADK FunctionTool. Agent's prompt instructs it to call
    this tool when it receives gs:// URLs from other tools.
    
    Args:
        pdf_urls: Comma-separated string of gs:// URLs
        
    Returns:
        Dictionary with success status and signed URLs
    """
    print("[TOOL] generate_individual_download_links called", file=sys.stderr)
    
    # Parse comma-separated URLs
    pdf_urls_list = [url.strip() for url in pdf_urls.split(",") if url.strip()]
    
    if not pdf_urls_list:
        return {
            "success": False,
            "error": "No se proporcionaron URLs de PDF",
            "download_urls": []
        }
    
    print(f"[TOOL] Processing {len(pdf_urls_list)} URLs", file=sys.stderr)
    
    # Get URL signer from container
    url_signer = container.url_signer
    
    # Sign each URL
    signed_urls = []
    errors = []
    
    for gs_url in pdf_urls_list:
        try:
            signed_url = url_signer.generate_signed_url(gs_url)
            signed_urls.append(signed_url)
            print(f"[TOOL] Signed: {gs_url[:50]}...", file=sys.stderr)
        except Exception as e:
            error_msg = f"Error signing {gs_url}: {str(e)}"
            errors.append(error_msg)
            print(f"[TOOL] ERROR: {error_msg}", file=sys.stderr)
    
    result = {
        "success": len(signed_urls) > 0,
        "download_urls": signed_urls,
        "total": len(pdf_urls_list),
        "signed": len(signed_urls),
        "failed": len(errors)
    }
    
    if errors:
        result["errors"] = errors
    
    signed_count = result['signed']
    total_count = result['total']
    msg = f"[TOOL] Result: {signed_count}/{total_count} signed"
    print(msg, file=sys.stderr)
    return result


# ================================================================
# ADK Agent Tools (Thin Wrappers)
# ================================================================


def search_invoices_by_rut(rut: str, limit: int = 10) -> dict:
    """
    Search invoices by customer RUT

    Args:
        rut: Customer RUT (Chilean tax ID)
        limit: Maximum number of results

    Returns:
        Dictionary with invoices (URLs NOT signed - agent must call
        generate_individual_download_links tool)
    """
    try:
        invoice_service = container.invoice_service
        # Don't generate URLs here - let agent call the tool
        invoices = invoice_service.get_invoices_by_rut(
            rut, limit=limit, generate_urls=False
        )
        return {
            "success": True,
            "count": len(invoices),
            "invoices": invoices
        }
    except Exception as e:
        print(f"ERROR search_invoices_by_rut: {e}", file=sys.stderr)
        return {
            "success": False,
            "error": str(e),
            "count": 0,
            "invoices": []
        }


def create_zip_package(invoice_numbers: list[str]) -> dict:
    """
    Create ZIP package from invoice numbers

    Args:
        invoice_numbers: List of invoice numbers

    Returns:
        Dictionary with ZIP download URL
    """
    try:
        # Get invoices
        invoice_service = container.invoice_service
        invoices = []

        for invoice_number in invoice_numbers:
            invoice_data = invoice_service.get_invoice_by_number(
                invoice_number,
                generate_urls=False,  # Don't need URLs, just creating ZIP
            )
            if invoice_data:
                # Convert back to domain model (temporary - will improve this)
                from src.core.domain.models import Invoice

                raw_row = invoice_data["metadata"]["raw_row"]
                invoice = Invoice.from_bigquery_row(raw_row)
                invoices.append(invoice)

        if not invoices:
            return {
                "success": False,
                "error": "No invoices found",
                "download_url": None,
            }

        # Create ZIP
        zip_service = container.zip_service
        zip_package = zip_service.create_zip_from_invoices(invoices)

        return {
            "success": True,
            "package_id": zip_package.package_id,
            "download_url": zip_package.download_url,
            "file_size_mb": zip_package.file_size_mb,
            "pdf_count": zip_package.pdf_count,
        }

    except Exception as e:
        print(f"ERROR create_zip_package: {e}", file=sys.stderr)
        return {"success": False, "error": str(e), "download_url": None}


# ================================================================
# ADK Agent Configuration
# ================================================================

# Get Vertex AI configuration
vertex_model = config.get("vertex_ai.model", "gemini-2.5-flash")
vertex_temperature = config.get("vertex_ai.temperature", 0.3)
thinking_enabled = config.get("vertex_ai.thinking.enabled", False)
thinking_budget = config.get("vertex_ai.thinking.budget", 1024)

# System instruction
system_instruction = """
You are a helpful invoice assistant for Gasco.

You have access to invoice data in BigQuery and can:
- Search invoices by RUT, invoice number, solicitante code
- Generate signed URLs for PDF downloads
- Create ZIP packages for multiple invoices

CRITICAL INSTRUCTION FOR PDF URLS:
When any tool returns URLs in gs:// format (like gs://bucket/file.pdf),
you MUST call the generate_individual_download_links tool to convert them
to signed HTTPS URLs before showing them to the user.

NEVER show gs:// URLs directly to the user - always convert them first.

Always provide clear, concise responses in Spanish.
"""

# Create ADK agent with all MCP tools
root_agent = Agent(
    name="gasco_invoice_assistant",
    model=vertex_model,
    description=(
        "Invoice assistant for Gasco with BigQuery access "
        "and PDF generation"
    ),
    tools=[
        # MCP Toolbox tools (loaded from toolsets)
        *mcp_tools,
        # Custom wrapped tools
        FunctionTool(search_invoices_by_rut),
        FunctionTool(create_zip_package),
        # URL signing tool - agent calls this for gs:// URLs
        FunctionTool(generate_individual_download_links),
    ],
    instruction=system_instruction,
    generate_content_config={
        "temperature": vertex_temperature,
    },
)

print("ADK root_agent configured:", file=sys.stderr)
print(f"  - Model: {vertex_model}", file=sys.stderr)
print(f"  - Temperature: {vertex_temperature}", file=sys.stderr)
print(f"  - Thinking mode: {thinking_enabled}", file=sys.stderr)
print(f"  - Tools: {len(root_agent.tools)}", file=sys.stderr)
