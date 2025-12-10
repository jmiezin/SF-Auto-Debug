# 🔄 Intégration CI/CD - Validation Automatique

## Vue d'Ensemble

Intégration des outils IA dans le pipeline de déploiement Salesforce.

**Objectif:** Détecter 90% des erreurs avant qu'elles n'atteignent la production.

---

## 🎯 Architecture CI/CD

```
┌─────────────────┐
│   Developer     │
│   Commit Flow   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Git Pre-Commit Hook                │
│  - Validation XML syntax            │
│  - Nomenclature check               │
└────────┬────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  GitHub Actions / Azure Pipeline    │
│  ┌─────────────────────────────┐   │
│  │ Step 1: AI Validator        │   │
│  │ - Check missing fields      │   │
│  │ - Detect orphans            │   │
│  │ - Verify FLS                │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Step 2: Generate Docs       │   │
│  │ - Create/update .md files   │   │
│  │ - Commit to docs/           │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Step 3: Impact Analysis     │   │
│  │ - Detect breaking changes   │   │
│  │ - Warn on PR                │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Step 4: Deploy if OK        │   │
│  │ - sf deploy metadata        │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│   Salesforce    │
│   Production    │
└─────────────────┘
```

---

## 📁 Fichiers de Configuration

### 1. GitHub Actions Workflow

**Fichier:** `.github/workflows/salesforce-validation.yml`

```yaml
name: Salesforce Flow Validation

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'force-app/main/default/flows/**'
  pull_request:
    branches: [ main ]
    paths:
      - 'force-app/main/default/flows/**'

env:
  AZURE_OPENAI_ENDPOINT: ${{ secrets.AZURE_OPENAI_ENDPOINT }}
  AZURE_OPENAI_API_KEY: ${{ secrets.AZURE_OPENAI_API_KEY }}
  AZURE_OPENAI_DEPLOYMENT: gpt-4-32k
  SF_TARGET_ORG: production

jobs:
  validate-flows:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: |
          pip install -r AI_ASSISTANT/requirements.txt
      
      - name: Run AI Validator
        id: validator
        run: |
          cd AI_ASSISTANT
          python3 validators/pre_deployment_validator.py > validation_report.json
          
          # Extraire résultats
          CRITICAL=$(jq '.summary.critical_issues' validation_report.json)
          WARNINGS=$(jq '.summary.warnings' validation_report.json)
          
          echo "critical=$CRITICAL" >> $GITHUB_OUTPUT
          echo "warnings=$WARNINGS" >> $GITHUB_OUTPUT
      
      - name: Check validation results
        if: steps.validator.outputs.critical > 0
        run: |
          echo "❌ ${{ steps.validator.outputs.critical }} erreurs critiques détectées"
          exit 1
      
      - name: Generate Documentation
        if: success()
        run: |
          cd AI_ASSISTANT
          python3 generators/flow_documentation_generator.py
      
      - name: Commit Documentation
        if: success()
        run: |
          git config user.name "AI Bot"
          git config user.email "bot@isonic.ai"
          git add AI_ASSISTANT/documentation/
          git diff --quiet && git diff --staged --quiet || \
            git commit -m "docs: Auto-generate flow documentation [skip ci]"
          git push
      
      - name: Comment PR with Results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const critical = ${{ steps.validator.outputs.critical }};
            const warnings = ${{ steps.validator.outputs.warnings }};
            
            let comment = `## 🤖 AI Validation Report\n\n`;
            
            if (critical === 0) {
              comment += `✅ **Aucune erreur critique** - Prêt à merger\n\n`;
            } else {
              comment += `❌ **${critical} erreur(s) critique(s)** - Corrections requises\n\n`;
            }
            
            comment += `- 🔴 Critiques: ${critical}\n`;
            comment += `- 🟡 Warnings: ${warnings}\n\n`;
            comment += `Voir le rapport complet dans les artifacts.`;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
      
      - name: Upload validation report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: validation-report
          path: AI_ASSISTANT/validation_report.json
  
  deploy-if-valid:
    needs: validate-flows
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && success()
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Install Salesforce CLI
        run: |
          npm install -g @salesforce/cli
      
      - name: Authenticate to Salesforce
        run: |
          echo "${{ secrets.SF_AUTH_URL }}" > auth_url.txt
          sf org login sfdx-url --sfdx-url-file auth_url.txt --alias production
      
      - name: Deploy Flows
        run: |
          sf deploy metadata \
            --metadata "Flow" \
            --target-org production \
            --wait 30 \
            --test-level NoTestRun
      
      - name: Notify on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "❌ Déploiement Salesforce échoué",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Déploiement échoué*\n\nCommit: ${{ github.sha }}\nAuteur: ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### 2. Git Pre-Commit Hook

