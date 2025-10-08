//
//  Objc+Helper.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 08.10.2025.
//

import Foundation

private var sharedLoggerForC: CsvLogger?

@_cdecl("bench_open_session_c")
public func bench_open_session_c(_ name: UnsafePointer<CChar>?) {
    let session = name.flatMap { String(cString: $0) }
    sharedLoggerForC = try? CsvLogger(sessionName: session)
}

@_cdecl("bench_log_samples_c")
public func bench_log_samples_c(_ key: UnsafePointer<CChar>,
                                _ caseName: UnsafePointer<CChar>,
                                _ language: UnsafePointer<CChar>,
                                _ samples: UnsafePointer<Double>,
                                _ count: Int32) {
    guard let logger = sharedLoggerForC else { return }
    let k = String(cString: key)
    let n = String(cString: caseName)
    let lang = String(cString: language)
    let buffer = UnsafeBufferPointer(start: samples, count: Int(count))
    let s = Array(buffer)
    let ss = s.enumerated().map { Sample(index: $0.offset, durationNs: $0.element) }
    let avg = s.reduce(0, +) / Double(s.count)
    let sorted = s.sorted()
    let median = sorted[sorted.count/2]
    let minv = s.min() ?? 0, maxv = s.max() ?? 0
    let variance = s.reduce(0) { $0 + pow($1 - avg, 2) } / Double(s.count)
    let std = sqrt(variance)
    let result = CaseResult(key: k, name: n, language: lang,
                            samples: ss, stats: .init(avg: avg, median: median, std: std, min: minv, max: maxv))
    try? logger.writePerCase(result)
    try? logger.appendSummary(result)
}

@_cdecl("bench_close_session_c")
public func bench_close_session_c() {
    sharedLoggerForC = nil
}
