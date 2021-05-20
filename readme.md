# SPA on AWS

Módulo do Terraform para hospedar sites estáticos (SPA) utilizando a infraestrutura da Amazon (AWS).

## Configurações

É necessário configurar as credencias da AWS e do GitHub, para tanto utilize as seguintes:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `GITHUB_TOKEN`

## Argumentos

- `name`
- `area`
- `domain`
- `aws_region`
- `aws_route53_zone_id`
- `github_owner`
- `github_repository`
- `environments`
