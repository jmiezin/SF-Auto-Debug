/**
 * Universal Logger pour toute l'org Salesforce
 * Standard de logging unifié pour LWC, Aura, Apex et Flow
 * 
 * Format standardisé :
 * [LEVEL] [COMPONENT] [METHOD] Message
 * 
 * Niveaux : DEBUG, INFO, WARN, ERROR
 */
public with sharing class UniversalLogger {
    
    public enum LogLevel {
        DEBUG, INFO, WARN, ERROR
    }
    
    /**
     * Log standardisé depuis Apex
     * @param level Niveau de log (DEBUG, INFO, WARN, ERROR)
     * @param component Nom du composant/classe/flow
     * @param method Nom de la méthode/action
     * @param message Message à logger
     * @param contextData Données contextuelles optionnelles (Map ou JSON string)
     */
    public static void log(LogLevel level, String component, String method, String message, Object contextData) {
        String logMessage = buildLogMessage(level, component, method, message, contextData);
        LoggingLevel sfLevel = mapToSalesforceLevel(level);
        System.debug(sfLevel, logMessage);
    }
    
    /**
     * Version simplifiée sans contexte
     */
    public static void log(LogLevel level, String component, String method, String message) {
        log(level, component, method, message, null);
    }
    
    /**
     * Log DEBUG
     */
    public static void debug(String component, String method, String message, Object contextData) {
        log(LogLevel.DEBUG, component, method, message, contextData);
    }
    
    public static void debug(String component, String method, String message) {
        log(LogLevel.DEBUG, component, method, message, null);
    }
    
    /**
     * Log INFO
     */
    public static void info(String component, String method, String message, Object contextData) {
        log(LogLevel.INFO, component, method, message, contextData);
    }
    
    public static void info(String component, String method, String message) {
        log(LogLevel.INFO, component, method, message, null);
    }
    
    /**
     * Log WARN
     */
    public static void warn(String component, String method, String message, Object contextData) {
        log(LogLevel.WARN, component, method, message, contextData);
    }
    
    public static void warn(String component, String method, String message) {
        log(LogLevel.WARN, component, method, message, null);
    }
    
    /**
     * Log ERROR avec exception
     */
    public static void error(String component, String method, String message, Exception e, Object contextData) {
        String errorDetails = buildErrorMessage(e);
        String fullMessage = message + '\n' + errorDetails;
        log(LogLevel.ERROR, component, method, fullMessage, contextData);
    }
    
    public static void error(String component, String method, String message, Exception e) {
        error(component, method, message, e, null);
    }
    
    public static void error(String component, String method, String message, Object contextData) {
        log(LogLevel.ERROR, component, method, message, contextData);
    }
    
    public static void error(String component, String method, String message) {
        log(LogLevel.ERROR, component, method, message, null);
    }
    
    /**
     * Construit le message de log standardisé
     */
    private static String buildLogMessage(LogLevel level, String component, String method, String message, Object contextData) {
        String timestamp = Datetime.now().format('yyyy-MM-dd HH:mm:ss.SSS');
        String userId = UserInfo.getUserId();
        String userName = UserInfo.getName();
        
        String logPrefix = String.format(
            '[{0}] [{1}] [{2}] [{3}]',
            new String[]{
                level.name(),
                component != null ? component : 'UNKNOWN',
                method != null ? method : 'UNKNOWN',
                timestamp
            }
        );
        
        String logMessage = logPrefix + ' ' + message;
        
        // Ajouter contexte utilisateur
        logMessage += '\n  👤 User: ' + userName + ' (' + userId + ')';
        
        // Ajouter données contextuelles
        if (contextData != null) {
            try {
                String contextJson;
                if (contextData instanceof String) {
                    contextJson = (String) contextData;
                } else if (contextData instanceof Map<String, Object>) {
                    contextJson = JSON.serializePretty(contextData);
                } else {
                    contextJson = JSON.serializePretty(contextData);
                }
                logMessage += '\n  📋 Context: ' + contextJson;
            } catch (Exception e) {
                logMessage += '\n  📋 Context: [Error serializing context: ' + e.getMessage() + ']';
            }
        }
        
        return logMessage;
    }
    
    /**
     * Construit le message d'erreur détaillé avec exception
     */
    private static String buildErrorMessage(Exception e) {
        if (e == null) return '';
        
        String errorMsg = '\n  ❌ Exception Type: ' + e.getTypeName();
        errorMsg += '\n  ❌ Message: ' + e.getMessage();
        errorMsg += '\n  ❌ Line: ' + e.getLineNumber();
        
        if (String.isNotBlank(e.getStackTraceString())) {
            errorMsg += '\n  ❌ Stack Trace:\n' + e.getStackTraceString();
        }
        
        if (e.getCause() != null) {
            errorMsg += '\n  ❌ Cause: ' + e.getCause().getMessage();
        }
        
        // Détails spécifiques pour DMLException
        if (e instanceof DmlException) {
            DmlException dmlEx = (DmlException) e;
            errorMsg += '\n  ❌ DML Fields: ' + dmlEx.getDmlFieldNames(0);
            errorMsg += '\n  ❌ DML Message: ' + dmlEx.getDmlMessage(0);
            errorMsg += '\n  ❌ DML Type: ' + dmlEx.getDmlType(0);
        }
        
        return errorMsg;
    }
    
    /**
     * Parse un string vers LogLevel
     */
    private static LogLevel parseLogLevel(String level) {
        if (level == null) {
            return LogLevel.INFO;
        }
        String levelUpper = level.toUpperCase();
        if (levelUpper == 'DEBUG') {
            return LogLevel.DEBUG;
        } else if (levelUpper == 'INFO') {
            return LogLevel.INFO;
        } else if (levelUpper == 'WARN') {
            return LogLevel.WARN;
        } else if (levelUpper == 'ERROR') {
            return LogLevel.ERROR;
        }
        return LogLevel.INFO;
    }
    
    /**
     * Mappe le niveau de log vers LoggingLevel Salesforce
     */
    private static LoggingLevel mapToSalesforceLevel(LogLevel level) {
        if (level == LogLevel.DEBUG) {
            return LoggingLevel.DEBUG;
        } else if (level == LogLevel.INFO) {
            return LoggingLevel.INFO;
        } else if (level == LogLevel.WARN) {
            return LoggingLevel.WARN;
        } else if (level == LogLevel.ERROR) {
            return LoggingLevel.ERROR;
        }
        return LoggingLevel.INFO;
    }
    
    /**
     * Méthode @AuraEnabled pour logging depuis LWC/Aura
     */
    @AuraEnabled
    public static void logFromClient(String level, String component, String method, String message, String contextJson) {
        try {
            LogLevel logLevel = parseLogLevel(level);
            
            Object contextData = null;
            if (String.isNotBlank(contextJson)) {
                try {
                    contextData = JSON.deserializeUntyped(contextJson);
                } catch (Exception e) {
                    // Si JSON invalide, utiliser la string telle quelle
                    contextData = contextJson;
                }
            }
            
            log(logLevel, component, method, message, contextData);
        } catch (Exception e) {
            // Ne pas faire échouer si le logging échoue
            System.debug(LoggingLevel.WARN, '⚠️ [UniversalLogger] Failed to log from client: ' + e.getMessage());
        }
    }
    
    /**
     * Wrapper pour Flow (un seul paramètre requis)
     */
    public class FlowLogInput {
        @InvocableVariable(label='Niveau' required=true)
        public String level;
        
        @InvocableVariable(label='Composant' required=true)
        public String component;
        
        @InvocableVariable(label='Méthode' required=true)
        public String method;
        
        @InvocableVariable(label='Message' required=true)
        public String message;
        
        @InvocableVariable(label='Contexte (JSON)')
        public String contextJson;
    }
    
    /**
     * Méthode @InvocableMethod pour logging depuis Flow
     */
    @InvocableMethod(label='Universal Logger' description='Log standardisé depuis Flow')
    public static void logFromFlow(List<FlowLogInput> inputs) {
        if (inputs == null || inputs.isEmpty()) {
            return;
        }
        
        FlowLogInput input = inputs[0];
        logFromClient(
            input.level != null ? input.level : 'INFO',
            input.component,
            input.method,
            input.message,
            input.contextJson
        );
    }
}
