import UIKit

/// Mantiene viva la generación cuando el usuario sale de la app.
///
/// iOS suspende la app pocos segundos después de pasar a background, lo que corta
/// el stream SSE a mitad de la respuesta. `beginBackgroundTask` pide a iOS una ventana
/// de ejecución extra (~30 s, a veces más) para que la respuesta termine en vez de
/// interrumpirse. No es ejecución infinita —iOS no la permite para data tasks— pero
/// cubre la gran mayoría de las respuestas. Se libera al terminar, al cancelar o cuando
/// el sistema expira la ventana.
@MainActor
enum BackgroundTaskKeeper {
    private static var taskID: UIBackgroundTaskIdentifier = .invalid

    static func begin() {
        guard taskID == .invalid else { return }
        taskID = UIApplication.shared.beginBackgroundTask(withName: "OpenPilot.generation") {
            end()
        }
    }

    static func end() {
        guard taskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskID)
        taskID = .invalid
    }
}