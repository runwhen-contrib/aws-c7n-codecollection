import os
import json
import yaml
from pathlib import Path
from tabulate import tabulate
from jinja2 import Environment, FileSystemLoader

def parse_resource_type_from_arn(arn):
    """
    Parse resource type from ARN.
    :param arn: AWS ARN string.
    :return: Resource type or 'Unknown Type' if ARN cannot be parsed.
    """
    if not arn.startswith("arn:aws:"):
        return "Unknown Type"
    
    try:
        arn_parts = arn.split(":")
        if len(arn_parts) > 2:
            return arn_parts[2]  # The third part is the service type
    except Exception as e:
        print(f"Error parsing ARN: {e}")
    
    return "Unknown Type"



def parse_custodian_results(input_dir: str):
    """
    Parses Cloud Custodian results and summarizes resources, metadata, and run health.

    :param input_dir: Path to the root directory containing Cloud Custodian output files.
    :return: A string summary of the results in tabular format or a message if no results found.
    """
    input_path = Path(input_dir)

    if not input_path.exists():
        return f"Input directory does not exist: {input_dir}"

    if not input_path.is_dir():
        return f"Input path is not a directory: {input_dir}"

    # Initialize data structures for report
    resource_summary = []
    policy_summary = []
    log_summary = []

    # Recursively traverse subdirectories
    for subdir in input_path.iterdir():
        if subdir.is_dir():
            resources_file = subdir / "resources.json"
            metadata_file = subdir / "metadata.json"
            log_file = subdir / "custodian-run.log"

            # Parse resources.json
            if resources_file.exists():
                try:
                    with open(resources_file, "r") as f:
                        resources = json.load(f)
                        if not isinstance(resources, list):
                            print(f"Skipping {resources_file}: Expected a list of resources.")
                            continue

                        for resource in resources:
                            if not isinstance(resource, dict):
                                print(f"Skipping malformed resource in {resources_file}: {resource}")
                                continue

                            # Resource attributes
                            resource_name = resource.get("Name", "Unknown Name")

                            # Extract the ARN
                            policy_raw = resource.get("Policy", None)
                            if isinstance(policy_raw, str):
                                try:
                                    policy = json.loads(policy_raw)
                                    arn = policy.get("Statement", [])[0].get("Resource", "Unknown ARN")
                                except json.JSONDecodeError:
                                    arn = "Unknown ARN (Invalid Policy)"
                            else:
                                arn = "Unknown ARN"

                            # Use the fixed ARN parsing function
                            resource_type = parse_resource_type_from_arn(arn)
                            resource_location = resource.get("Location", {}).get("LocationConstraint", "Unknown Location")

                            # Tags
                            tags = resource.get("Tags", [])
                            if isinstance(tags, list):
                                tags_str = ", ".join(f"{tag.get('Key', 'Unknown')}={tag.get('Value', 'Unknown')}" for tag in tags)
                            else:
                                tags_str = "Unknown Tags"

                            # Public Access Block
                            public_access_block = resource.get("c7n:PublicAccessBlock", {})
                            public_access = public_access_block.get("BlockPublicPolicy", "Unknown")

                            # Append to resource summary
                            resource_summary.append([
                                subdir.name,  # Policy name
                                resource_name,
                                resource_type,
                                resource_location,
                                tags_str,
                                public_access
                            ])
                except json.JSONDecodeError:
                    print(f"Error reading resources.json in {subdir}: Invalid JSON format.")
                except Exception as e:
                    print(f"Error reading resources.json in {subdir}: {e}")


                    
            # Parse metadata.json
            if metadata_file.exists():
                try:
                    with open(metadata_file, "r") as f:
                        metadata = json.load(f)
                        policy = metadata.get("policy", {})
                        policy_name = policy.get("name", "Unknown Policy")
                        
                        # Extract metrics timestamps for start and end time
                        metrics = metadata.get("metrics", [])
                        if metrics:
                            timestamps = [m.get("Timestamp") for m in metrics if m.get("Timestamp")]
                            start_time = min(timestamps) if timestamps else "Unknown Start Time"
                            end_time = max(timestamps) if timestamps else "Unknown End Time"
                        else:
                            start_time = "Unknown Start Time"
                            end_time = "Unknown End Time"

                        # Add to policy summary
                        policy_summary.append([policy_name, start_time, end_time])
                except Exception as e:
                    print(f"Error reading metadata.json in {subdir}: {e}")

            # Parse custodian-run.log
            if log_file.exists():
                try:
                    with open(log_file, "r") as f:
                        logs = f.readlines()
                        error_count = sum(1 for line in logs if "ERROR" in line)
                        warning_count = sum(1 for line in logs if "WARNING" in line)
                        log_summary.append([subdir.name, error_count, warning_count])
                except Exception as e:
                    print(f"Error reading custodian-run.log in {subdir}: {e}")

    # Generate combined summary
    results = []

    if resource_summary:
        results.append("Resource Summary:")
        results.append(tabulate(resource_summary, headers=[
            "Policy Name", "Resource Name", "Resource Type", "Location", "Tags", "Public Access Blocked"
        ], tablefmt="grid"))

    if policy_summary:
        results.append("\nPolicy Summary:")
        results.append(tabulate(policy_summary, headers=["Policy Name", "Start Time", "End Time"], tablefmt="grid"))

    if log_summary:
        results.append("\nRun Health Summary:")
        results.append(tabulate(log_summary, headers=["Policy Name", "Errors", "Warnings"], tablefmt="grid"))

    if not results:
        return "No valid results found in the specified directory."

    return "\n".join(results)



