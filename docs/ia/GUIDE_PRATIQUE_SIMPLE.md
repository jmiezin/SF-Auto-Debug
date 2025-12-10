# 🎯 Guide Pratique - Azure OpenAI dans Salesforce

## En 3 minutes : Comment ça marche ?

Tu as 3 outils Python qui utilisent Azure OpenAI pour t'aider avec Salesforce :

1. **Validateur** → Vérifie tes flows avant déploiement
2. **Documentation** → Génère de la doc automatique
3. **Impact** → Analyse les risques avant de modifier

---

## 🚀 Setup Initial (une seule fois)

### Étape 1 : Installer Python

```bash
# Vérifier que Python est installé
python3 --version
# Doit afficher: Python 3.8 ou plus
```

### Étape 2 : Installer les dépendances

```bash
cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"
pip3 install -r requirements.txt
```

### Étape 3 : Configurer Azure OpenAI

```bash
# Copier le fichier template
cp config/azure.example.env config/azure.env

# Ouvrir avec un éditeur
nano config/azure.env
```

**Remplir ces 3 lignes :**
```env
AZURE_OPENAI_ENDPOINT=https://ton-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=ta-clé-api-ici
AZURE_OPENAI_DEPLOYMENT=gpt-4-32k
```

**C'est tout !** ✅

---

## 📋 Cas d'Usage Concrets

### Cas 1 : "Je veux valider mes flows avant de déployer"

**Problème :** Tu as modifié des flows et tu veux éviter les erreurs en production.

**Solution :**

```bash
cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"
python3 validators/pre_deployment_validator.py
```

**Ce qui se passe :**
- ✅ Analyse tous tes flows Quote
- ✅ Détecte les champs manquants
- ✅ Trouve les IDs hardcodés
- ✅ Vérifie les erreurs de logique
- ✅ Génère un rapport JSON

**Résultat :**
```
✅ Déployables: 35/39 (89%)
🔴 Critiques: 12
🟡 Warnings: 47
```

**Fichier généré :** `reports/validation_report.json`

**Comment lire le rapport :**
```bash
# Voir les flows avec erreurs critiques
cat reports/validation_report.json | jq '.flows[] | select(.can_deploy == false) | .name'

# Voir les erreurs d'un flow spécifique
cat reports/validation_report.json | jq '.flows[] | select(.name == "Quote_Trigger_Update") | .issues[]'
```

---

### Cas 2 : "Je veux comprendre un flow complexe"

**Problème :** `Quote_Trigger_Update` fait 1426 lignes, impossible à comprendre.

**Solution :**

```bash
cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"
python3 generators/flow_documentation_generator.py
```

**Ce qui se passe :**
- ✅ Parse le flow XML
- ✅ Utilise Azure OpenAI pour expliquer la logique
- ✅ Génère un fichier Markdown lisible

**Résultat :**
- Fichier créé : `documentation/flows/Quote_Trigger_Update.md`
- Contient : diagramme ASCII, explication métier, liste des champs

**Lire la doc :**
```bash
cat documentation/flows/Quote_Trigger_Update.md
```

---

### Cas 3 : "Je veux supprimer un champ, c'est risqué ?"

**Problème :** Tu veux supprimer `Quote.TotalCost__c` mais tu ne sais pas ce qui va casser.

**Solution :**

1. **Ouvrir le fichier :**
```bash
nano AI_ASSISTANT/analyzers/impact_analyzer.py
```

2. **Aller à la ligne 443 et modifier :**
```python
# Avant (ligne 443)
analysis = analyzer.analyze_field_impact("Quote", "TotalCost__c", "Delete")
```

3. **Lancer l'analyse :**
```bash
python3 analyzers/impact_analyzer.py
```

**Ce qui se passe :**
- ✅ Scanne tous les flows qui utilisent ce champ
- ✅ Trouve les classes Apex concernées
- ✅ Liste les LWCs impactés
- ✅ Utilise Azure OpenAI pour donner une recommandation

**Résultat :**
```
🔴 IMPACT DÉTECTÉ:
- 3 flows utilisent ce champ
- 1 LWC (iscpq_targetPricingModal)
- 2 Permission Sets

💡 RECOMMANDATION: DANGEROUS - Ne pas supprimer
📋 PLAN: Créer champ de remplacement d'abord
```

**Fichier généré :** `reports/impact_analysis_Quote_TotalCost.json`

---

## 🎯 Exemples Concrets du Quotidien

### Exemple 1 : Avant chaque déploiement

```bash
#!/bin/bash
# Script: avant_deploy.sh

cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"

echo "🔍 Validation des flows..."
python3 validators/pre_deployment_validator.py

if [ $? -eq 0 ]; then
    echo "✅ Tout est OK, tu peux déployer"
else
    echo "❌ Erreurs détectées, corrige avant de déployer"
    echo "📄 Voir: reports/validation_report.json"
fi
```

**Utilisation :**
```bash
chmod +x avant_deploy.sh
./avant_deploy.sh
```

---

### Exemple 2 : Documenter un flow spécifique

```bash
# Documenter seulement Quote_Trigger_Update
cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"

# Modifier generators/flow_documentation_generator.py
# Ligne ~670, changer pour filtrer un flow spécifique
# Puis lancer:
python3 generators/flow_documentation_generator.py
```

---

### Exemple 3 : Analyser plusieurs champs d'un coup

