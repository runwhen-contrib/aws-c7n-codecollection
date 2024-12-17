# Simple table format
"Policy Name\tResource ID\tGroup Name\tOpen Ports\tVPC ID" + 
($resources | map(
  "\n" + 
  "high-risk-security-groups\t" + 
  .GroupId + "\t" + 
  .GroupName + "\t" + 
  (.IpPermissions | map(
    if .FromPort and .ToPort then 
      "\(.FromPort)-\(.ToPort)/\(.IpProtocol)" 
    else 
      "All" 
    end
  ) | join(", ") + "\t" + 
  .VpcId
) | join(""))