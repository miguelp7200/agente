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

# Initialize conversation tracking service
from src.application.services.conversation_tracking_service import (
    ConversationTrackingService,
)
from src.infrastructure.repositories.bigquery_conversation_repository import (
    BigQueryConversationRepository,
)

# Create BigQuery repository and tracking service
bq_repo = BigQueryConversationRepository()
conversation_tracker = ConversationTrackingService(repository=bq_repo)

# Check if dual-write mode is enabled
tracking_backend = config.get("analytics.conversation_tracking.backend", "solid")
legacy_tracker = None

if tracking_backend in ["legacy", "dual"]:
    # Import Legacy tracker for dual-write or legacy-only mode
    print(
        f"[ANALYTICS] Backend mode: {tracking_backend} " "(importing Legacy tracker)",
        file=sys.stderr,
    )
    try:
        legacy_path = (
            Path(__file__).parent.parent.parent.parent
            / "my-agents"
            / "gcp_invoice_agent_app"
        )
        sys.path.insert(0, str(legacy_path))
        from conversation_callbacks import conversation_tracker as legacy_tracker_import

        legacy_tracker = legacy_tracker_import
        print("[ANALYTICS] ✓ Legacy tracker loaded", file=sys.stderr)
    except Exception as e:
        msg = f"[ANALYTICS] ✗ Failed to load Legacy tracker: {e}"
        print(msg, file=sys.stderr)
        if tracking_backend == "legacy":
            raise  # Fail if legacy-only mode can't load legacy
else:
    msg = f"[ANALYTICS] Backend mode: {tracking_backend} (SOLID only)"
    print(msg, file=sys.stderr)


# Initialize MCP Toolbox
toolbox_url = config.get("service.mcp_toolbox_url", "http://127.0.0.1:5000")
toolbox_client = ToolboxSyncClient(toolbox_url)

# Load MCP toolsets
invoice_search_tools = toolbox_client.load_toolset("gasco_invoice_search")
zip_management_tools = toolbox_client.load_toolset("gasco_zip_management")
mcp_tools = invoice_search_tools + zip_management_tools

print("ADK Agent initialized with service container", file=sys.stderr)
container.print_status()

# ================================================================
# URL Signing Tool - Agent can call this to sign gs:// URLs
# ================================================================