**Fichier:** `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook pour validation locale

echo "🔍 Validation pré-commit..."

# Récupérer les flows modifiés
FLOWS=$(git diff --cached --name-only --diff-filter=ACM | grep "\.flow-meta\.xml$")

if [ -z "$FLOWS" ]; then
    echo "✅ Aucun flow modifié"
    exit 0
fi

echo "📋 Flows modifiés:"
echo "$FLOWS" | while read flow; do
    echo "  - $flow"
done

# Installer dépendances si nécessaire
if [ ! -d "AI_ASSISTANT/venv" ]; then
    echo "📦 Installation des dépendances..."
    cd AI_ASSISTANT
    python3 -m venv venv
    source venv/bin/activate
    pip install -q -r requirements.txt
    cd ..
fi

# Valider les flows
echo "🤖 Lancement de la validation IA..."

cd AI_ASSISTANT
source venv/bin/activate

# Valider uniquement les flows modifiés
echo "$FLOWS" | while read flow; do
    FLOW_NAME=$(basename "$flow" .flow-meta.xml)
    python3 validators/pre_deployment_validator.py --flow "$FLOW_NAME"
    
    if [ $? -ne 0 ]; then
        echo "❌ Erreurs détectées dans $FLOW_NAME"
        echo "   Utilisez 'git commit --no-verify' pour forcer (non recommandé)"
        exit 1
    fi
done

deactivate
cd ..

echo "✅ Validation réussie"
exit 0
```

**Installation:**

```bash
chmod +x .git/hooks/pre-commit
```

---

### 3. Azure DevOps Pipeline

**Fichier:** `azure-pipelines.yml`

```yaml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - force-app/main/default/flows/*

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: azure-openai-credentials
  - name: pythonVersion
    value: '3.10'

stages:
  - stage: Validate
    displayName: 'AI Validation'
    jobs:
      - job: ValidateFlows
        displayName: 'Validate Salesforce Flows'
        steps:
          - task: UsePythonVersion@0
            inputs:
              versionSpec: '$(pythonVersion)'
            displayName: 'Use Python $(pythonVersion)'
          
          - script: |
              pip install -r AI_ASSISTANT/requirements.txt
            displayName: 'Install dependencies'
          
          - script: |
              cd AI_ASSISTANT
              python3 validators/pre_deployment_validator.py
            displayName: 'Run AI Validator'
            env:
              AZURE_OPENAI_ENDPOINT: $(AZURE_OPENAI_ENDPOINT)
              AZURE_OPENAI_API_KEY: $(AZURE_OPENAI_API_KEY)
          
          - task: PublishTestResults@2
            condition: succeededOrFailed()
            inputs:
              testResultsFormat: 'JUnit'
              testResultsFiles: 'AI_ASSISTANT/reports/validation_report.xml'
              failTaskOnFailedTests: true
            displayName: 'Publish validation results'
  
  - stage: Deploy
    displayName: 'Deploy to Salesforce'
    dependsOn: Validate
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployFlows
        displayName: 'Deploy Flows'
        environment: 'production'
        strategy:
          runOnce:
            deploy:
              steps:
                - script: |
                    npm install -g @salesforce/cli
                  displayName: 'Install Salesforce CLI'
                
                - script: |
                    echo "$(SF_AUTH_URL)" > auth_url.txt
                    sf org login sfdx-url --sfdx-url-file auth_url.txt --alias production
                  displayName: 'Authenticate to Salesforce'
                  env:
                    SF_AUTH_URL: $(SF_AUTH_URL)
                
                - script: |
                    sf deploy metadata \
                      --metadata "Flow" \
                      --target-org production \
                      --wait 30
                  displayName: 'Deploy Flows'
```

---

## 🔐 Configuration des Secrets

### GitHub Secrets

Dans **Settings > Secrets and variables > Actions**, ajouter:

| Secret Name | Description | Exemple |
|-------------|-------------|---------|
| `AZURE_OPENAI_ENDPOINT` | URL du service Azure OpenAI | `https://xxx.openai.azure.com/` |
| `AZURE_OPENAI_API_KEY` | Clé API Azure OpenAI | `sk-...` |
| `SF_AUTH_URL` | URL d'authentification Salesforce | `force://PlatformCLI::...` |
| `SLACK_WEBHOOK_URL` | Webhook Slack pour notifications | `https://hooks.slack.com/...` |

**Générer SF_AUTH_URL:**

```bash
sf org display --verbose --target-org production --json | jq -r '.result.sfdxAuthUrl'
```

---

### Azure DevOps Variable Groups

Dans **Pipelines > Library**, créer groupe `azure-openai-credentials`:

| Variable | Value | Secret |
|----------|-------|--------|
| `AZURE_OPENAI_ENDPOINT` | `https://xxx.openai.azure.com/` | No |
| `AZURE_OPENAI_API_KEY` | `sk-...` | Yes ✅ |
| `SF_AUTH_URL` | `force://...` | Yes ✅ |

