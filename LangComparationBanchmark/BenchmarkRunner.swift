//
//  BenchmarkRunner.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 08.10.2025.
//

import Foundation
import UIKit
import CoreGraphics

public struct Sample: Codable {
    public let index: Int
    public let durationNs: Double
}
public struct Stats {
    public let avg, median, std, min, max: Double
}
public struct CaseResult {
    public let key: String
    public let name: String
    public let language: String
    public let samples: [Sample]
    public let stats: Stats
}

public struct SummaryRow: Identifiable, Hashable {
    public var id: String { "\(sessionId)|\(key)|\(language)" }
    public let sessionId: String
    public let sessionDate: Date

    public let key: String
    public let name: String

    public let language: String

    public let avgNs: Double
    public let medianNs: Double
    public let stdNs: Double
    public let minNs: Double
    public let maxNs: Double

    public let sampleCount: Int
}

final class BenchmarkRunner {
    let benchmarks: [SwiftBenchmark]
    let logger: CsvLogger
    
    init(benchmarks: [SwiftBenchmark], logger: CsvLogger) {
        self.benchmarks = benchmarks
        self.logger = logger
    }
    
    public func runAll() {
        print("Swift Benchmarks (ns per run)\n")
        for b in benchmarks {
            let times = b.run()
            let samples = times.enumerated().map { Sample(index: $0.offset, durationNs: $0.element) }
            let s = stats(times)
            let result = CaseResult(
                key: b.key,
                name: b.name,
                language: "Swift",
                samples: samples,
                stats: .init(avg: s.avg, median: s.median, std: s.std, min: s.min, max: s.max)
            )
            do {
                try logger.writePerCase(result)
                try logger.appendSummary(result)
            } catch {
                print("CSV error:", error.localizedDescription)
            }
            print("\n==> \(b.name)")
            print(String(format: "avg: %.0f ns, std: %.0f, median: %.0f, min: %.0f, max: %.0f",
                         s.avg, s.std, s.median, s.min, s.max))
        }
    }
}
