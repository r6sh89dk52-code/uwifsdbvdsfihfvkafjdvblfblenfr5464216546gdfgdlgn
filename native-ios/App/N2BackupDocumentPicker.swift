import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Copy an encrypted backup from any iOS Files provider into a short-lived,
/// protected local file. In-place security-scoped URLs from a provider are not
/// reliable once the document picker has disappeared.
enum N2BackupPickerCopy {
    enum Failure:Error,LocalizedError {
        case unsupportedFile
        case invalidFile
        var errorDescription:String? {
            switch self {
            case .unsupportedFile:
                return "Elige un respaldo de DANPER terminado en .danperbackup."
            case .invalidFile:
                return "El respaldo no es un archivo válido de entre 100 bytes y 42 MB."
            }
        }
    }
    private static let prefix="DANPER_RESTORE_PICKED_"
    static func stage(_ input:URL)throws->URL {
        guard input.pathExtension.lowercased()=="danperbackup" else {
            throw Failure.unsupportedFile
        }
        let scoped=input.startAccessingSecurityScopedResource()
        defer {if scoped {input.stopAccessingSecurityScopedResource()}}
        let values=try input.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard values.isSymbolicLink != true else {throw Failure.invalidFile}
        // Some Files providers omit fileSize until materialized. Reading the
        // provider's copy verifies it before making it the active selection.
        let bytes=try Data(contentsOf:input,options:.mappedIfSafe)
        guard (100...42*1024*1024).contains(bytes.count) else {throw Failure.invalidFile}
        let destination=FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix+UUID().uuidString+".danperbackup")
        try bytes.write(to:destination,options:[.atomic,.completeFileProtection])
        return destination
    }
    static func discard(_ url:URL?) {
        guard let url,url.deletingLastPathComponent().standardizedFileURL ==
            FileManager.default.temporaryDirectory.standardizedFileURL,
            url.lastPathComponent.hasPrefix(prefix),
            url.pathExtension.lowercased()=="danperbackup" else{return}
        try? FileManager.default.removeItem(at:url)
    }
}

/// A copy-mode document picker accepts custom .danperbackup files from Files,
/// iCloud Drive and third-party providers without retaining an expired scope.
struct N2BackupDocumentPicker:UIViewControllerRepresentable {
    let onPicked:(URL)->Void
    let onCancelled:()->Void
    let onError:(String)->Void
    func makeCoordinator()->Coordinator {
        Coordinator(onPicked:onPicked,onCancelled:onCancelled,onError:onError)
    }
    func makeUIViewController(context:Context)->UIDocumentPickerViewController {
        let backupType=UTType(filenameExtension:"danperbackup",conformingTo:.data) ?? .data
        let picker=UIDocumentPickerViewController(
            forOpeningContentTypes:[backupType,.item],asCopy:true)
        picker.delegate=context.coordinator
        picker.allowsMultipleSelection=false
        return picker
    }
    func updateUIViewController(_ controller:UIDocumentPickerViewController,context:Context){}
    final class Coordinator:NSObject,UIDocumentPickerDelegate {
        let onPicked:(URL)->Void
        let onCancelled:()->Void
        let onError:(String)->Void
        init(onPicked:@escaping(URL)->Void,onCancelled:@escaping()->Void,
             onError:@escaping(String)->Void) {
            self.onPicked=onPicked
            self.onCancelled=onCancelled
            self.onError=onError
        }
        func documentPicker(_ controller:UIDocumentPickerViewController,
                            didPickDocumentsAt urls:[URL]) {
            guard let url=urls.first else {
                onError("No se recibió ningún archivo del selector.")
                return
            }
            do {onPicked(try N2BackupPickerCopy.stage(url))}
            catch {onError(error.localizedDescription)}
        }
        func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController) {
            onCancelled()
        }
    }
}
