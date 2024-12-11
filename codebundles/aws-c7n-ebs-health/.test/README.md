### AWS IAM policy for running this codebundle:

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "VisualEditor0",
			"Effect": "Allow",
			"Action": [
				"ec2:DescribeImages",
				"ec2:DescribeInstances",
				"ec2:DescribeVolumeStatus",
				"ec2:DescribeTags",
				"autoscaling:DescribeAutoScalingGroups",
				"ec2:DescribeRegions",
				"ec2:DescribeVolumes",
				"autoscaling:DescribeTags",
				"autoscaling:DescribeLaunchConfigurations",
				"ec2:DescribeSnapshots",
				"ec2:DescribeVolumeAttribute"
			],
			"Resource": "*"
		}
	]
}
```