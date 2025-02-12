from tabulate import tabulate
from urllib.parse import quote
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
    
def generate_aws_console_link(resource_type, resource_id, arn, region):
    """
    Generate AWS console link based on resource type and ID
    :param resource_type: AWS resource type
    :param resource_id: AWS resource ID
    :param region: AWS region
    :return: Console URL string
    """
    base_url = f"https://{region}.console.aws.amazon.com"
    resource_type = resource_type.lower()
    
    # Comprehensive resource mappings
    mappings = {
        # EC2
        "ec2": f"{base_url}/ec2/v2/home?region={region}#InstanceDetails:instanceId={resource_id}",
        "volume": f"{base_url}/ec2/v2/home?region={region}#VolumeDetails:volumeId={resource_id}",
        "snapshot": f"{base_url}/ec2/v2/home?region={region}#SnapshotDetails:snapshotId={resource_id}",
        "ami": f"{base_url}/ec2/v2/home?region={region}#ImageDetails:imageId={resource_id}",
        "security-group": f"{base_url}/ec2/v2/home?region={region}#SecurityGroup:groupId={resource_id}",
        "key-pair": f"{base_url}/ec2/v2/home?region={region}#KeyPairs:search={resource_id}",
        "vpc": f"{base_url}/vpcconsole/home?region={region}#VpcDetails:VpcId={resource_id}",
        "subnet": f"{base_url}/vpc/home?region={region}#subnets:search={resource_id}",
        "route-table": f"{base_url}/vpc/home?region={region}#RouteTables:search={resource_id}",
        "internet-gateway": f"{base_url}/vpc/home?region={region}#igws:search={resource_id}",
        "nat-gateway": f"{base_url}/vpc/home?region={region}#NatGateways:search={resource_id}",
        "vpn-gateway": f"{base_url}/vpc/home?region={region}#VpnGateways:search={resource_id}",
        "network-acl": f"{base_url}/vpc/home?region={region}#acls:search={resource_id}",
        "elastic-ip": f"{base_url}/ec2/v2/home?region={region}#Addresses:search={resource_id}",
        
        # IAM
        "iam-user": f"{base_url}/iamv2/home?region={region}#/users/details/{resource_id}",
        "iam-group": f"{base_url}/iam/home?region={region}#/groups/{resource_id}",
        "iam-role": f"{base_url}/iam/home?region={region}#/roles/{resource_id}",
        "iam-policy": f"{base_url}/iam/home?region={region}#/policies/details/{arn}?section=tags",
        
        # S3
        "s3-bucket": f"{base_url}/s3/buckets/{resource_id}?region={region}",
        
        # RDS
        "rds-instance": f"{base_url}/rds/home?region={region}#database:id={resource_id};is-cluster=false",
        "rds-cluster": f"{base_url}/rds/home?region={region}#database:id={resource_id};is-cluster=true",
        "rds-snapshot": f"{base_url}/rds/home?region={region}#snapshot:id={resource_id}",
        "rds-subnet-group": f"{base_url}/rds/home?region={region}#subnet-group-details:id={resource_id}",
        
        # Lambda
        "lambda-function": f"{base_url}/lambda/home?region={region}#/functions/{resource_id}",
        
        # CloudWatch
        "cloudwatch-alarm": f"{base_url}/cloudwatch/home?region={region}#alarms:alarmFilter=ANY;name={resource_id}",
        "cloudwatch-log-group": f"{base_url}/cloudwatch/home?region={region}#logsV2:log-groups/log-group/{resource_id.replace('/', '$252F')}",
        
        # SNS
        "sns-topic": f"{base_url}/sns/v3/home?region={region}#/topic/{resource_id}",
        
        # SQS
        "sqs-queue": f"{base_url}/sqs/v2/home?region={region}#/queues/{resource_id}",
        
        # DynamoDB
        "dynamodb-table": f"{base_url}/dynamodbv2/home?region={region}#table?name={resource_id}",
        
        # ECS
        "ecs-cluster": f"{base_url}/ecs/home?region={region}#/clusters/{resource_id}",
        # "ecs-service": f"{base_url}/ecs/home?region={region}#/services/{resource_id.split('/')[0]}/details/{resource_id.split('/')[1]}",
        "ecs-task-definition": f"{base_url}/ecs/home?region={region}#/taskDefinitions/{resource_id}",
        
        # EKS
        "eks-cluster": f"{base_url}/eks/home?region={region}#/clusters/{resource_id}",
        
        # CloudFormation
        "cloudformation-stack": f"{base_url}/cloudformation/home?region={region}#/stacks/stackinfo?stackId={resource_id}",
        
        # API Gateway
        "apigateway-rest-api": f"{base_url}/apigateway/home?region={region}#/apis/{resource_id}",
        # "apigateway-stage": f"{base_url}/apigateway/home?region={region}#/apis/{resource_id.split('/')[0]}/stages/{resource_id.split('/')[1]}",
        
        # Elastic Load Balancing
        "elb-load-balancer": f"{base_url}/ec2/v2/home?region={region}#LoadBalancers:search={resource_id}",
        "elb-target-group": f"{base_url}/ec2/v2/home?region={region}#TargetGroups:search={resource_id}",
        
        # Auto Scaling
        "autoscaling-group": f"{base_url}/ec2/autoscaling/home?region={region}#/details/{resource_id}",
        "autoscaling-launch-configuration": f"{base_url}/ec2/autoscaling/home?region={region}#/launchconfigurations/{resource_id}",
        
        # KMS
        "kms-key": f"{base_url}/kms/home?region={region}#/kms/keys/{resource_id}",
        
        # CloudTrail
        "cloudtrail-trail": f"{base_url}/cloudtrail/home?region={region}#/trails/{resource_id}",
        
        # Config
        "config-rule": f"{base_url}/config/home?region={region}#/rules/rule-details/{resource_id}",
        
        # Systems Manager
        "ssm-parameter": f"{base_url}/systems-manager/parameters/{resource_id}/description?region={region}",
        
        # Step Functions
        "stepfunctions-state-machine": f"{base_url}/states/home?region={region}#/statemachines/view/{resource_id}",
        
        # EventBridge
        "eventbridge-rule": f"{base_url}/events/home?region={region}#/rules/{resource_id}",
        
        # Default fallback
        "default": f"{base_url}/console/home?region={region}"
    }
    
    return mappings.get(resource_type.lower(), mappings["default"])

