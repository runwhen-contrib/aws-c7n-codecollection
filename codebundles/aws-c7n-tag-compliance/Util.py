from tabulate import tabulate

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
    
def generate_region_report(region, resources):
    """
    Generate a formatted report for a specific region using tabulate
    :param region: AWS region name
    :param resources: List of dictionaries containing resource details
    :return: Formatted report string
    """
    from tabulate import tabulate
    
    if not resources:
        return f"\n=== Region: {region} ===\n\nNo resources found in this region.\n"
    
    # Prepare table data
    table_data = []
    for resource in resources:
        table_data.append([
            resource.get('type', 'N/A'),
            resource.get('id', 'N/A'),
            resource.get('missing_tags', 'N/A')
        ])
    
    # Create the report
    report = f"\n=== Region: {region} ===\n\n"
    report += tabulate(table_data, 
                      headers=["Resource Type", "Resource ID", "Missing Tags"],
                      tablefmt="grid")
    return report + "\n"