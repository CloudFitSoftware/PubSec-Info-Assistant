import os

# Check if a path exists
def does_path_exist(subdirectory_path: str) -> bool:
    """ Check if a path exists
    Args:
        subdirectory_path (str): The path to check
    Returns:
        bool: True if the path exists, False otherwise
    """
    return os.path.exists(subdirectory_path)

# Function to ensure that a path exists
# If the path doesn't exist, it will be created
def ensure_path_exists(subdirectory_path: str): 
    """ Ensure that a path exists
    If the path doesn't exist, it will be created
    Args:
        subdirectory_path (str): The path to check
    """ 
    # Check if the subdirectory exists
    if not os.path.exists(subdirectory_path):
        # If it doesn't exist, create it
        os.makedirs(subdirectory_path)
        print(f"Created subdirectory: {subdirectory_path}")
    else:
        print(f"Subdirectory already exists: {subdirectory_path}")
        