//
//  RunAllBanchmarks.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 08.10.2025.
//

import Foundation

public func runAllBenchmarks(sessionName: String? = nil,
                             completion: @escaping (URL) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            // 1) Єдина назва для сесії (спільна для Swift і ObjC)
            let name = sessionName ?? {
                let f = ISO8601DateFormatter()
                let s = f.string(from: Date()).replacingOccurrences(of: ":", with: "-")
                return s
            }()

            // 2) Swift-логер під це ім'я
            let logger = try CsvLogger(sessionName: name)

            // 3) ВІДКРИТИ ObjC-сесію ТІЄЮ Ж НАЗВОЮ (щоб писали в одну папку)
            name.withCString { cstr in
                bench_open_session_c(cstr)
            }

            // 4) Запускаємо Swift-бенчі (вони пишуть у logger(sessionName: name))
            let swiftRunner = BenchmarkRunner(benchmarks: [
                ArrayAppendReserve(count: 100_000),
                ArrayAppendNoReserve(count: 100_000),
                ArrayInsertAtZero(count: 10_000),
                DictionaryLookupHit(lookups: 2_000_000, size: 100_000),
                SetContains(lookups: 2_000_000, size: 100_000),
                ClosureNonCaptured(calls: 5_000_000),
                ClosureCaptured(calls: 5_000_000),
                AutoreleasePoolOverhead(allocations: 500_000),
                StringConcatination(parts: 20_000),
                StringReserveAppend(parts: 20_000)
            ], logger: logger)
            swiftRunner.runAll()

            // 5) Запускаємо ObjC-бенчі (вони теж пишуть у цю ж сесію, бо вже відкрито bench_open_session_c(name))
            runObjCBenchmarks()

            // 6) Закриваємо ObjC-сесію
            bench_close_session_c()

            // 7) Повертаємо папку сесії
            let folder = try sessionFolder(named: name)
            DispatchQueue.main.async {
                completion(folder)
            }
        } catch {
            print("runAllBenchmarks error:", error)
        }
    }
}

func sessionFolder(named name: String) throws -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    return docs.appendingPathComponent("Benchmarks").appendingPathComponent(name, isDirectory: true)
}
