resource "aws_db_instance" "instance" {
  count                  = var.rds_port > 0 ? 1 : 0
  identifier             = "${var.name}-db"
  allocated_storage      = 20
  db_name                = var.name
  engine                 = "postgres"
  engine_version         = "16.1"
  instance_class         = "db.t4g.micro"
  username               = var.username
  password               = var.password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds[count.index].id]
  db_subnet_group_name   = aws_db_subnet_group.group[count.index].name
  multi_az               = false
}

resource "aws_db_subnet_group" "group" {
  count      = var.rds_port > 0 ? 1 : 0
  name       = "${var.name}_subnet_group"
  subnet_ids = [aws_subnet.subnet_c[count.index].id, aws_subnet.subnet_d[count.index].id]

  tags = {
    Name = "${var.name}"
  }
}