def parse_ebs_results(input_dir: str):
    input_path = Path(input_dir)

    if not input_path.exists():
        return f"Input directory does not exist: {input_dir}"

    if not input_path.is_dir():
        return f"Input path is not a directory: {input_dir}"

    # Initialize data structures for report
    resource_summary = []
    policy_summary = []
    log_summary = []

    # Recursively traverse subdirectories
    for subdir in input_path.iterdir():
        if subdir.is_dir():
            resources_file = subdir / "resources.json"
            metadata_file = subdir / "metadata.json"
            log_file = subdir / "custodian-run.log"

            # Parse resources.json
            if resources_file.exists():
                try:
                    with open(resources_file, "r") as f:
                        resources = json.load(f)
                        if not isinstance(resources, list):
                            print(f"Skipping {resources_file}: Expected a list of resources.")
                            continue

                        for resource in resources:
                            if not isinstance(resource, dict):
                                print(f"Skipping malformed resource in {resources_file}: {resource}")
                                continue

                            resource_id = ""
                            resource_type = ""
                            if "VolumeType" in resource:
                                resource_type = "EBS volume"
                                resource_id = resource.get("VolumeId", "Unknown ID")
                            elif "SnapshotId" in resource:
                                resource_type = "EBS snapshot"
                                resource_id = resource.get("SnapshotId", "Unknown ID")
                            elif "InstanceId" in resource:
                                resource_type = "EC2 Instance"
                                resource_id = resource.get("InstanceId", "Unknown ID")
                                
                            Id = [id for id in resource.keys() if "id" in id.lower()]
                            resource_location = find_value_recursive(resource, 'AvailabilityZone')[0][:-1]
                            tags = resource.get("Tags", [])
                            if isinstance(tags, list):
                                tags_str = ", ".join(f"{tag.get('Key', 'Unknown')}={tag.get('Value', 'Unknown')}" for tag in tags)
                            else:
                                tags_str = "Unknown Tags"

                            # Append to resource summary
                            resource_summary.append([
                                subdir.name,  # Policy name
                                resource_id,
                                resource_type,
                                resource_location,
                                tags_str
                            ])
                except json.JSONDecodeError:
                    print(f"Error reading resources.json in {subdir}: Invalid JSON format.")
                except Exception as e:
                    print(f"Error reading resources.json in {subdir}: {e}")

            # Parse metadata.json
            if metadata_file.exists():
                try:
                    with open(metadata_file, "r") as f:
                        metadata = json.load(f)
                        policy = metadata.get("policy", {})
                        policy_name = policy.get("name", "Unknown Policy")
                        
                        # Extract metrics timestamps for start and end time
                        metrics = metadata.get("metrics", [])
                        if metrics:
                            timestamps = [m.get("Timestamp") for m in metrics if m.get("Timestamp")]
                            start_time = min(timestamps) if timestamps else "Unknown Start Time"
                            end_time = max(timestamps) if timestamps else "Unknown End Time"
                        else:
                            start_time = "Unknown Start Time"
                            end_time = "Unknown End Time"

                        # Add to policy summary
                        policy_summary.append([policy_name, start_time, end_time])
                except Exception as e:
                    print(f"Error reading metadata.json in {subdir}: {e}")

            # Parse custodian-run.log
            if log_file.exists():
                try:
                    with open(log_file, "r") as f:
                        logs = f.readlines()
                        error_count = sum(1 for line in logs if "ERROR" in line)
                        warning_count = sum(1 for line in logs if "WARNING" in line)
                        log_summary.append([subdir.name, error_count, warning_count])
                except Exception as e:
                    print(f"Error reading custodian-run.log in {subdir}: {e}")


    results = []

    if resource_summary:
        results.append("Resource Summary:")
        results.append(tabulate(resource_summary, headers=[
            "Policy Name", "Resource ID", "Resource Type", "Location", "Tags"
        ], tablefmt="grid"))

    if policy_summary:
        results.append("\nPolicy Summary:")
        results.append(tabulate(policy_summary, headers=["Policy Name", "Start Time", "End Time"], tablefmt="grid"))

    if log_summary:
        results.append("\nRun Health Summary:")
        results.append(tabulate(log_summary, headers=["Policy Name", "Errors", "Warnings"], tablefmt="grid"))

    if not results:
        return "No valid results found in the specified directory."

    return "\n".join(results)

