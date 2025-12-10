# 🚀 Quick Start - AI Assistant

## Configuration Rapide (5 minutes)

### 1. Prérequis

```bash
# Vérifier Python 3.8+
python3 --version

# Installer pip si nécessaire
which pip3
```

### 2. Installation

```bash
cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"

# Installer dépendances
pip3 install -r requirements.txt
```

### 3. Configuration Azure OpenAI

```bash
# Copier le template
cp config/azure.example.env config/azure.env

# Éditer avec vos credentials
nano config/azure.env
```

**Remplir:**
```env
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=votre-clé-api
AZURE_OPENAI_DEPLOYMENT=gpt-4-32k
```

### 4. Test Rapide

```bash
# Valider un flow
python3 validators/pre_deployment_validator.py

# Générer documentation
python3 generators/flow_documentation_generator.py

# Analyser un impact
python3 analyzers/impact_analyzer.py
```

---

## 📋 Cas d'Usage Principaux

### 🔍 Cas 1: Valider avant Déploiement

**Problème:** "J'ai 39 flows Quote à déployer, comment éviter les erreurs ?"

```bash
python3 validators/pre_deployment_validator.py

# Output:
# ✅ Déployables: 35/39 (89%)
# 🔴 Critiques: 12
# 🟡 Warnings: 47
```

**Résultat:**
- Rapport JSON avec tous les problèmes
- Suggestions de correction
- Exit code 0 si OK, 1 si erreurs critiques

---

### 📚 Cas 2: Documenter un Flow Complexe

**Problème:** "Quote_Trigger_Update fait 1426 lignes, impossible à comprendre"

```bash
python3 generators/flow_documentation_generator.py

# Génère:
# - documentation/flows/Quote_Trigger_Update.md
# - Diagramme ASCII
# - Explication IA de la logique
# - Liste des champs/Custom Settings
```

**Résultat:**
Documentation Markdown lisible avec:
- Objectif métier
- Diagramme de flux
- Champs utilisés
- Impact sur les données

---

### 🔎 Cas 3: Analyser Impact d'un Changement

**Problème:** "Je veux supprimer Quote.TotalCost__c, quels sont les risques ?"

```bash
# Dans analyzers/impact_analyzer.py, modifier la ligne 443:
analysis = analyzer.analyze_field_impact("Quote", "TotalCost__c", "Delete")

# Lancer
python3 analyzers/impact_analyzer.py

# Output:
# 🔴 IMPACT DÉTECTÉ:
# - 3 flows utilisent ce champ
# - 1 LWC (iscpq_targetPricingModal)
# - 2 Permission Sets
# 
# 💡 RECOMMANDATION: DANGEROUS - Ne pas supprimer
# 📋 PLAN: Créer champ de remplacement d'abord
```

**Résultat:**
- Tree view des dépendances
- Recommandation IA
- Plan de migration étape par étape

---

## 🎯 Scénarios Avancés

### Scénario 1: Pré-déploiement Complet

```bash
#!/bin/bash
# Script: pre_deploy_check.sh

echo "🔍 Validation pré-déploiement..."

# 1. Valider tous les flows
python3 validators/pre_deployment_validator.py
if [ $? -ne 0 ]; then
    echo "❌ Erreurs critiques détectées"
    exit 1
fi

# 2. Générer documentation
python3 generators/flow_documentation_generator.py

# 3. Analyser impacts critiques
# (à implémenter selon vos besoins)

echo "✅ Validation OK - Prêt à déployer"
```

### Scénario 2: Analyse d'un Flow Spécifique

```python
# analyze_single_flow.py
from generators.flow_documentation_generator import FlowDocumentationGenerator
from pathlib import Path

workspace = "/Users/jonathanmiezin/Desktop/IS Migration"
generator = FlowDocumentationGenerator(workspace)

# Analyser un flow spécifique
flow_path = Path(workspace) / "force-app/main/default/flows/Quote_Trigger_Update.flow-meta.xml"
doc = generator.parse_flow(flow_path)

# Afficher résumé
print(f"Flow: {doc.label}")
print(f"Elements: {len(doc.elements)}")
print(f"\nLogique métier:\n{doc.business_logic}")
```

### Scénario 3: Rapport Consolidé d'Impact

