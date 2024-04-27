data "aws_iam_policy_document" "ec2_assume_role" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "instance_role" {
  assume_role_policy  = data.aws_iam_policy_document.ec2_assume_role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_instance_profile" "instance_profile" {
  role = aws_iam_role.instance_role.id
}

resource "aws_launch_template" "launch_template" {
  image_id               = var.image_id
  instance_type          = "t4g.nano"
  vpc_security_group_ids = [aws_security_group.instance_security_group.id]
  user_data              = base64encode(file("${path.module}/init.sh"))
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance_profile.arn
  }
}

resource "aws_autoscaling_group" "asg" {
  max_size            = 4
  min_size            = 4
  vpc_zone_identifier = aws_subnet.private_subnet[*].id
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }
  target_group_arns = [
    aws_lb_target_group.application_lb_target_group.arn,
    aws_lb_target_group.network_lb_target_group.arn
  ]
}