---

## 📊 Notifications & Reporting

### 1. Slack Integration

**Fichier:** `AI_ASSISTANT/utils/slack_notifier.py`

```python
import requests
import os
from typing import Dict

def send_slack_notification(webhook_url: str, report: Dict):
    """Envoie notification Slack avec résumé de validation"""
    
    critical = report['summary']['critical_issues']
    warnings = report['summary']['warnings']
    deployable = report['summary']['deployable']
    total = report['summary']['total_flows']
    
    color = "good" if critical == 0 else "danger"
    
    payload = {
        "attachments": [
            {
                "color": color,
                "title": "🤖 AI Validation Report",
                "fields": [
                    {
                        "title": "Flows Analyzed",
                        "value": str(total),
                        "short": True
                    },
                    {
                        "title": "Deployable",
                        "value": f"{deployable}/{total}",
                        "short": True
                    },
                    {
                        "title": "Critical Issues",
                        "value": str(critical),
                        "short": True
                    },
                    {
                        "title": "Warnings",
                        "value": str(warnings),
                        "short": True
                    }
                ],
                "footer": "AI Assistant",
                "ts": int(time.time())
            }
        ]
    }
    
    response = requests.post(webhook_url, json=payload)
    return response.status_code == 200
```

---

### 2. Email Reports

**Fichier:** `AI_ASSISTANT/utils/email_reporter.py`

```python
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

def send_validation_email(to_email: str, report_path: str, summary: Dict):
    """Envoie rapport de validation par email"""
    
    from_email = os.getenv("SMTP_FROM_EMAIL")
    smtp_server = os.getenv("SMTP_SERVER")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_password = os.getenv("SMTP_PASSWORD")
    
    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = to_email
    msg['Subject'] = f"Validation Report - {summary['total_flows']} flows"
    
    body = f"""
    Rapport de Validation Automatique
    
    Flows analysés: {summary['total_flows']}
    Déployables: {summary['deployable']}
    Erreurs critiques: {summary['critical_issues']}
    Warnings: {summary['warnings']}
    
    Voir le rapport complet en pièce jointe.
    """
    
    msg.attach(MIMEText(body, 'plain'))
    
    # Attacher rapport JSON
    with open(report_path, 'rb') as f:
        part = MIMEBase('application', 'octet-stream')
        part.set_payload(f.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition', f'attachment; filename= {os.path.basename(report_path)}')
        msg.attach(part)
    
    # Envoyer
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.login(from_email, smtp_password)
        server.send_message(msg)
```

---

## 🧪 Tests Locaux

### Simuler le Pipeline Localement

```bash
#!/bin/bash
# test_ci_cd_locally.sh

echo "🧪 Simulation du pipeline CI/CD..."

# Step 1: Validation
echo "\n📋 Step 1: AI Validation"
cd AI_ASSISTANT
python3 validators/pre_deployment_validator.py

if [ $? -ne 0 ]; then
    echo "❌ Validation failed"
    exit 1
fi

# Step 2: Documentation
echo "\n📚 Step 2: Generate Documentation"
python3 generators/flow_documentation_generator.py

# Step 3: Impact Analysis (sur champs critiques)
echo "\n🔎 Step 3: Impact Analysis"
python3 analyzers/impact_analyzer.py

# Step 4: Deploy (dry-run)
echo "\n🚀 Step 4: Deploy (dry-run)"
cd ..
sf deploy metadata \
    --metadata "Flow:Quote*" \
    --target-org production \
    --dry-run

echo "\n✅ Pipeline simulation complete"
```

---

## 📈 Métriques de Performance

### Benchmarks Attendus

| Étape | Temps | Bloquant |
|-------|-------|----------|
| AI Validation (39 flows) | 5-10min | Oui si erreur |
| Documentation Generation | 10-15min | Non |
| Impact Analysis | 2-5min | Non |
| Deploy to Salesforce | 10-20min | Oui si erreur |

**Total pipeline:** 30-50min

---

## 🔄 Rollback Automatique

### En cas d'échec de déploiement

```yaml
# Dans GitHub Actions
- name: Rollback on failure
  if: failure()
  run: |
    # Récupérer le dernier commit qui fonctionnait
    LAST_SUCCESS=$(git rev-list --all --grep="deploy: success" -1)
    
    # Déployer la version précédente
    git checkout $LAST_SUCCESS
    
    sf deploy metadata \
      --metadata "Flow" \
      --target-org production \
      --wait 30
    
    # Notifier
    echo "⚠️ Rollback effectué vers $LAST_SUCCESS" >> $GITHUB_STEP_SUMMARY
```

---

**Créé:** 6 Dec 2024  
**Auteur:** AI Assistant  
**Version:** 1.0.0

