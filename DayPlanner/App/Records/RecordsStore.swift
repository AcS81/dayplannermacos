import Combine
import Foundation

/// Lightweight in-memory records helper used by the calendar confirmation loop.
final class RecordsStore: ObservableObject {
    @Published private(set) var records: [Record] = []
    
    func seed(with existing: [Record]) {
        records = existing.sorted { $0.confirmedAt > $1.confirmedAt }
    }
    
    func add(_ record: Record) {
        records.insert(record, at: 0)
    }
    
    func remove(_ recordId: UUID) {
        records.removeAll { $0.id == recordId }
    }
}
