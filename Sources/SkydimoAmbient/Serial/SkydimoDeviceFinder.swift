import Foundation
import IOKit
import IOKit.serial

struct SerialDeviceInfo {
    let path: String
    let vendorID: Int?
    let productID: Int?
}

enum SkydimoDeviceFinder {
    static let knownVendorIDs: Set<Int> = [
        0x1A86,
        0x10C4,
        0x0403,
        0x067B,
        0x2341,
        0x2A03,
        0x303A,
    ]

    static func listSerialDevices() -> [SerialDeviceInfo] {
        var result: [SerialDeviceInfo] = []
        let matching = IOServiceMatching(kIOSerialBSDServiceValue)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return result
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard
                let calloutRef = IORegistryEntryCreateCFProperty(
                    service, kIOCalloutDeviceKey as CFString, kCFAllocatorDefault, 0
                )
            else { continue }
            guard let path = calloutRef.takeRetainedValue() as? String, !path.isEmpty else { continue }

            var vendorID: Int?
            var productID: Int?
            var current = service
            IOObjectRetain(current)
            while true {
                if let v = IORegistryEntryCreateCFProperty(current, "idVendor" as CFString, kCFAllocatorDefault, 0) {
                    vendorID = (v.takeRetainedValue() as? NSNumber)?.intValue
                }
                if let p = IORegistryEntryCreateCFProperty(current, "idProduct" as CFString, kCFAllocatorDefault, 0) {
                    productID = (p.takeRetainedValue() as? NSNumber)?.intValue
                }
                if vendorID != nil {
                    IOObjectRelease(current)
                    break
                }
                var parent: io_registry_entry_t = 0
                let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
                IOObjectRelease(current)
                if kr != KERN_SUCCESS || parent == 0 { break }
                current = parent
            }

            result.append(SerialDeviceInfo(path: path, vendorID: vendorID, productID: productID))
        }
        return result
    }

    static func autoDetect() -> String? {
        listSerialDevices().first { device in
            guard let v = device.vendorID else { return false }
            return knownVendorIDs.contains(v)
        }?.path
    }
}
