import re
import json
from tabulate import tabulate

def usage_table(resource_file_path):
    # Load JSON data from file
    print(resource_file_path)
    try:
        # Attempt to open and read the log file
        with open(resource_file_path, 'r') as file:
            data = json.load(file)
    except FileNotFoundError:
        return f"Error: The file '{resource_file_path}' was not found."
    except PermissionError:
        return f"Error: Permission denied when trying to read '{resource_file}'."
    except Exception as e:
        return f"An unexpected error occurred while reading the file: {e}"

    # Define table headers
    headers = ["ServiceName", "QuotaName", "Usage", "Quota", "UsagePercentage", "MetricName", "Period"]
    
    # Prepare table rows
    table = []
    for item in data:
        service_name = item.get("ServiceName", "N/A")
        quota_name = item.get("QuotaName", "N/A")
        usage = item.get("c7n:UsageMetric", {}).get("metric", 0)
        quota = item.get("c7n:UsageMetric", {}).get("quota", 1)  # Avoid division by zero
        usage_percentage = round((usage / quota) * 100, 2) if quota else 0
        metric_name = item.get("UsageMetric", {}).get("MetricName", "N/A")
        period_value = item.get("Period", {}).get("PeriodValue", "N/A")
        period_unit = item.get("Period", {}).get("PeriodUnit", "N/A")
        period = f"{period_value} {period_unit}"
        
        table.append([service_name, quota_name, usage, quota, f"{usage_percentage}%", metric_name, period])
    
    # Print the table
    return tabulate(table, headers=headers, tablefmt="grid")

# e.g aws usage logs 
    # "2025-02-06 06:27:33,611: custodian.filters:INFO Amazon Elastic Compute Cloud (Amazon EC2) Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances usage: 2.0/512.0",
    # "2025-02-06 06:28:05,175: custodian.filters:INFO Elastic Load Balancing (ELB) Targets per Network Load Balancer usage: 0.0/3000.0",
    # "2025-02-06 06:32:00,460: custodian.filters:INFO Amazon CloudWatch Rate of GetMetricStatistics requests usage: 0.37/400.0",
    # "2025-02-06 06:28:01,668: custodian.filters:INFO Elastic Load Balancing (ELB) Targets per Availability Zone per Network Load Balancer usage: 0.0/500.0",
    # "2025-02-06 06:28:04,540: custodian.filters:INFO Elastic Load Balancing (ELB) Classic Load Balancers per Region usage: 0.0/20.0",
    # "2025-02-06 06:28:05,175: custodian.filters:INFO Elastic Load Balancing (ELB) Targets per Network Load Balancer usage: 0.0/3000.0",
    # "2025-02-06 06:28:06,787: custodian.filters:INFO Elastic Load Balancing (ELB) Listeners per Network Load Balancer usage: 0.0/50.0", 
    # "2025-02-06 06:28:05,969: custodian.filters:INFO Elastic Load Balancing (ELB) Target Groups per Region usage: 0.0/3000.0",    
    # "2025-02-06 06:28:07,590: custodian.filters:INFO Elastic Load Balancing (ELB) Targets per Target Group per Region usage: 0.0/1000.0",
    # "2025-02-06 06:28:08,426: custodian.filters:INFO Elastic Load Balancing (ELB) Targets per Application Load Balancer usage: 0.0/1000.0",
    # "2025-02-06 06:28:09,248: custodian.filters:INFO Elastic Load Balancing (ELB) Application Load Balancers per Region usage: 0.0/50.0",
    # "2025-02-06 06:28:10,064: custodian.filters:INFO Elastic Load Balancing (ELB) Network Load Balancers per Region usage: 0.0/50.0",
    # "2025-02-06 06:28:10,864: custodian.filters:INFO Elastic Load Balancing (ELB) Registered Instances per Classic Load Balancer usage: 0.0/1000.0",
    # "2025-02-06 06:28:43,856: custodian.filters:INFO Amazon EMR The maximum number of ListSecurityConfigurations API requests that you can make per second. usage: 0.0/5.0",
    # "2025-02-06 06:28:46,315: custodian.filters:INFO Amazon EventBridge (CloudWatch Events) Invocations throttle limit in transactions per second usage: 0.05/18750.0",
    # "2025-02-06 06:28:52,341: custodian.filters:INFO Amazon Kinesis Data Firehose Rate of ListDeliveryStream requests usage: 1.0/5.0",
    # "2025-02-06 06:30:26,459: custodian.filters:INFO AWS Key Management Service (AWS KMS) ListKeys request rate usage: 0.0/500.0",
    # "2025-02-06 06:30:40,805: custodian.filters:INFO AWS Key Management Service (AWS KMS) GetKeyPolicy request rate usage: 0.01/1000.0",
    # "2025-02-06 06:30:41,863: custodian.filters:INFO AWS Key Management Service (AWS KMS) ListAliases request rate usage: 0.0/500.0",
    # "2025-02-06 06:30:54,569: custodian.filters:INFO AWS Key Management Service (AWS KMS) Customer Master Keys (CMKs) usage: 2.0/100000.0",
    # "2025-02-06 06:30:57,280: custodian.filters:INFO AWS Key Management Service (AWS KMS) Cryptographic operations (symmetric) request rate usage: 0.01/100000.0",
    # "2025-02-06 06:31:03,602: custodian.filters:INFO AWS Key Management Service (AWS KMS) DescribeKey request rate usage: 0.01/2000.0",
    # "2025-02-06 06:31:07,009: custodian.filters:INFO AWS Lambda Concurrent executions usage: 1.0/1000.0",
    # "2025-02-06 06:31:17,046: custodian.filters:INFO Amazon CloudWatch Logs DescribeLogGroups throttle limit in transactions per second usage: 0.0/10.0",
    # "2025-02-06 06:31:20,730: custodian.filters:INFO Amazon CloudWatch Logs CreateLogStream throttle limit in transactions per second usage: 0.01/50.0",
    # "2025-02-06 06:31:29,270: custodian.filters:INFO Amazon CloudWatch Logs DescribeDestinations throttle limit in transactions per second usage: 0.0/5.0",
    # "2025-02-06 06:31:29,771: custodian.filters:INFO Amazon CloudWatch Logs PutLogEvents throttle limit in transactions per second usage: 0.03/5000.0",
    # "2025-02-06 06:31:30,934: custodian.filters:INFO Amazon CloudWatch Logs DescribeMetricFilters throttle limit in transactions per second usage: 0.01/5.0"
