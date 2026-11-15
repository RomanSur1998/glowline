import Foundation

final class AppRuntime {
    let menuBar: MenuBarController
    let lighting: LightingController
    let serialSupervisor: SerialSupervisor?
    let powerMonitor: PowerEventMonitor
    let hotKey: GlobalHotKey

    init(
        menuBar: MenuBarController, lighting: LightingController, serialSupervisor: SerialSupervisor?, powerMonitor: PowerEventMonitor,
        hotKey: GlobalHotKey
    ) {
        self.menuBar = menuBar
        self.lighting = lighting
        self.serialSupervisor = serialSupervisor
        self.powerMonitor = powerMonitor
        self.hotKey = hotKey
    }
}
