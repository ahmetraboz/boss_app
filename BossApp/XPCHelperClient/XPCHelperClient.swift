@preconcurrency import BossXPCBridge
import Cocoa
import Foundation

final class XPCHelperClient: NSObject, @unchecked Sendable {
    nonisolated static let shared = XPCHelperClient()

    private let serviceName = "com.ahmetboz.bossapp.helper"

    private var remoteService: RemoteXPCService<BossAppHelperProtocol>?
    private var connection: NSXPCConnection?

    deinit {
        connection?.invalidate()
    }

    // MARK: - Connection Management (Main Actor Isolated)

    @MainActor
    private func ensureRemoteService() -> RemoteXPCService<BossAppHelperProtocol> {
        if let existing = remoteService {
            return existing
        }

        let conn = NSXPCConnection(serviceName: serviceName)

        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.remoteService = nil
            }
        }

        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.remoteService = nil
            }
        }

        conn.resume()

        let service = RemoteXPCService<BossAppHelperProtocol>(
            connection: conn,
            remoteInterface: BossAppHelperProtocol.self
        )

        connection = conn
        remoteService = service
        return service
    }

    @MainActor
    private func getRemoteService() -> RemoteXPCService<BossAppHelperProtocol>? {
        remoteService
    }

    // MARK: - Keyboard Brightness

    nonisolated func isKeyboardBrightnessAvailable() async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.isKeyboardBrightnessAvailable { available in
                    continuation.resume(returning: available)
                }
            }
        } catch {
            return false
        }
    }

    nonisolated func currentKeyboardBrightness() async -> Float? {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            let result: NSNumber? = try await service.withContinuation { service, continuation in
                service.currentKeyboardBrightness { value in
                    continuation.resume(returning: value)
                }
            }
            return result?.floatValue
        } catch {
            return nil
        }
    }

    nonisolated func setKeyboardBrightness(_ value: Float) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.setKeyboardBrightness(value) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }

    // MARK: - Screen Brightness

    nonisolated func isScreenBrightnessAvailable() async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.isScreenBrightnessAvailable { available in
                    continuation.resume(returning: available)
                }
            }
        } catch {
            return false
        }
    }

    nonisolated func currentScreenBrightness() async -> Float? {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            let result: NSNumber? = try await service.withContinuation { service, continuation in
                service.currentScreenBrightness { value in
                    continuation.resume(returning: value)
                }
            }
            return result?.floatValue
        } catch {
            return nil
        }
    }

    nonisolated func setScreenBrightness(_ value: Float) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.setScreenBrightness(value) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }

    // MARK: - Screenshot Paths

    nonisolated func getScreenshotPaths(limit: Int = 100) async -> [String] {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.getScreenshotPaths(limit: limit) { paths in
                    continuation.resume(returning: paths)
                }
            }
        } catch {
            return []
        }
    }

    nonisolated func getScreenshotPaths(inFolder path: String, limit: Int = 100) async -> [String] {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.getScreenshotPaths(inFolder: path, limit: limit) { paths in
                    continuation.resume(returning: paths)
                }
            }
        } catch {
            return []
        }
    }

    nonisolated func readFileData(path: String) async -> Data? {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            let result: NSData? = try await service.withContinuation { service, continuation in
                service.readFileData(atPath: path) { data in
                    continuation.resume(returning: data)
                }
            }
            return result as Data?
        } catch {
            return nil
        }
    }

    nonisolated func trashFile(path: String) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.trashFile(atPath: path) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }

    nonisolated func openFile(path: String) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.openFile(atPath: path) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }

    nonisolated func revealFile(path: String) async -> Bool {
        do {
            let service = await MainActor.run {
                ensureRemoteService()
            }
            return try await service.withContinuation { service, continuation in
                service.revealFile(atPath: path) { success in
                    continuation.resume(returning: success)
                }
            }
        } catch {
            return false
        }
    }
}
