"""
Utility functions for configuration management.
"""
import os

def get_env(name: str) -> str:
    """Get an environment variable and raise an error if it's missing."""
    value = os.getenv(name)

    if not value:
        raise ValueError(
            f"Environment variable '{name}' is missing"
        )

    return value
