resource "aws_dynamodb_table" "order-table" {
  name           = "OrderTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "OrderId"

  attribute {
    name = "OrderId"
    type = "S"
  }

  attribute {
    name = "CustomerId"
    type = "S"
  }

  attribute {
    name = "OrderDate"
    type = "S"
  }

  global_secondary_index {
    name            = "CustomerIdIndex"
    hash_key        = "CustomerId"
    range_key       = "OrderDate"
    projection_type = "ALL"
  }

  tags = {
    Name        = "OrderTable"
    Environment = "dev"
  }
}