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
    private let parser = IORegistryBatteryParser()

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

        return parser.parse(output: output)
    }
}

struct MockBatteryReader: BatteryReader {
    let devices: [DeviceBatterySnapshot]

    func readBatterySnapshots() throws -> [DeviceBatterySnapshot] {
        devices
    }
}
