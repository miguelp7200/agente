"""
ADK Agent Entry Point - SOLID Refactored
=========================================
Minimal wrapper that imports the refactored agent.

This file is the entry point for ADK api_server.
All business logic has been moved to src/ following Clean Architecture.

Legacy code moved to: deprecated/legacy/agent_legacy.py
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Check for legacy mode feature flag
from src.core.config import get_config

config = get_config()
use_legacy = config.get("features.use_legacy_architecture", False)

if use_legacy:
    print("=" * 60, file=sys.stderr)
    print("WARNING: Using LEGACY architecture (deprecated)", file=sys.stderr)
    print(
        "  Set features.use_legacy_architecture=false to use refactored code",
        file=sys.stderr,
    )
    print("=" * 60 + "\n", file=sys.stderr)

    # Import legacy agent from deprecated/
    sys.path.insert(0, str(project_root / "deprecated" / "legacy"))
    from agent_legacy import root_agent
else:
    print("=" * 60, file=sys.stderr)
    print("Using REFACTORED architecture (Clean Architecture + SOLID)", file=sys.stderr)
    print(
        "  Legacy fallback available via features.use_legacy_architecture=true",
        file=sys.stderr,
    )
    print("=" * 60 + "\n", file=sys.stderr)

    # Import refactored agent
    from src.presentation.agent.adk_agent import root_agent

# Export root_agent for ADK api_server
__all__ = ["root_agent"]