def generate_individual_download_links(pdf_urls: str) -> dict:
    """
    Tool that agent can call to convert gs:// URLs to signed URLs.

    Registered as ADK FunctionTool. Agent's prompt instructs it to call
    this tool when it receives gs:// URLs from other tools.

    CRITICAL: Auto-triggers ZIP creation when count > threshold

    Args:
        pdf_urls: Comma-separated string of gs:// URLs

    Returns:
        Dictionary with:
        - success: bool
        - signed_urls: list of signed HTTPS URLs (first 5 if count > threshold)
        - zip_url: str (ONLY if count > threshold) - ZIP download URL to show user
        - message: str - Message explaining what was done
        - zip_auto_created: bool - True if ZIP was created
        - original_pdf_count: int - Total number of invoices

        IMPORTANT: If zip_url is present, YOU MUST show it to the user as
        a download link for all invoices in ZIP format.
    """
    print("[TOOL] generate_individual_download_links called", file=sys.stderr)

    # Parse comma-separated URLs
    pdf_urls_list = [url.strip() for url in pdf_urls.split(",") if url.strip()]

    if not pdf_urls_list:
        return {
            "success": False,
            "error": "No se proporcionaron URLs de PDF",
            "download_urls": [],
        }

    count = len(pdf_urls_list)
    print(f"[TOOL] Processing {count} URLs", file=sys.stderr)

    # Check ZIP threshold from config
    zip_threshold = config.get("pdf.zip.threshold", 5)

    # [INTERCEPTOR AUTO-ZIP] LEGACY PATTERN (SYNCHRONOUS)
    # If count > threshold, create ZIP IMMEDIATELY and return ZIP URL
    if count > zip_threshold:
        print(f"[TOOL] Count {count} > threshold {zip_threshold}", file=sys.stderr)
        print("[TOOL] AUTO-ZIP INTERCEPTOR: Creating ZIP (SYNC)", file=sys.stderr)

        # Extract invoice numbers from gs:// URLs
        # Format: gs://bucket/descargas/{invoice_number}/filename.pdf
        invoice_numbers = []
        for url in pdf_urls_list:
            parts = url.split("/")
            if len(parts) >= 5 and parts[3] == "descargas":
                invoice_number = parts[4]
                if invoice_number not in invoice_numbers:
                    invoice_numbers.append(invoice_number)

        if not invoice_numbers:
            print("[TOOL] ERROR: No invoice numbers extracted", file=sys.stderr)
            # Fallback: sign first 5 URLs
            urls_to_sign = pdf_urls_list[:5]
        else:
            print(
                f"[TOOL] Creating ZIP for {len(invoice_numbers)} invoices (SYNC)...",
                file=sys.stderr,
            )

            try:
                # SYNCHRONOUS ZIP creation (legacy pattern)
                zip_result = create_zip_package(invoice_numbers)

                if zip_result.get("success") and zip_result.get("download_url"):
                    print(
                        f"[TOOL] ZIP created: {zip_result['download_url']}",
                        file=sys.stderr,
                    )

                    # Sign ONLY first 5 PDFs for preview
                    urls_to_sign = pdf_urls_list[:5]
                    url_signer = container.url_signer
                    signed_urls = []
                    errors = []

                    for gs_url in urls_to_sign:
                        try:
                            signed_url = url_signer.generate_signed_url(gs_url)
                            signed_urls.append(signed_url)
                            print(f"[TOOL] Signed: {gs_url[:60]}...", file=sys.stderr)
                        except Exception as e:
                            error_msg = f"Error signing {gs_url}: {str(e)}"
                            errors.append(error_msg)
                            print(f"[TOOL] {error_msg}", file=sys.stderr)

                    # Return immediately with ZIP URL + first 5 signed URLs
                    return {
                        "success": True,
                        "signed_urls": signed_urls,
                        "zip_url": zip_result["download_url"],
                        "message": f"ZIP creado con {count} facturas. "
                        f"Se muestran las primeras 5 para vista previa.",
                        "zip_auto_created": True,
                        "original_pdf_count": count,
                        "errors": errors if errors else None,
                    }
                else:
                    print(
                        f"[TOOL] ZIP failed: {zip_result.get('error')}",
                        file=sys.stderr,
                    )
                    print("[TOOL] Fallback: signing first 5 URLs", file=sys.stderr)
                    # Fallback: sign first 5 URLs
                    urls_to_sign = pdf_urls_list[:5]

            except Exception as e:
                print(f"[TOOL] ZIP exception: {str(e)}", file=sys.stderr)
                print("[TOOL] Fallback: signing first 5 URLs", file=sys.stderr)
                # Fallback: sign first 5 URLs
                urls_to_sign = pdf_urls_list[:5]
    else:
        # Below threshold: sign all URLs
        urls_to_sign = pdf_urls_list

    # Get URL signer from container
    url_signer = container.url_signer

    # Sign URLs (only first 5 if count > threshold)
    signed_urls = []
    errors = []

    for gs_url in urls_to_sign:
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
        "failed": len(errors),
    }

    if errors:
        result["errors"] = errors

    signed_count = result["signed"]
    total_count = result["total"]
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
        return {"success": True, "count": len(invoices), "invoices": invoices}
    except Exception as e:
        print(f"ERROR search_invoices_by_rut: {e}", file=sys.stderr)
        return {"success": False, "error": str(e), "count": 0, "invoices": []}


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

        # Capture ZIP metrics for conversation tracking
        zip_metrics = zip_service.get_last_zip_metrics()
        if zip_metrics:
            conversation_tracker.update_zip_metrics(zip_metrics)

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

CRITICAL INSTRUCTIONS:

1. PDF URL CONVERSION:
   When any tool returns URLs in gs:// format (like gs://bucket/file.pdf),
   you MUST call the generate_individual_download_links tool to convert them.
   
   NEVER show gs:// URLs directly to the user - always convert them first.

2. AUTO ZIP CREATION (MANDATORY):
   When a search returns more than 5 invoices:
   
   EXAMPLE: If search returns 278 invoices with gs:// URLs:
   
   Step 1: Call generate_individual_download_links with THE COMPLETE LIST:
   generate_individual_download_links(pdf_urls="gs://url1,gs://url2,...,gs://url278")
   
   DO NOT call with only 5 URLs. DO NOT truncate the list. Pass ALL 278 URLs.
   
   Step 2: The tool will automatically:
   - Detect that 278 > 5 (threshold)
   - Create a ZIP package with ALL invoices (this takes ~10 seconds)
   - Return response with:
     * signed_urls: First 5 PDF links for preview
     * zip_url: Download link for ZIP with ALL invoices
     * message: Explanation of what was done
   
   Step 3: Show to user (CRITICAL FORMAT):
   - First 5 invoices with their signed PDF links (from signed_urls)
   - ALWAYS show ZIP download link if zip_url is present in response:
     Format: "📦 Descarga todas las facturas en ZIP: [Descargar ZIP](URL_AQUI)"
     Replace URL_AQUI with the actual zip_url value from tool response
   
   IMPORTANT: If the tool returns zip_url field, YOU MUST ALWAYS show it
   to the user as a clickable download link. DO NOT ignore this field.

