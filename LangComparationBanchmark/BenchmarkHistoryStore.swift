//
//  BenchmarkHistoryStore.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 08.10.2025.
//

import Foundation
import Combine

final class BenchmarkHistoryStore: ObservableObject {
    @Published var rows: [SummaryRow] = []
    @Published var sessions: [String] = []
    @Published var latestSessionId: String?

    private var docsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    private var rootURL: URL { docsURL.appendingPathComponent("Benchmarks", isDirectory: true) }

    func loadAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            var allRows: [SummaryRow] = []
            var sessionIds: [String] = []

            do {
                let folders = (try? FileManager.default.contentsOfDirectory(
                    at: self.rootURL,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []

                // Сортуємо за датою створення (спадаючий)
                let sorted = folders.sorted {
                    let aDate = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let bDate = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    return aDate > bDate
                }

                for folder in sorted where folder.hasDirectoryPath {
                    let sessionId = folder.lastPathComponent
                    sessionIds.append(sessionId)

                    let sessionDate = (try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let summary = folder.appendingPathComponent("summary.csv")
                    if FileManager.default.fileExists(atPath: summary.path) {
                        let rows = try parseSummaryRows(from: summary,
                                                        sessionId: sessionId,
                                                        sessionDateFallback: sessionDate)
                        allRows.append(contentsOf: rows)
                    }
                }

                DispatchQueue.main.async {
                    self.rows = allRows
                    self.sessions = sessionIds
                    self.latestSessionId = sessionIds.first
                }
            } catch {
                print("loadAll error:", error)
                DispatchQueue.main.async {
                    self.rows = []
                    self.sessions = []
                    self.latestSessionId = nil
                }
            }
        }
    }

    /// Видаляє весь каталог Benchmarks (усю історію)
    func deleteAllHistory() throws {
        if FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
        DispatchQueue.main.async {
            self.rows = []
            self.sessions = []
            self.latestSessionId = nil
        }
    }
}
