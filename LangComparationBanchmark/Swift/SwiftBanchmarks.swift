//
//  File.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 07.10.2025.
//

import Foundation
import os

@inline(__always)
func nowNanos() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

func measure(samples: Int = 10, warmup: Int = 3, label: String, _ block: () -> Void) -> [Double] {
    for _ in 0..<warmup {
        block()
    }
    var results: [Double] = []
    for _ in 0..<samples {
        let t0 = nowNanos()
        block()
        let t1 = nowNanos()
        results.append(Double(t1 &- t0))
    }
    return results
}

func stats(_ values: [Double]) -> (avg: Double, std: Double, min: Double, max: Double, median: Double) {
    let n = Double(values.count)
    let avg = values.reduce(0, +) / n
    let minv = values.min() ?? 0
    let maxv = values.max() ?? 0
    let sorted = values.sorted()
    let median = sorted[sorted.count/2]
    let variance = values.reduce(0.0) {
        $0 + ($1 - avg) * ($1 - avg)
    } / n
    return (avg, sqrt(variance), minv, maxv, median)
}

protocol SwiftBenchmark {
    var key: String { get }
    var name: String { get }
    func run() -> [Double]
}

// MARK: - Swift Benchmarks

struct ArrayAppendReserve: SwiftBenchmark {
    let count: Int
    var key: String { "array_append_reserve" }
    var name: String { "Array.append with reserve(\(count))" }
    func run() -> [Double] {
        measure(label: name) {
            var a: [Int] = []
            a.reserveCapacity(count)
            for i in 0..<count {
                a.append(i)
            }
        }
    }
}

struct ArrayAppendNoReserve: SwiftBenchmark {
    let count: Int
    var key: String { "array_append_no_reserve" }
    var name: String { "Array.append without reserve(\(count))" }
    func run() -> [Double] {
        measure(label: name) {
            var a: [Int] = []
            for i in 0..<count {
                a.append(i)
            }
        }
    }
}

struct ArrayInsertAtZero: SwiftBenchmark {
    let count: Int
    var key: String { "array_insert_at_zero" }
    var name: String { "Array.insert at 0 (\(count))" }
    func run() -> [Double] {
        measure(label: name) {
            var a: [Int] = []
            for i in 0..<count {
                a.insert(i, at: 0)
            }
        }
    }
}

struct DictionaryLookupHit: SwiftBenchmark {
    let lookups: Int
    let size: Int
    var key: String { "dict_lookup_hit" }
    var name: String { "Dictionary lookup hit (size=\(size), ops=\(lookups))" }
    func run() -> [Double] {
        var d: [Int: Int] = [:]
        d.reserveCapacity(size)
        for i in 0..<size { d[i] = i }
        return measure(label: name) {
            var s = 0
            for i in 0..<lookups {
                s &+= d[i % size]!
            }
            _ = s
        }
    }
}

struct SetContains: SwiftBenchmark {
    let lookups: Int
    let size: Int
    var key: String { "set_contains" }
    var name: String { "Set.contains (size=\(size), ops=\(lookups))" }
    func run() -> [Double] {
        var s = Set<Int>()
        s.reserveCapacity(size)
        for i in 0..<size {
            s.insert(i)
        }
        return measure(label: name) {
            var hits = 0
            for i in 0..<lookups {
                if s.contains(i % size) {
                    hits &+= 1
                }
            }
            _ = hits
        }
    }
}

struct ForLoopVsForEach: SwiftBenchmark {
    let iterations: Int
    var key: String { "for_loop_vs_for_each" }
    var name: String { "for vs forEach (\(iterations))" }
    func run() -> [Double] {
        let arr = Array(0..<iterations)
        let s1 = measure(label: name + " - for") {
            var sum = 0
            for v in arr {
                sum &+= v
            }
            _ = sum
        }
        let s2 = measure(label: name + " - forEach") {
            var sum = 0
            arr.forEach {
                sum &+= $0
            }
            _ = sum
        }
        return s1 + s2
    }
}

struct ClosureNonCaptured: SwiftBenchmark {
    var key: String { "closure-non-captured" }
    let calls: Int
    var name: String { "Closure call overhead non-capturing calls=\(calls)" }
    func run() -> [Double] {
        let nonCap: () -> Int = { 1 }
        let s1 = measure(label: name + " - non-capturing") {
            var acc = 0
            for _ in 0..<calls {
                acc &+= nonCap()
            }
            _ = acc
        }
        return s1
    }
}

struct ClosureCaptured: SwiftBenchmark {
    var key: String { "closure-captured" }
    let calls: Int
    var name: String { "Closure call overhead capturing calls=\(calls)" }
    func run() -> [Double] {
        let value = 1
        let cap: () -> Int = { [value] in value }
        let s1 = measure(label: name + " - capturing") {
            var acc = 0
            for _ in 0..<calls {
                acc &+= cap()
            }
            _ = acc
        }
        return s1
    }
}

struct AutoreleasePoolOverhead: SwiftBenchmark {
    let allocations: Int
    var key: String { "autoreleasepool_overhead" }
    var name: String { "Autoreleasepool overhead (\(allocations) NSNumber)" }
    func run() -> [Double] {
        measure(label: name) {
            autoreleasepool {
                var sum = 0
                for i in 0..<allocations {
                    let n = NSNumber(value: i)
                    sum &+= n.intValue
                }
                _ = sum
            }
        }
    }
}

struct StringConcatination: SwiftBenchmark {
    let parts: Int
    var key: String { "string_concatenation" }
    var name: String { "String concatenation (\(parts) parts)" }
    func run() -> [Double] {
        let s1 = measure(label: name) {
            var s = ""
            for i in 0..<parts {
                s += String(i)
            }
            _ = s
        }
        return s1
    }
}

struct StringReserveAppend: SwiftBenchmark {
    let parts: Int
    var key: String { "string_reserve_append" }
    var name: String { "String reserve append (\(parts) parts)" }
    func run() -> [Double] {
        let s1 = measure(label: name) {
            var s = ""
            s.reserveCapacity(parts * 2)
            for i in 0..<parts {
                s.append(String(i))
            }
            _ = s
        }
        return s1
    }
}
