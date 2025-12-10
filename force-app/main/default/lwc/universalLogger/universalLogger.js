/**
 * Universal Logger pour LWC/Aura
 * Standard de logging unifié pour toute l'org
 * 
 * Usage:
 * import log from 'c/universalLogger';
 * log.debug('MyComponent', 'handleClick', 'Button clicked', { buttonId: 'save' });
 * log.error('MyComponent', 'handleSave', 'Save failed', error);
 */
import logFromServer from '@salesforce/apex/UniversalLogger.logFromClient';

const LOG_LEVELS = {
    DEBUG: 'DEBUG',
    INFO: 'INFO',
    WARN: 'WARN',
    ERROR: 'ERROR'
};

/**
 * Logger universel pour LWC
 */
const logger = {
    /**
     * Log DEBUG
     */
    debug(component, method, message, context) {
        this._log(LOG_LEVELS.DEBUG, component, method, message, context);
        console.debug(`[DEBUG] [${component}] [${method}] ${message}`, context || '');
    },
    
    /**
     * Log INFO
     */
    info(component, method, message, context) {
        this._log(LOG_LEVELS.INFO, component, method, message, context);
        console.info(`[INFO] [${component}] [${method}] ${message}`, context || '');
    },
    
    /**
     * Log WARN
     */
    warn(component, method, message, context) {
        this._log(LOG_LEVELS.WARN, component, method, message, context);
        console.warn(`[WARN] [${component}] [${method}] ${message}`, context || '');
    },
    
    /**
     * Log ERROR avec détails complets
     */
    error(component, method, message, error, context) {
        const errorContext = this._buildErrorContext(error, context);
        this._log(LOG_LEVELS.ERROR, component, method, message, errorContext);
        console.error(`[ERROR] [${component}] [${method}] ${message}`, error || '', errorContext || '');
    },
    
    /**
     * Log interne vers Salesforce
     */
    _log(level, component, method, message, context) {
        try {
            const contextJson = context ? JSON.stringify(context) : null;
            logFromServer({
                level: level,
                component: component || 'UNKNOWN',
                method: method || 'UNKNOWN',
                message: message || '',
                contextJson: contextJson
            }).catch(err => {
                // Ne pas bloquer si le logging serveur échoue
                console.warn('[UniversalLogger] Failed to log to server:', err);
            });
        } catch (e) {
            console.warn('[UniversalLogger] Error in logger:', e);
        }
    },
    
    /**
     * Construit le contexte d'erreur enrichi
     */
    _buildErrorContext(error, additionalContext) {
        const errorContext = {
            ...additionalContext
        };
        
        if (error) {
            errorContext.error = {
                message: error?.message || error?.body?.message || 'Unknown error',
                stack: error?.stack || null,
                status: error?.status || null,
                statusText: error?.statusText || null,
                errorCode: error?.body?.errorCode || null,
                pageErrors: error?.body?.pageErrors || null,
                fieldErrors: error?.body?.fieldErrors || null,
                outputErrors: error?.body?.outputErrors || null,
                stackTrace: error?.body?.stackTrace || null
            };
            
            // Ajouter le body complet si disponible
            if (error?.body) {
                try {
                    errorContext.errorBody = JSON.parse(JSON.stringify(error.body));
                } catch (e) {
                    errorContext.errorBody = String(error.body);
                }
            }
        }
        
        return errorContext;
    }
};

export default logger;