Always provide clear, concise responses in Spanish.
"""

# ================================================================
# Conversation Tracking Callbacks
# ================================================================


def before_agent_callback(callback_context):
    """
    Called before agent processes user query.

    Initializes conversation tracking (SOLID and/or Legacy).
    """
    # SOLID tracker (always call unless backend="legacy")
    if tracking_backend in ["solid", "dual"]:
        conversation_tracker.before_agent_callback(callback_context)

    # Legacy tracker (call if backend="legacy" or "dual")
    if tracking_backend in ["legacy", "dual"] and legacy_tracker:
        try:
            legacy_tracker.before_agent_callback(callback_context)
        except Exception as e:
            msg = f"[ANALYTICS] ✗ Legacy before_agent failed: {e}"
            print(msg, file=sys.stderr)

    return None


def after_agent_callback(callback_context):
    """
    Called after agent generates response.

    Captures tokens, response text, and triggers persistence.
    Implements dual-write with token comparison if enabled.
    """
    # Legacy tracker FIRST (backward compatibility)
    if tracking_backend in ["legacy", "dual"] and legacy_tracker:
        try:
            legacy_tracker.after_agent_callback(callback_context)
        except Exception as e:
            msg = f"[ANALYTICS] ✗ Legacy after_agent failed: {e}"
            print(msg, file=sys.stderr)

    # SOLID tracker
    if tracking_backend in ["solid", "dual"]:
        try:
            conversation_tracker.after_agent_callback(callback_context)

            # Compare tokens if dual-write mode
            compare_enabled = config.get(
                "analytics.conversation_tracking.dual_write.compare_tokens", True
            )
            if tracking_backend == "dual" and compare_enabled:
                _compare_token_counts(callback_context)

        except Exception as e:
            msg = f"[ANALYTICS] ✗ SOLID after_agent failed: {e}"
            print(msg, file=sys.stderr)
            # In dual-write, SOLID failure is not fatal
            # (Legacy already persisted)
            if tracking_backend == "solid":
                raise  # Re-raise if SOLID-only mode

    return None


def _compare_token_counts(callback_context):
    """
    Compare token counts between Legacy and SOLID trackers.

    Logs warning if difference exceeds threshold.
    """
    try:
        # Get tokens from SOLID
        solid_tokens = None
        if conversation_tracker.current_record:
            solid_tokens = (
                conversation_tracker.current_record.token_usage.total_token_count
            )

        # Get tokens from Legacy
        legacy_tokens = None
        if legacy_tracker and hasattr(legacy_tracker, "current_conversation"):
            legacy_data = legacy_tracker.current_conversation
            legacy_tokens = legacy_data.get("total_token_count")

        # Compare if both have values
        if solid_tokens is not None and legacy_tokens is not None:
            diff = abs(solid_tokens - legacy_tokens)
            threshold_key = (
                "analytics.conversation_tracking." "dual_write.token_diff_threshold"
            )
            threshold = config.get(threshold_key, 100)

            if diff > threshold:
                msg = (
                    f"[ANALYTICS] ⚠️ TOKEN MISMATCH: "
                    f"Legacy={legacy_tokens}, SOLID={solid_tokens}, "
                    f"diff={diff}"
                )
                print(msg, file=sys.stderr)
            else:
                print(
                    f"[ANALYTICS] ✓ Tokens match: {solid_tokens} " f"(diff={diff})",
                    file=sys.stderr,
                )
    except Exception as e:
        print(f"[ANALYTICS] ✗ Token comparison failed: {e}", file=sys.stderr)


# ================================================================
# Create ADK Agent
# ================================================================

# Create ADK agent with all MCP tools and conversation tracking
root_agent = Agent(
    name="gasco_invoice_assistant",
    model=vertex_model,
    description=(
        "Invoice assistant for Gasco with BigQuery access " "and PDF generation"
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
    # Register conversation tracking callbacks
    before_agent_callback=before_agent_callback,
    after_agent_callback=after_agent_callback,
)

print("ADK root_agent configured:", file=sys.stderr)
print(f"  - Model: {vertex_model}", file=sys.stderr)
print(f"  - Temperature: {vertex_temperature}", file=sys.stderr)
print(f"  - Thinking mode: {thinking_enabled}", file=sys.stderr)
print(f"  - Tools: {len(root_agent.tools)}", file=sys.stderr)
