import Foundation

final class AppRuntime {
    let menuBar: MenuBarController
    let captureSupervisor: CaptureSupervisor
    let serialSupervisor: SerialSupervisor?

    init(menuBar: MenuBarController, captureSupervisor: CaptureSupervisor, serialSupervisor: SerialSupervisor?) {
        self.menuBar = menuBar
        self.captureSupervisor = captureSupervisor
        self.serialSupervisor = serialSupervisor
    }
}
