# 📧 Flow Case_Error_Email_Sender - Guide

## Fonctionnement

Le Flow `Case_Error_Email_Sender` s'exécute automatiquement quand :
- ✅ Un Case est créé
- ✅ Avec `Origin = 'Automated'`
- ✅ Et `Type = 'APEX'` ou `'LWC'` ou `'FLOW'`

**Action :** Envoie un email HTML à l'admin avec toutes les informations du diagnostic IA.

---

## Structure du Flow

```
1. Start (Record-Triggered)
   └─ Condition: Origin = 'Automated'
   
2. Decision: Check Error Type
   └─ Type = 'APEX' OU 'LWC' OU 'FLOW' → Continue
   └─ Sinon → Stop
   
3. Get Records: Get Admin Email
   └─ Récupère le premier User avec Profile = 'System Administrator'
   
4. Send Email
   └─ To: {!Get_Admin_Email.Email}
   └─ Subject: {!$Record.Subject}
   └─ Body: HTML formaté avec description du Case
```

---

## Configuration

### Option 1 : Utiliser l'email du premier Admin (actuel)

Le Flow récupère automatiquement le premier User avec le profil "System Administrator".

**Avantage :** Fonctionne immédiatement  
**Inconvénient :** Peut ne pas être la bonne personne

### Option 2 : Modifier pour utiliser Custom Metadata

**Modifier le Flow :**

1. Remplacer "Get Admin Email" par un Get Records sur Custom Metadata
2. Créer Custom Metadata `Admin_Config__mdt` avec champ `Admin_Email__c`
3. Récupérer l'email depuis le Custom Metadata

**Exemple :**
```
Get Records: Get Admin Config
Object: Admin_Config__mdt
WHERE DeveloperName = 'Default'
Fields: Admin_Email__c
```

### Option 3 : Utiliser SendBetterEmail (comme tes autres Flows)

Si tu préfères utiliser `SendBetterEmail` (comme dans tes autres Flows) :

1. Remplacer l'action "Send Email" par "SendBetterEmail"
2. Utiliser le Text Template `Email_Body` déjà créé
3. Ajouter `orgWideEmailAddressId` si nécessaire

---

## Format de l'Email

L'email HTML contient :

- **Header rouge** : "🚨 Erreur [TYPE] Détectée"
- **Informations du Case** : Numéro, lien Salesforce
- **Tableau d'informations** : Type, Priorité, Date
- **Description complète** : Tout le contenu du Case (diagnostic IA inclus)

---

## Test

### Tester le Flow

1. **Créer un Case manuellement :**
   ```
   Subject: [APEX ERROR] Test - CRITICAL
   Origin: Automated
   Type: APEX
   Description: Test error message
   ```

2. **Vérifier que l'email est envoyé :**
   - Vérifier la boîte mail de l'admin
   - Vérifier les Email Logs dans Setup

3. **Vérifier le format :**
   - Email HTML bien formaté
   - Lien vers le Case fonctionne
   - Description complète présente

---

## Personnalisation

### Modifier le format HTML

Le HTML est dans le Text Template `Email_Body` du Flow.

**Pour modifier :**
1. Ouvrir le Flow dans Flow Builder
2. Trouver le Text Template `Email_Body`
3. Modifier le HTML selon tes besoins

### Ajouter des destinataires supplémentaires

**Option 1 :** Modifier le Get Records pour récupérer plusieurs admins

**Option 2 :** Utiliser SendBetterEmail avec CC/BCC

---

## Dépannage

### L'email n'est pas envoyé

**Vérifier :**
- ✅ Le Case a bien `Origin = 'Automated'`
- ✅ Le Case a bien `Type = 'APEX'` ou `'LWC'` ou `'FLOW'`
- ✅ Le Flow est actif
- ✅ Il existe un User avec Profile = 'System Administrator'
- ✅ L'email de l'admin est renseigné

### L'email est envoyé mais vide

**Vérifier :**
- ✅ Le Case a bien une Description
- ✅ Le Text Template `Email_Body` est correctement configuré

### Erreur "No records found" dans Get Admin Email

**Solution :**
- Vérifier qu'il existe un User avec Profile = 'System Administrator'
- Ou modifier le Flow pour utiliser Custom Metadata

---

## Prochaines Étapes

1. ✅ Activer le Flow
2. ✅ Tester avec un Case manuel
3. ✅ Vérifier que l'email est bien reçu
4. ✅ Modifier le format si nécessaire
5. ✅ Intégrer avec `ErrorDiagnosticService` dans tes Flows

---

**Le Flow est prêt !** 🚀
