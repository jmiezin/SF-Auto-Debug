/**
 * Queueable pour créer le diagnostic IA en asynchrone
 * Utilisé par AuraExceptionHandler
 */
public class DiagnosticQueueable implements Queueable {
    private ErrorDiagnosticService.ErrorInfo error;
    
    public DiagnosticQueueable(ErrorDiagnosticService.ErrorInfo error) {
        this.error = error;
    }
    
    public void execute(QueueableContext context) {
        try {
            ErrorDiagnosticService.diagnoseAndCreateCase(
                new List<ErrorDiagnosticService.ErrorInfo>{ error }
            );
        } catch (Exception e) {
            // Silent fail - ne pas crasher si le diagnostic échoue
            System.debug(LoggingLevel.ERROR, '❌ Diagnostic IA failed: ' + e.getMessage());
        }
    }
}
