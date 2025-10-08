//
//  OperationChartsListView.swift
//  LangComparationBanchmark
//
//  Created by Serhii Navka on 07.10.2025.
//

import SwiftUI
import Charts

struct OperationChartsListView: View {
    @StateObject private var store = BenchmarkHistoryStore()
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Group {
                if store.rows.isEmpty {
                    VStack(spacing: 12) {
                        Text("Історія порожня")
                            .foregroundColor(.secondary)
                        Button("Оновити") {
                            store.loadAll()
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            let grouped = Dictionary(grouping: store.rows, by: { $0.key })
                            ForEach(grouped.keys.sorted(), id: \.self) { key in
                                let rowsForKey = grouped[key] ?? []
                                OperationChartSection(
                                    key: key,
                                    rows: rowsForKey,
                                    latestSessionId: store.latestSessionId
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Операції / Графіки")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Видалити історію", systemImage: "trash")
                        }
                        Button {
                            store.loadAll()
                        } label: {
                            Label("Оновити", systemImage: "arrow.clockwise")
                        }
                        Button {
                            runAllBenchmarks { folder in
                                print("Folder: \(folder)")
                                store.loadAll()
                            }
                        } label: {
                            Label("Старт бенчмарки", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear { store.loadAll() }
            .alert("Видалити всю історію бенчмарків?", isPresented: $showDeleteConfirm) {
                Button("Видалити", role: .destructive) {
                    do {
                        try store.deleteAllHistory()
                    } catch {
                        print("delete error:", error)
                    }
                }
                Button("Скасувати", role: .cancel) { }
            } message: {
                Text("Буде видалено каталог Documents/Benchmarks разом із CSV та графіками.")
            }
        }
    }
}

@available(iOS 16.0, *)
struct OperationChartSection: View {
    let key: String
    let rows: [SummaryRow]
    let latestSessionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rows.first?.name ?? key)
                .font(.headline)
            
            Chart(historyData) { item in
                BarMark(
                    x: .value("Сесія", item.sessionShort),
                    y: .value("Середній час, нс", item.avgNs)
                )
                .foregroundStyle(by: .value("Мова", item.language))
            }
            .chartYAxisLabel("нс")
            .frame(height: 260)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var historyData: [ChartPoint] {
        rows
            .sorted {
                $0.sessionDate < $1.sessionDate
            }.map {
                ChartPoint(language: $0.language, sessionShort: short($0.sessionId), avgNs: $0.avgNs)
            }
    }

    private func short(_ sessionId: String) -> String {
        if let d = ISO8601DateFormatter().date(from: sessionId) {
            let df = DateFormatter()
            df.dateFormat = "MM-dd HH:mm"
            return df.string(from: d)
        }
        return String(sessionId.suffix(12))
    }

    struct ChartPoint: Identifiable {
        var id = UUID()
        let language: String
        let sessionShort: String
        let avgNs: Double
    }
}