```python
# batch_impact_analysis.py
from analyzers.impact_analyzer import ImpactAnalyzer
import json

analyzer = ImpactAnalyzer("/Users/jonathanmiezin/Desktop/IS Migration")

# Champs à analyser
fields_to_check = [
    ("Quote", "TotalCost__c"),
    ("Quote", "GlobalMargin__c"),
    ("QuoteLineItem", "Quantity"),
]

results = []
for obj, field in fields_to_check:
    analysis = analyzer.analyze_field_impact(obj, field, "Delete")
    results.append({
        'field': f"{obj}.{field}",
        'total_impacts': analysis.total_impacts,
        'critical': analysis.critical_impacts,
        'recommendation': analysis.recommendation
    })

# Sauvegarder rapport consolidé
with open('consolidated_impact_report.json', 'w') as f:
    json.dump(results, f, indent=2)

print("✅ Rapport consolidé généré")
```

---

## 📊 Interprétation des Résultats

### Validation Report

```json
{
  "summary": {
    "total_flows": 39,
    "deployable": 35,
    "critical_issues": 12,
    "warnings": 47
  },
  "flows": [
    {
      "name": "Quote_Trigger_Update",
      "can_deploy": false,
      "issues": [
        {
          "severity": "CRITICAL",
          "category": "FIELD",
          "message": "Champ Owner_Role__c connu pour être problématique",
          "suggestion": "Vérifier existence ou retirer"
        }
      ],
      "ai_summary": "Ce flow contient des références à des champs Activity..."
    }
  ]
}
```

**Actions:**
1. Filtrer sur `can_deploy: false`
2. Corriger les `CRITICAL` en priorité
3. Re-valider
4. Déployer

---

### Impact Analysis

```json
{
  "target": "Quote.TotalCost__c",
  "summary": {
    "total_impacts": 7,
    "critical_impacts": 2
  },
  "recommendation": "DANGEROUS - Ce champ est essentiel au calcul de marge...",
  "migration_plan": "1. Créer nouveau champ...\n2. Migrer données..."
}
```

**Décision:**
- `total_impacts > 5` → Planifier migration
- `critical_impacts > 0` → NE PAS supprimer directement
- Suivre le plan de migration IA

---

## 🔧 Personnalisation

### Ajouter un Validateur Custom

```python
# Dans validators/pre_deployment_validator.py

def _check_custom_rule(self, root: ET.Element, flow_name: str) -> List[ValidationIssue]:
    """Votre règle personnalisée"""
    issues = []
    
    # Exemple: Vérifier qu'un champ spécifique est présent
    if "Quote" in flow_name:
        if "Quote_Type__c" not in ET.tostring(root, encoding='unicode'):
            issues.append(ValidationIssue(
                severity="WARNING",
                category="BUSINESS_RULE",
                flow_name=flow_name,
                element="Quote_Type__c",
                message="Flow Quote sans vérification de Quote_Type__c",
                suggestion="Ajouter une décision sur Quote_Type__c"
            ))
    
    return issues

# Ajouter dans validate_flow():
issues.extend(self._check_custom_rule(root, flow_file.stem))
```

---

## ❓ Troubleshooting

### Erreur: "Azure OpenAI API Key invalide"

```bash
# Vérifier configuration
cat config/azure.env | grep API_KEY

# Tester connexion
python3 -c "
import openai
from dotenv import load_dotenv
load_dotenv('config/azure.env')
import os
print(openai.AzureOpenAI(
    api_key=os.getenv('AZURE_OPENAI_API_KEY'),
    api_version=os.getenv('AZURE_OPENAI_API_VERSION'),
    azure_endpoint=os.getenv('AZURE_OPENAI_ENDPOINT')
))
"
```

### Erreur: "Module not found"

```bash
# Réinstaller dépendances
pip3 install --upgrade -r requirements.txt
```

### Erreur: "Flow XML parsing error"

```bash
# Vérifier syntaxe XML
xmllint --noout force-app/main/default/flows/Quote_Trigger_Update.flow-meta.xml

# Si erreur → corriger avec script Python
python3 scripts/fix_flow_xml.py Quote_Trigger_Update
```

---

## 📈 Prochaines Étapes

1. ✅ Configurer Azure OpenAI
2. ✅ Lancer validateur sur tous les flows Quote
3. ✅ Générer documentation
4. ✅ Analyser impacts des champs à risque
5. ⏭️ Intégrer dans CI/CD (GitHub Actions / Azure Pipelines)
6. ⏭️ Former l'équipe
7. ⏭️ Étendre aux autres objets (Account, Contact, etc.)

---

**Support:** Voir `README.md` pour documentation complète  
**Questions:** jonathan.miezin@isonic.ai

