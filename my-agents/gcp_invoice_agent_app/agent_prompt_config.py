"""
Agent Prompt Configuration Loader
==================================

This module provides utilities to load and use the structured YAML prompt
configuration for the Invoice PDF Finder Agent.

Usage:
    from agent_prompt_config import AgentPromptConfig
    
    config = AgentPromptConfig()
    instructions = config.get_system_instructions()
    tools_info = config.get_tools_description()

Author: Invoice Chatbot Backend Team
Date: September 8, 2025
"""

import yaml
import os
from pathlib import Path
from typing import Dict, Any, List, Optional


class AgentPromptConfig:
    """
    Loads and provides access to the agent prompt configuration from YAML
    """
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize the configuration loader
        
        Args:
            config_path: Path to the YAML configuration file. 
                        If None, looks for agent_prompt.yaml in the same directory.
        """
        if config_path is None:
            config_path = Path(__file__).parent / "agent_prompt.yaml"
        
        self.config_path = Path(config_path)
        self._config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """Load the YAML configuration file"""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as file:
                return yaml.safe_load(file)
        except FileNotFoundError:
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
        except yaml.YAMLError as e:
            raise ValueError(f"Invalid YAML configuration: {e}")
    
    def get_system_instructions(self) -> str:
        """Get the main system instructions for the agent"""
        return self._config.get('system_instructions', '')
    
    def get_agent_config(self) -> Dict[str, Any]:
        """Get basic agent configuration (name, model, description)"""
        return self._config.get('agent_config', {})
    
    def get_tools_description(self) -> Dict[str, Any]:
        """Get the tools description and configuration"""
        return self._config.get('tools_description', {})
    
    def get_url_handling_rules(self) -> Dict[str, Any]:
        """Get URL handling and validation rules"""
        return self._config.get('url_handling_rules', {})
    
    def get_error_handling(self) -> Dict[str, Any]:
        """Get error handling patterns and procedures"""
        return self._config.get('error_handling', {})
    
    def get_data_sources(self) -> Dict[str, Any]:
        """Get data sources and project configuration"""
        return self._config.get('data_sources', {})
    
    def get_response_formats(self) -> Dict[str, Any]:
        """Get response format templates"""
        return self._config.get('response_formats', {})
    
    def get_conversation_tracking(self) -> Dict[str, Any]:
        """Get conversation tracking and logging configuration"""
        return self._config.get('conversation_tracking', {})
    
    def get_configuration_constants(self) -> Dict[str, Any]:
        """Get configuration constants (thresholds, ports, etc.)"""
        return self._config.get('configuration', {})
    
    def get_statistics_rules(self) -> Dict[str, Any]:
        """Get business intelligence and statistics rules"""
        return self._config.get('statistics_rules', {})
    
    def get_usage_examples(self) -> Dict[str, Any]:
        """Get examples of valid user queries and expected tool usage"""
        return self._config.get('usage_examples', {})
    
    def get_security_configuration(self) -> Dict[str, Any]:
        """Get security and authentication configuration"""
        return self._config.get('security_configuration', {})
    
    def get_environment_config(self) -> Dict[str, Any]:
        """Get environment-specific configuration"""
        return self._config.get('environment', {})
    
    def get_testing_compatibility(self) -> Dict[str, Any]:
        """Get testing compatibility requirements"""
        return self._config.get('testing_compatibility', {})
    
    def get_zip_threshold(self) -> int:
        """Get the ZIP threshold value"""
        config = self.get_configuration_constants()
        return config.get('thresholds', {}).get('ZIP_THRESHOLD', 5)
    
    def get_mcp_tools_list(self) -> List[str]:
        """Get list of available MCP tools"""
        tools_desc = self.get_tools_description()
        mcp_tools = tools_desc.get('mcp_tools', {})
        
        all_tools = []
        for toolset_name, toolset_info in mcp_tools.items():
            if 'tools' in toolset_info:
                all_tools.extend(toolset_info['tools'])
        
        return all_tools
    
    def get_custom_tools_list(self) -> List[str]:
        """Get list of custom tools defined in the agent"""
        tools_desc = self.get_tools_description()
        custom_tools = tools_desc.get('custom_tools', {})
        return list(custom_tools.keys())
    
    def format_response_template(self, template_type: str, **kwargs) -> str:
        """
        Format a response template with provided variables
        
        Args:
            template_type: Type of template (e.g., 'search_results_summary')
            **kwargs: Variables to substitute in the template
        
        Returns:
            Formatted template string
        """
        formats = self.get_response_formats()
        template = formats.get(template_type, {}).get('format', '')
        
        try:
            return template.format(**kwargs)
        except KeyError as e:
            raise ValueError(f"Missing template variable: {e}")
    
    def validate_tool_usage(self, query: str) -> Dict[str, Any]:
        """
        Suggest appropriate tools based on query patterns
        
        Args:
            query: User query string
        
        Returns:
            Dictionary with suggested tools and parameters
        """
        query_lower = query.lower()
        examples = self.get_usage_examples()
        
        suggestions = []
        
        # Check against usage examples
        for example_type, example_data in examples.items():
            example_query = example_data.get('query', '').lower()
            
            # Simple keyword matching (could be enhanced with NLP)
            if any(keyword in query_lower for keyword in example_query.split()):
                suggestions.append({
                    'type': example_type,
                    'tool': example_data.get('expected_tool'),
                    'parameters': example_data.get('parameters', {}),
                    'confidence': 'medium'  # Could be calculated more sophisticated
                })
        
        return {
            'suggestions': suggestions,
            'query_analyzed': query,
            'available_tools': self.get_mcp_tools_list() + self.get_custom_tools_list()
        }
    
    def get_full_config(self) -> Dict[str, Any]:
        """Get the complete configuration dictionary"""
        return self._config.copy()
    
    def __str__(self) -> str:
        """String representation of the configuration"""
        agent_config = self.get_agent_config()
        return f"AgentPromptConfig(name={agent_config.get('name', 'N/A')}, " \
               f"model={agent_config.get('model', 'N/A')}, " \
               f"config_path={self.config_path})"
    
    def __repr__(self) -> str:
        return self.__str__()


# Convenience functions for quick access
def load_system_instructions(config_path: Optional[str] = None) -> str:
    """Quick function to load just the system instructions"""
    config = AgentPromptConfig(config_path)
    return config.get_system_instructions()


def load_agent_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """Quick function to load just the agent configuration"""
    config = AgentPromptConfig(config_path)
    return config.get_agent_config()


def get_zip_threshold(config_path: Optional[str] = None) -> int:
    """Quick function to get the ZIP threshold"""
    config = AgentPromptConfig(config_path)
    return config.get_zip_threshold()


if __name__ == "__main__":
    # Test the configuration loader
    try:
        config = AgentPromptConfig()
        print("✅ Configuration loaded successfully")
        print(f"📊 Agent: {config.get_agent_config().get('name', 'N/A')}")
        print(f"🤖 Model: {config.get_agent_config().get('model', 'N/A')}")
        print(f"🔧 MCP Tools: {len(config.get_mcp_tools_list())}")
        print(f"🛠️ Custom Tools: {len(config.get_custom_tools_list())}")
        print(f"📦 ZIP Threshold: {config.get_zip_threshold()}")
        
        # Test template formatting
        template = config.format_response_template(
            'search_results_summary',
            count=10,
            start_date='2019-12-01',
            end_date='2019-12-31',
            search_criteria='RUT y fecha'
        )
        print(f"📝 Template test: {template[:50]}...")
        
    except Exception as e:
        print(f"❌ Error loading configuration: {e}")