```python
# Créer: AI_ASSISTANT/scripts/batch_impact.py

from analyzers.impact_analyzer import ImpactAnalyzer
import json

analyzer = ImpactAnalyzer("/Users/jonathanmiezin/Desktop/IS Migration")

# Liste des champs à vérifier
champs_a_verifier = [
    ("Quote", "TotalCost__c"),
    ("Quote", "GlobalMargin__c"),
    ("QuoteLineItem", "Quantity"),
]

resultats = []
for objet, champ in champs_a_verifier:
    print(f"🔍 Analyse {objet}.{champ}...")
    analyse = analyzer.analyze_field_impact(objet, champ, "Delete")
    resultats.append({
        'champ': f"{objet}.{champ}",
        'impacts': analyse.total_impacts,
        'critiques': analyse.critical_impacts,
        'recommandation': analyse.recommendation
    })

# Sauvegarder
with open('reports/batch_impact.json', 'w') as f:
    json.dump(resultats, f, indent=2, ensure_ascii=False)

print("✅ Rapport sauvegardé: reports/batch_impact.json")
```

**Lancer :**
```bash
python3 scripts/batch_impact.py
```

---

## 🔧 Commandes Rapides

### Valider un flow spécifique

```bash
# Modifier pre_deployment_validator.py ligne ~545
# Ajouter: --flow Quote_Trigger_Update
python3 validators/pre_deployment_validator.py --flow Quote_Trigger_Update
```

### Voir seulement les erreurs critiques

```bash
cat reports/validation_report.json | jq '.flows[] | select(.can_deploy == false) | {name: .name, issues: [.issues[] | select(.severity == "CRITICAL")]}'
```

### Générer doc pour tous les flows Quote

```bash
python3 generators/flow_documentation_generator.py
# Génère: documentation/flows/*.md
```

---

## ❓ Problèmes Courants

### "Module not found"

```bash
# Réinstaller les dépendances
pip3 install --upgrade -r requirements.txt
```

### "Azure OpenAI API Key invalide"

```bash
# Vérifier que le fichier existe
cat config/azure.env

# Vérifier les valeurs
grep AZURE_OPENAI config/azure.env
```

### "Flow XML parsing error"

```bash
# Vérifier la syntaxe XML
xmllint --noout force-app/main/default/flows/Quote_Trigger_Update.flow-meta.xml
```

---

## 📊 Comprendre les Rapports

### validation_report.json

```json
{
  "summary": {
    "total_flows": 39,
    "deployable": 35,        ← Flows OK pour déployer
    "critical_issues": 12,   ← Erreurs à corriger AVANT déploiement
    "warnings": 47           ← À vérifier mais pas bloquant
  },
  "flows": [
    {
      "name": "Quote_Trigger_Update",
      "can_deploy": false,   ← false = NE PAS déployer
      "issues": [
        {
          "severity": "CRITICAL",
          "message": "Champ Owner_Role__c manquant",
          "suggestion": "Vérifier existence ou retirer"
        }
      ]
    }
  ]
}
```

**Action :**
- `can_deploy: false` → Corriger les `CRITICAL` avant de déployer
- `can_deploy: true` → Tu peux déployer

---

### impact_analysis_*.json

```json
{
  "target": "Quote.TotalCost__c",
  "summary": {
    "total_impacts": 7,      ← Nombre total d'endroits impactés
    "critical_impacts": 2    ← Impacts critiques (ne pas ignorer)
  },
  "recommendation": "DANGEROUS - Ce champ est essentiel...",
  "migration_plan": "1. Créer nouveau champ...\n2. Migrer données..."
}
```

**Décision :**
- `total_impacts > 5` → Planifier une migration
- `critical_impacts > 0` → NE PAS supprimer directement
- Suivre le `migration_plan`

---

## 🎓 Workflow Recommandé

### Avant de modifier un flow

1. **Documenter l'existant :**
```bash
python3 generators/flow_documentation_generator.py
```

2. **Analyser l'impact si tu modifies des champs :**
```bash
python3 analyzers/impact_analyzer.py
```

3. **Faire tes modifications**

4. **Valider avant commit :**
```bash
python3 validators/pre_deployment_validator.py
```

5. **Si OK → Commit et déployer**

---

## 💡 Astuces

### Voir les résultats rapidement

```bash
# Erreurs critiques seulement
cat reports/validation_report.json | jq '.summary.critical_issues'

# Liste des flows non déployables
cat reports/validation_report.json | jq -r '.flows[] | select(.can_deploy == false) | .name'
```

### Intégrer dans Git

```bash
# Créer .git/hooks/pre-commit
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
cd "/Users/jonathanmiezin/Desktop/IS Migration/AI_ASSISTANT"
python3 validators/pre_deployment_validator.py
EOF

chmod +x .git/hooks/pre-commit
```

Maintenant, à chaque `git commit`, les flows sont validés automatiquement !

---

## 📞 Besoin d'aide ?

**Fichiers importants :**
- `AI_ASSISTANT/validators/pre_deployment_validator.py` → Validateur
- `AI_ASSISTANT/generators/flow_documentation_generator.py` → Documentation
- `AI_ASSISTANT/analyzers/impact_analyzer.py` → Analyse d'impact
- `AI_ASSISTANT/config/azure.env` → Configuration Azure OpenAI

**Rapports générés :**
- `reports/validation_report.json` → Résultats validation
- `reports/impact_analysis_*.json` → Analyses d'impact
- `documentation/flows/*.md` → Documentation flows

---

**C'est tout !** 🎉

Tu as maintenant 3 outils qui utilisent Azure OpenAI pour t'aider avec Salesforce. Utilise-les avant chaque déploiement pour éviter les erreurs.
