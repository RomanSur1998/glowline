import Foundation

final class AppRuntime {
    let menuBar: MenuBarController
    let lighting: LightingController
    let serialSupervisor: SerialSupervisor?

    init(menuBar: MenuBarController, lighting: LightingController, serialSupervisor: SerialSupervisor?) {
        self.menuBar = menuBar
        self.lighting = lighting
        self.serialSupervisor = serialSupervisor
    }
}
