# hello-web-26

A minimal Flask hello-world app with three deployment paths:
- **Local** — docker-compose for development
- **Docker (Pulumi)** — container deployed locally via Pulumi's Docker provider
- **Serverless (Terraform)** — Lambda + API Gateway HTTP API on AWS

## Prerequisites

| Tool | Version |
|------|---------|
| Docker + Docker Compose | v2+ |
| Python | 3.12+ |
| Pulumi CLI | v3+ |
| Terraform CLI | v1.5+ |
| AWS CLI (serverless path) | v2+ |

## Project structure

```
.
├── app.py               # Flask application
├── lambda_handler.py    # Mangum adapter — wraps Flask for Lambda
├── requirements.txt     # App dependencies (flask, gunicorn, mangum)
├── Dockerfile           # Container image (gunicorn)
├── docker-compose.yml   # Local development stack
├── Makefile             # All workflow targets
├── infra/               # Pulumi — Docker provider
│   ├── Pulumi.yaml
│   ├── __main__.py
│   └── requirements.txt
└── terraform/           # Terraform — AWS Lambda + API Gateway
    └── main.tf
```

## Quick start

### Local (docker-compose)

```bash
make local-up    # build image and start container at http://localhost:5000
make local-logs  # tail logs
make local-down  # stop and remove containers
```

### Docker (Pulumi)

```bash
make remote-init     # first-time: creates infra/venv and the 'dev' stack
make remote-preview  # dry-run
make remote-up       # deploy
make remote-down     # destroy
```

> Override host port: `cd infra && ./venv/bin/pulumi config set hostPort 8080`

### Serverless (AWS + Terraform)

Configure AWS credentials first:

```bash
aws configure
```

Then deploy:

```bash
make tf-init  # first-time: download providers
make tf-up    # build Lambda zip and apply — prints the API Gateway URL
make tf-down  # destroy all AWS resources
```

`tf-up` automatically runs `make build`, which packages the app and its
dependencies into `dist/lambda.zip` before Terraform runs.

#### Surface Terraform outputs in Pulumi

After `make tf-up`, Pulumi can read the Terraform state:

```bash
cd infra && ./venv/bin/pulumi config set readTfState true
make remote-up
# stack outputs will include tf_api_url and tf_function_name
```

## Endpoints

| Route | Response |
|-------|----------|
| `GET /` | `{"message": "Hello, World!"}` |
| `GET /health` | `{"status": "ok"}` |
