def generate_resource_id_mappings(mapping_str: str) -> dict:
    """Convert a mapping string to a dictionary.
    
    Args:
        mapping_str: String in format "resource1=id1,resource2=id2"
        
    Returns:
        Dict mapping resources to their ID fields
    """
    try:
        # Split the string into key-value pairs
        pairs = [pair.strip() for pair in mapping_str.split(',')]
        
        # Convert to dictionary
        mapping_dict = {}
        for pair in pairs:
            resource, id_field = pair.split('=')
            mapping_dict[resource.strip()] = id_field.strip()
            
        return mapping_dict
        
    except ValueError as e:
        print(f"Error parsing mapping string: {e}")
        print("Expected format: 'resource1=id1,resource2=id2'")
        return {}