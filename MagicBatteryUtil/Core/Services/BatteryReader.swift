//
//  BatteryReader.swift
//  MagicBatteryUtil
//

import Foundation

protocol BatteryReader: Sendable {
    func readBatterySnapshots() throws -> [DeviceBatterySnapshot]
}

struct BatteryReadResult {
    let devices: [DeviceBatterySnapshot]
    let diagnostics: [String]
}

enum BatteryReaderError: LocalizedError {
    case commandFailed(String)
    case unreadableOutput

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .unreadableOutput:
            return "The battery reader returned output that could not be parsed."
        }
    }
}

final class IORegistryBatteryReader: BatteryReader, @unchecked Sendable {
    func readBatterySnapshots() throws -> [DeviceBatterySnapshot] {
        try readBatteryResult().devices
    }

    func readBatteryResult() throws -> BatteryReadResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-l", "-c", "AppleDeviceManagementHIDEventService"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw BatteryReaderError.unreadableOutput
        }

        guard process.terminationStatus == 0 else {
            throw BatteryReaderError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return parse(output: output)
    }

    private func parse(output: String) -> BatteryReadResult {
        let blocks = output
            .components(separatedBy: "+-o AppleDeviceManagementHIDEventService")
            .dropFirst()

        let now = Date()
        var diagnostics: [String] = []
        let devices = blocks.compactMap { block in
            let properties = parseProperties(in: block)
            let kind = resolveKind(from: properties)
            let serialNumber = properties["SerialNumber"]?.nilIfBlank
            let address = properties["DeviceAddress"]?.nilIfBlank
            let id = serialNumber ?? address ?? "product-\(properties["ProductID"] ?? "unknown")-\(kind.rawValue)"
            let productName = properties["Product"]?.nilIfBlank
                ?? inferredDisplayName(kind: kind, properties: properties, fallbackID: id)
            let batteryPercent = properties["BatteryPercent"].flatMap(Int.init)
            let productID = properties["ProductID"].flatMap(Int.init)

             if batteryPercent == nil {
                diagnostics.append("Battery percentage unavailable for \(productName).")
            }

            return DeviceBatterySnapshot(
                id: id,
                productName: productName,
                kind: kind,
                batteryPercent: batteryPercent,
                connectionState: .connected,
                lastSeenAt: now,
                source: .ioRegistry,
                productID: productID,
                serialNumber: serialNumber
            )
        }
        return BatteryReadResult(devices: devices, diagnostics: diagnostics)
    }

    private func parseProperties(in block: String) -> [String: String] {
        var properties: [String: String] = [:]

        for rawLine in block.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("\""), let separatorRange = line.range(of: "\" = ") else {
                continue
            }

            let key = String(line[line.startIndex..<separatorRange.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            var value = String(line[separatorRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasSuffix(",") {
                value.removeLast()
            }
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            properties[key] = value
        }

        return properties
    }

    private func resolveKind(from properties: [String: String]) -> DeviceKind {
        let productText = properties["Product"]?.lowercased() ?? ""
        if productText.contains("keyboard") {
            return .keyboard
        }
        if productText.contains("mouse") {
            return .mouse
        }
        if productText.contains("trackpad") {
            return .trackpad
        }

        let joinedValues = properties.values.joined(separator: " ").uppercased()
        if joinedValues.contains("KBL") || joinedValues.contains("KB") {
            return .keyboard
        }
        if joinedValues.contains("MOL") || joinedValues.contains("MO") {
            return .mouse
        }
        if joinedValues.contains("TP") {
            return .trackpad
        }

        switch properties["ProductID"].flatMap(Int.init) {
        case 615:
            return .keyboard
        case 617:
            return .mouse
        case 618:
            return .trackpad
        default:
            return .unknown
        }
    }

    private func inferredDisplayName(kind: DeviceKind, properties: [String: String], fallbackID: String) -> String {
        switch kind {
        case .keyboard:
            return "Magic Keyboard"
        case .mouse:
            return "Magic Mouse"
        case .trackpad:
            return "Magic Trackpad"
        case .unknown:
            let suffix = String(fallbackID.suffix(4))
            return "Magic Accessory \(suffix)"
        }
    }
}

struct MockBatteryReader: BatteryReader {
    let devices: [DeviceBatterySnapshot]

    func readBatterySnapshots() throws -> [DeviceBatterySnapshot] {
        devices
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
