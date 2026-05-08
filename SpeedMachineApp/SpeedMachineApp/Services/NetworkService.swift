//
//  NetworkService.swift
//  SpeedMachineApp
//
//  Fetches the training program from the Speed Machine admin backend.
//  Falls back to UserDefaults cache, then to the bundled JSON.
//

import Foundation

final class NetworkService {
    static let shared = NetworkService()

    private let baseURL = "https://speed-machine-admin.vercel.app"
    private let versionKey = "remoteProgramVersion"
    private let dataKey = "remoteProgramData"
    static let statusKey = "networkServiceStatus"

    private init() {}

    // Called at app launch from TrainingProgramLoader. Non-blocking.
    func fetchProgramIfNeeded() async {
        print("🌐 [NetworkService] Starting fetch...")
        setStatus("Fetching version...")

        // Try up to 3 times — handles transient SSL/network errors
        var remoteVersion: String?
        for attempt in 1...3 {
            do {
                remoteVersion = try await fetchVersion()
                if remoteVersion != nil { break }
            } catch {
                print("🌐 [NetworkService] Attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < 3 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
            }
        }

        guard let remoteVersion else {
            print("🌐 [NetworkService] All attempts failed — using bundle only")
            setStatus("Network unavailable — using bundle")
            return
        }

        print("🌐 [NetworkService] Remote version: \(remoteVersion)")

        // Compare to cached version
        let cachedVersion = UserDefaults.standard.string(forKey: versionKey) ?? ""
        print("🌐 [NetworkService] Cached version: '\(cachedVersion)'")

        if remoteVersion == cachedVersion,
           let cachedData = UserDefaults.standard.data(forKey: dataKey) {
            print("🌐 [NetworkService] Cache is current — loading from cache")
            await MainActor.run {
                TrainingProgramLoader.shared.useRemoteProgram(cachedData)
                setStatus("Remote v\(remoteVersion) (cached)")
            }
            return
        }

        // Download the new version
        print("🌐 [NetworkService] Downloading program v\(remoteVersion)...")
        setStatus("Downloading program...")
        do {
            let data = try await fetchProgramData()
            print("🌐 [NetworkService] Downloaded \(data.count) bytes")
            UserDefaults.standard.set(data, forKey: dataKey)
            UserDefaults.standard.set(remoteVersion, forKey: versionKey)
            await MainActor.run {
                TrainingProgramLoader.shared.useRemoteProgram(data)
                setStatus("Remote v\(remoteVersion) ✓")
            }
            print("🌐 [NetworkService] Program updated to v\(remoteVersion)")
        } catch {
            print("🌐 [NetworkService] Download failed: \(error.localizedDescription)")
            setStatus("Download failed — using bundle")
        }
    }

    private func setStatus(_ status: String) {
        UserDefaults.standard.set(status, forKey: NetworkService.statusKey)
    }

    private func fetchVersion() async throws -> String? {
        guard let url = URL(string: "\(baseURL)/api/program/version") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("🌐 [NetworkService] Version endpoint status: \(statusCode)")
        guard statusCode == 200 else { return nil }

        let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
        // Use "version|publishedAt" as the cache key so any re-publish (even same
        // version number) invalidates the cache and forces a fresh download.
        return "\(decoded.version)|\(decoded.publishedAt)"
    }

    private func fetchProgramData() async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/program/current") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("🌐 [NetworkService] Program endpoint status: \(statusCode)")
        guard statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private struct VersionResponse: Decodable {
        let version: String
        let publishedAt: String
    }
}