def generate_region_report(region, resources):
    """
    Generate a formatted report for a specific region using tabulate
    :param region: AWS region name
    :param resources: List of dictionaries containing resource details
    :return: Formatted report string
    """
    print("resources--", resources)
    # [{'type': 'Iam-User', 'id': 'AIDA6ELKOIOAEXKAITG7M', 'missing_tags': 'Name, Environment, Owner'}, {'type': 'Iam-Policy', 'id': 'ANPA6ELKOIOAK6MPYG6WD', 'missing_tags': 'Name, Environment, Owner'}]
    if not resources:
        return f"\n=== Region: {region} ===\n\nNo resources found in this region.\n"
    
    report = f"\n=== Region: {region} ===\n\n"
    # Prepare table data
    table_data = []
    for resource in resources:
        resource_type = resource.get('type', 'N/A').lower()
        resource_id = resource.get('id', 'N/A')
        arn = quote(resource.get('arn',''), safe='') 
        if resource_type.startswith('iam-'):  # Fixed method name
            if arn:  # Check if arn is not None or empty
                resource_id = arn.split(":")[-1].split("/")[-1]  # Extract last part
                
        console_link = generate_aws_console_link(resource_type, resource_id, arn, region)

        
        table_data.append([
            resource.get('type', 'N/A'),
            f"[{resource_id}]({console_link})" if console_link != "N/A" else resource_id,
            resource.get('missing_tags', 'N/A')
        ])
    
    # Create the report
    
    report += tabulate(table_data, 
                      headers=["Resource Type", "Resource ID", "Missing Tags"],
                      tablefmt="grid")
    return report + "\n"