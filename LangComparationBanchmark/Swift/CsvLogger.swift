//
//  CsvLogger.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 08.10.2025.
//

import Foundation

public final class CsvLogger {
    public let sessionFolder: URL
    private let casesFolder: URL
    private let summaryURL: URL
    private var wroteSummaryHeader = false
    
    public init(sessionName: String? = nil) throws {
        let dateStamp = sessionName ?? ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        sessionFolder = docs.appendingPathComponent("Benchmarks").appendingPathComponent(dateStamp, isDirectory: true)
        casesFolder = sessionFolder.appendingPathComponent("cases", isDirectory: true)
        summaryURL = sessionFolder.appendingPathComponent("summary.csv")
        try FileManager.default.createDirectory(at: casesFolder, withIntermediateDirectories: true)
    }
    
    public func writePerCase(_ result: CaseResult) throws {
        let url = casesFolder.appendingPathComponent("\(result.key)_\(result.language).csv")
        var csv = "sampleIndex,duration_ns\n"
        for s in result.samples {
            csv += "\(s.index),\(Int64(s.durationNs))\n"
        }
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public func appendSummary(_ result: CaseResult) throws {
        let head = "key,name,language,avg_ns,median_ns,std_ns,min_ns,max_ns,samples,count\n"
        let line = "\(result.key),\"\(result.name)\",\(result.language),\(Int64(result.stats.avg)),\(Int64(result.stats.median)),\(Int64(result.stats.std)),\(Int64(result.stats.min)),\(Int64(result.stats.max)),\"\(result.samples.map{$0.durationNs}.map{Int64($0)}.map(String.init).joined(separator: " "))\",\(result.samples.count)\n"
        if !FileManager.default.fileExists(atPath: summaryURL.path) {
            try head.write(to: summaryURL, atomically: true, encoding: .utf8)
            wroteSummaryHeader = true
        } else if !wroteSummaryHeader {
            // у разі перезапуску
            wroteSummaryHeader = true
        }
        let handle = try FileHandle(forWritingTo: summaryURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        if let data = line.data(using: .utf8) { try handle.write(contentsOf: data) }
    }
    
    public var summaryFileURL: URL { summaryURL }
}

func splitCSV(line: String) -> [String] {
    var out: [String] = []
    var field = ""
    var quoted = false
    for ch in line {
        if ch == "\"" {
            quoted.toggle()
            field.append(ch)
            continue
        }
        if ch == "," && !quoted {
            out.append(field)
            field = ""
        } else {
            field.append(ch)
        }
    }
    out.append(field)
    return out
}

func parseSummaryRows(from url: URL,
                      sessionId: String,
                      sessionDateFallback: Date) throws -> [SummaryRow] {
    let txt = try String(contentsOf: url, encoding: .utf8)
    var lines = txt.split(separator: "\n").map(String.init)
    guard !lines.isEmpty else { return [] }

    if lines.first?.lowercased().contains("key,name,language") == true {
        lines.removeFirst() // заголовок
    }

    // Спробуємо дістати дату з імені папки; інакше — дата створення папки
    let sessionDate = ISO8601DateFormatter().date(from: sessionId) ?? sessionDateFallback

    return lines.compactMap { line in
        let p = splitCSV(line: line)
        guard p.count >= 10 else { return nil }

        let key    = p[0]
        let name   = p[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let lang   = p[2]
        let avg    = Double(p[3]) ?? 0
        let median = Double(p[4]) ?? 0
        let std    = Double(p[5]) ?? 0
        let minv   = Double(p[6]) ?? 0
        let maxv   = Double(p[7]) ?? 0
        let count  = Int(p[9]) ?? 0

        return SummaryRow(
            sessionId: sessionId,
            sessionDate: sessionDate,
            key: key, name: name, language: lang,
            avgNs: avg,
            medianNs: median,
            stdNs: std,
            minNs: minv,
            maxNs: maxv,
            sampleCount: count
        )
    }
}

func parseSummaryRows(from url: URL) throws -> [SummaryRow] {
    let sessionFolder = url.deletingLastPathComponent()
    let sessionId = sessionFolder.lastPathComponent
    let sessionDateFallback =
        (try? sessionFolder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast

    return try parseSummaryRows(from: url,
                                sessionId: sessionId,
                                sessionDateFallback: sessionDateFallback)
}