def find_value_recursive(obj, target_key):
    """
    Recursively search for a key in a nested dictionary or list.
    Returns all matching values found.
    """
    results = []
    
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key == target_key:
                results.append(value)
            
            # Recursively search nested dictionaries and lists
            if isinstance(value, (dict, list)):
                results.extend(find_value_recursive(value, target_key))
    
    elif isinstance(obj, list):
        for item in obj:
            if isinstance(item, (dict, list)):
                results.extend(find_value_recursive(item, target_key))
    
    return results

def generate_policy(template_path, **kargs):

    if not os.path.isfile(template_path):
        raise FileNotFoundError(f"Template file not found: {template_path}")
        exit

    template_dir    = os.path.dirname(template_path)
    template_file   = os.path.split(template_path)[-1]
    jinja_env       = Environment(loader=FileSystemLoader(template_dir))

    if "tags" in kargs and kargs["tags"] != "" :
        kargs["tags"] = kargs["tags"].replace(" ","").split(",")
    else:
        kargs["tags"] = []

    if "resource_providers" in kargs and kargs["resource_providers"] != "" :
        kargs["resource_providers"] = kargs["resource_providers"].replace(" ","").split(",")
    else:
        kargs["resource_providers"] = []

    try:
        template = jinja_env.get_template(template_file)
    except Exception as e:
        print(f"Error loading template: {e}")

    try:
        rendered_policy = template.render(kargs)
        policy_file_path = os.path.join(template_dir, f'{template_file.split(".")[0]}.yaml')

        with open(policy_file_path, 'w') as output_file:
            output_file.write(rendered_policy)
    except Exception as e:
        print(f"Error rendering template: {e}")