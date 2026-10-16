import Foundation

/// Export gate exclusively for bundled, synthetic N1s fixtures. It does not
/// accept imports, backups, worker records or the mutable clinical ledger.
public enum N1sDemoWorkbookKind: String, CaseIterable, Sendable {
    case indicator, nursing

    public var filename: String {
        switch self {
        case .indicator: return "DANPER_INDICADOR_DEMO_NO_OFICIAL.xlsx"
        case .nursing: return "DANPER_KARDEX_DEMO_NO_OFICIAL.xlsx"
        }
    }
}

public enum N1sDemoExportError: Error, Equatable {
    case nonDemoManifest, invalidWorkbook
}

public enum N1sDemoExportBridge {
    public static func create(_ kind: N1sDemoWorkbookKind,
                              base: Data, manifest: Data) throws -> Data {
        guard manifest.count < 4_000_000,
              let object = try? JSONSerialization.jsonObject(with: manifest) as? [String:Any],
              object["demoFixtureOnly"] as? Bool == true,
              object["demoFixtureTag"] as? String == "DANPER_N1S_SYNTHETIC_2026",
              object["demoKind"] as? String == kind.rawValue else {
            throw N1sDemoExportError.nonDemoManifest
        }
        let book: N1sExcelResult
        switch kind {
        case .indicator:
            book = try N1sFullExcelWriter.exportIndicator(base: base, manifest: manifest)
        case .nursing:
            book = try N1sNursingExcelWriter.export(base: base, manifest: manifest)
        }
        let expected = kind == .indicator ? 10 : 1
        let rows = kind == .indicator ? 2 : 98
        guard !book.canUseClinicalData,
              book.sheetCount == expected,
              book.writtenRows == rows,
              book.xlsx.count > 20_000,
              book.xlsx.starts(with: [0x50,0x4B,0x03,0x04]) else {
            throw N1sDemoExportError.invalidWorkbook
        }
        return book.xlsx
    }
}
