
# Documento de trust policy: permite que o servico Lambda assuma a role via STS.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Role de execucao da Lambda que recebera as permissoes operacionais.
resource "aws_iam_role" "lambda_exec" {
  name               = "create-order-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Policy de permissoes da Lambda (logs e acesso ao DynamoDB).
data "aws_iam_policy_document" "lambda_permissions" {
  # Permissoes para gravar logs no CloudWatch Logs.
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  # Permissoes de leitura/escrita no DynamoDB para operacoes comuns da funcao.
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:ConditionCheckItem"
    ]
    resources = ["*"]
  }

  # Permissoes necessarias para Lambda em VPC criar/gerenciar interfaces de rede (ENI).
  statement {
    sid    = "VpcNetworkInterfaceAccess"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
}

# Anexa a policy de permissoes na role de execucao da Lambda.
resource "aws_iam_role_policy" "lambda_policy" {
  name   = "create-order-lambda-policy"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_permissions.json
}

# Cria a funcao Lambda e associa a role IAM com as permissoes definidas acima.
resource "aws_lambda_function" "example" {
  filename      = "${path.module}/../dist/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../dist/function.zip")
  function_name = "create-order-function"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "app.index.lambda_handler"
  runtime       = "python3.12"
  memory_size   = 256
  timeout       = 29
  architectures = ["arm64"]

  # Reaproveita configuracao de VPC de uma Lambda de referencia.
  vpc_config {
    subnet_ids         = ["subnet-0c12b4150f7e3e976"]
    security_group_ids = ["sg-025c0770e6fef28d5"]
  }
}

# Permissao resource-based na Lambda para permitir invocacao pelo API Gateway.
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "apigateway.amazonaws.com"
}