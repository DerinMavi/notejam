# generating random password for RDS instance
resource "random_string" "rds_password" {
  length = 16
  special = false
}

# generating random string needed for unique final snapshot identifier
resource "random_string" "rds_final_snapshot" {
  length = 6
  special = false
}

# storing password as a SecureString to parameter store
resource "aws_ssm_parameter" "rds_password" {
  name  = "/${var.project}/${terraform.workspace}/rds/pass"
  type  = "SecureString"
  value = random_string.rds_password.result
}

# subnet group for rds instance
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project}-${terraform.workspace}"
  subnet_ids = [
      aws_subnet.rds_a.id,
      aws_subnet.rds_b.id
      ]
}

# rds security group
# allowing access only from ecs fargate tasks ond from inside the rds subnets
resource "aws_security_group" "rds_notejam" {
  name   = "${var.project}-${terraform.workspace}-rds-notejam"
  vpc_id = aws_vpc.notejam.id

  ingress {
    from_port = var.rds_port[terraform.workspace]
    to_port   = var.rds_port[terraform.workspace]
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = var.rds_port[terraform.workspace]
    to_port   = var.rds_port[terraform.workspace]
    protocol  = "tcp"
    security_groups = [
        aws_security_group.worker.id
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
        "0.0.0.0/0"
        ]
  }
}

# rds variables
variable "rds_database_name" { type = map(string) }
variable "rds_port" { type = map(string) }
variable "rds_master_username" { type = map(string) }
variable "rds_backup_retention_period" { type = map(string) }
variable "rds_preferred_backup_window" { type = map(string) }
variable "rds_deletion_protection" { type = map(string) }
variable "rds_storage_encrypted" { type = map(string) }
variable "rds_min_capacity" { type = map(string) }
variable "rds_max_capacity" { type = map(string) }
variable "rds_auto_pause" { type = map(string) }
variable "rds_seconds_until_auto_pause" { type = map(string) }

# rds instance
resource "aws_rds_cluster" "notejam" {
  cluster_identifier         = "${var.project}-${terraform.workspace}"
  engine                     = "aurora-mysql"
  engine_mode                = "serverless"

  storage_encrypted          = var.rds_storage_encrypted[terraform.workspace]

  master_username            = var.rds_master_username[terraform.workspace]
  master_password            = aws_ssm_parameter.rds_password.value
  database_name              = var.rds_database_name[terraform.workspace]

  backup_retention_period    = var.rds_backup_retention_period[terraform.workspace]
  preferred_backup_window    = var.rds_preferred_backup_window[terraform.workspace]
  deletion_protection        = var.rds_deletion_protection[terraform.workspace]

  skip_final_snapshot        = false
  final_snapshot_identifier  = "${var.project}-${terraform.workspace}-${random_string.rds_final_snapshot.result}"

  db_subnet_group_name       = aws_db_subnet_group.rds.name

  vpc_security_group_ids     = [ aws_security_group.rds_notejam.id ]

  scaling_configuration {
    min_capacity             = var.rds_min_capacity[terraform.workspace]
    max_capacity             = var.rds_max_capacity[terraform.workspace]
    auto_pause               = var.rds_auto_pause[terraform.workspace]
    seconds_until_auto_pause = var.rds_seconds_until_auto_pause[terraform.workspace]
  }

  lifecycle {
    ignore_changes = [
      engine_version,
    ]
  }
}
