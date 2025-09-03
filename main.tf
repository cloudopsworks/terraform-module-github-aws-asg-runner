##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  function_name       = "github-runner-${local.system_name}"
  function_name_short = "github-runner-${local.system_name_short}"
  variables = concat(try(var.settings.environment.variables, []),
    [
      {
        name  = "WEBHOOK_SECRET"
        value = local.secretb64
      },
      {
        name  = "GITHUB_APP_SECRET_NAME"
        value = try(var.settings.github_app_secret_name, "/organization/github/app")
      },
    ],
    [
    ]
  )
}

resource "archive_file" "lambda_code" {
  output_path = "${path.module}/.archive/${local.function_name_short}.zip"
  type        = "zip"
  source_dir  = "${path.module}/lambda_code/"
}

resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  description      = try(var.settings.description, "Bastion Access Control Lambda - Region: ${data.aws_region.current.id}")
  role             = aws_iam_role.default_lambda_function.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "nodejs22.x"
  package_type     = "Zip"
  filename         = archive_file.lambda_code.output_path
  source_code_hash = archive_file.lambda_code.output_base64sha256
  memory_size      = try(var.settings.memory_size, 128)
  timeout          = try(var.settings.timeout, 120)
  publish          = true
  environment {
    variables = {
      for item in local.variables :
      item.name => item.value
    }
  }
  logging_config {
    application_log_level = try(var.settings.logging.application_log_level, null)
    log_format            = try(var.settings.logging.log_format, "JSON")
    log_group             = aws_cloudwatch_log_group.logs.name
    system_log_level      = try(var.settings.logging.system_log_level, null)
  }
  tags = local.all_tags
  depends_on = [
    aws_cloudwatch_log_group.logs,
    archive_file.lambda_code
  ]
  layers = [
    aws_lambda_layer_version.octokit.arn
  ]
}

resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"
}

resource "terraform_data" "octokit" {
  input = timestamp()
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/lambda_layers/nodejs/node_modules/ && cd ${path.module}/lambda_layers/nodejs/node_modules && npm install @octokit/app @octokit/rest"
  }
  provisioner "local-exec" {
    command = "cd ${path.module}/lambda_layers/ && zip -qr /tmp/octokit-layer.zip nodejs"
  }
  triggers_replace = {
    always_run = timestamp()
  }
}

resource "aws_lambda_layer_version" "octokit" {
  skip_destroy             = true
  layer_name               = "octokit-layer-${local.system_name_short}"
  description              = "Lambda Layer for Octokit - ${local.system_name}"
  filename                 = "/tmp/octokit-layer.zip"
  source_code_hash         = filebase64sha256("/tmp/octokit-layer.zip")
  license_info             = "Apache-2.0"
  compatible_runtimes      = ["nodejs20.x", "nodejs22.x"]
  compatible_architectures = ["x86_64"]
  depends_on               = [terraform_data.octokit]
}
