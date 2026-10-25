import SwiftUI
import UIKit
import DanperCore

struct N2ExpiryTextField:UIViewRepresentable {
    @Binding var text:String
    func makeCoordinator()->Coordinator {Coordinator(self)}
    func makeUIView(context:Context)->UITextField {
        let field=UITextField()
        field.placeholder="DD/MM/AA (ej. 20/10/30)"
        field.keyboardType = .numberPad
        field.font = .preferredFont(forTextStyle:.body)
        field.adjustsFontForContentSizeCategory=true
        field.accessibilityLabel="Fecha de vencimiento, día mes y año"
        field.accessibilityIdentifier="inventory-expiry-text"
        field.delegate=context.coordinator
        return field
    }
    func updateUIView(_ field:UITextField,context:Context) {
        context.coordinator.parent=self
        if field.text != text {field.text=text}
    }
    final class Coordinator:NSObject,UITextFieldDelegate {
        var parent:N2ExpiryTextField
        init(_ parent:N2ExpiryTextField){self.parent=parent}
        func textField(_ field:UITextField,shouldChangeCharactersIn range:NSRange,
                       replacementString replacement:String)->Bool {
            guard replacement.allSatisfy({($0.isASCII && $0.isNumber) || $0=="/"}),
                  let source=field.text,let edit=Range(range,in:source) else{return false}
            var candidate=source.replacingCharacters(in:edit,with:replacement)
            guard candidate.filter(\.isNumber).count<=6 else{return false}
            var caret=range.location+(replacement as NSString).length
            if replacement.isEmpty && String(source[edit])=="/" && range.location>0 {
                let prior=range.location-1
                if let digit=Range(NSRange(location:prior,length:1),in:candidate) {
                    candidate.removeSubrange(digit);caret=prior
                }
            }
            let numericOffset=candidate.prefix(caret).filter(\.isNumber).count
            let formatted=N2ExpiryEntry.format(candidate)
            field.text=formatted;parent.text=formatted
            var offset=0,count=0
            for character in formatted {
                if count>=numericOffset {break}
                offset+=1
                if character.isNumber {count+=1}
            }
            if let position=field.position(from:field.beginningOfDocument,offset:offset) {
                field.selectedTextRange=field.textRange(from:position,to:position)
            }
            return false
        }
    }
}
