import Foundation

final class LiveFrameSettings {
    @Locked var colorOrder: ColorOrder
    @Locked var fixedAdaHeader: Bool

    init(colorOrder: ColorOrder, fixedAdaHeader: Bool) {
        self.colorOrder = colorOrder
        self.fixedAdaHeader = fixedAdaHeader
    }
}
