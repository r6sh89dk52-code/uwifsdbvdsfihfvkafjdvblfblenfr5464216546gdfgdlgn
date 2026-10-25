import SwiftUI

/// Three visible stages in Build 222: configure, review, share.
/// This is presentation only; the original Swift Excel validators still
/// determine whether a workbook can be generated.
struct N2Build222ExportProgress:View {
    let titles:[String]
    var body:some View {
        HStack(spacing:6) {
            ForEach(titles.indices,id:\.self) {index in
                HStack(spacing:5) {
                    Text(String(index+1))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width:22,height:22)
                        .background(DanperStyle.red,in:Circle())
                    Text(titles[index])
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.72)
                }
                .frame(maxWidth:.infinity)
            }
        }
        .padding(12)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:15))
        .accessibilityElement(children:.combine)
        .accessibilityLabel("Etapas: "+titles.joined(separator:", "))
    }
}

struct N2Build222StageHeading:View {
    let step:Int
    let title:String
    var body:some View {
        HStack(alignment:.center,spacing:11) {
            Text(String(step))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width:34,height:34)
                .background(DanperStyle.red,in:RoundedRectangle(cornerRadius:11))
            Text(title).font(.headline.weight(.bold))
            Spacer(minLength:0)
        }
        .accessibilityElement(children:.combine)
    }
}
