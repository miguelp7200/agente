"""
ADK Agent Entry Point
=====================
Minimal wrapper that imports the SOLID-refactored agent.

This file is the entry point for ADK api_server.
All business logic is in src/ following Clean Architecture.

Note: Legacy architecture (deprecated/legacy/) was removed in Nov 2025.
      Archive available in branch: archive/legacy-pre-deprecation
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

print("=" * 60, file=sys.stderr)
print("Invoice Agent - Clean Architecture + SOLID", file=sys.stderr)
print("=" * 60 + "\n", file=sys.stderr)

# Import SOLID-refactored agent
from src.presentation.agent.adk_agent import root_agent

# Export root_agent for ADK api_server
__all__ = ["root_agent"]
