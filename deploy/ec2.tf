resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# verify:
# aws iam list-attached-role-policies --role-name ec2-ssm-role

# This instance profile allows EC2 instances to assume the IAM role we just created.
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}


resource "aws_security_group" "ec2_ssm_sg" {
  name        = "${local.prefix}-ec2-ssm-sg"
  description = "SSM box security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-ec2-ssm-sg"
  }
}

# required for SSM to communicate with the instance, 
# and for the instance to access the internet for updates and SSM agent communication.
resource "aws_vpc_security_group_egress_rule" "ec2_https_out" {
  security_group_id = aws_security_group.ec2_ssm_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_http_out" {
  security_group_id = aws_security_group.ec2_ssm_sg.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_rds_postgres" {
  security_group_id            = aws_security_group.ec2_ssm_sg.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.rds_postgres.id
}

# EC2 instance to test SSM connectivity
resource "aws_instance" "ssm_box" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private["private_1"].id
  vpc_security_group_ids = [aws_security_group.ec2_ssm_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data_replace_on_change = true

  #   user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "${local.prefix}-ssm-box"
  }
}

# This policy allows the EC2 instance to read the RDS credentials from Secrets Manager, 
#which is necessary for our SSM box to connect to the RDS instance and run tests.
resource "aws_iam_role_policy" "ec2_read_rds_secret" {
  name = "${local.prefix}-ec2-read-rds-secret"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = local.postgres_instance.master_user_secret[0].secret_arn
      }
    ]
  })
}
