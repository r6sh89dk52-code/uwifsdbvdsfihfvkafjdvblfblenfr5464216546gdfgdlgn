import SwiftUI
import UIKit

/// Reusable visual language for the entire native preview. Respect Dynamic Type,
/// Dark/Light Mode, Reduce Motion and the iPhone's safe areas.
enum DanperStyle {
    static let red=Color(red:0.88,green:0.09,blue:0.16)
    static let deepRed=Color(red:0.57,green:0.035,blue:0.12)
    static let canvas=Color(uiColor:.systemGroupedBackground)
    static let surface=Color(uiColor:.secondarySystemGroupedBackground)
    static let animation=Animation.easeInOut(duration:0.22)
    static let gradient=LinearGradient(colors:[red,deepRed],
                                      startPoint:.topLeading,endPoint:.bottomTrailing)
}

struct DanperPrimaryButton:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .font(.system(.subheadline,design:.rounded,weight:.bold))
            .foregroundStyle(.white)
            .padding(.horizontal,20).padding(.vertical,14)
            .frame(maxWidth:.infinity,minHeight:50)
            .background(DanperStyle.gradient,in:RoundedRectangle(cornerRadius:15))
            .shadow(color:DanperStyle.red.opacity(configuration.isPressed ? 0.05 : 0.16),
                    radius:configuration.isPressed ? 2 : 9,y:configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.17),
                       value:configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius:15))
    }
}
struct DanperSecondaryButton:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DanperStyle.red)
            .padding(.horizontal,16).padding(.vertical,13)
            .frame(minHeight:48)
            .background(DanperStyle.red.opacity(configuration.isPressed ? 0.16 : 0.08),
                        in:RoundedRectangle(cornerRadius:14))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.17),
                       value:configuration.isPressed)
    }
}
struct DanperFormChrome:ViewModifier {
    func body(content:Content)->some View {
        content
            .scrollContentBackground(.hidden)
            .background(DanperStyle.canvas)
            .tint(DanperStyle.red)
            .environment(\.locale,Locale(identifier:"es_PE"))
    }
}
extension View {
    func danperFormChrome()->some View {modifier(DanperFormChrome())}
}
struct DanperStepProgress:View {
    let step:Int
    let titles:[String]
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:10) {
                Image(systemName:["person.crop.rectangle","stethoscope",
                                  "cross.vial.fill","checkmark.shield.fill"][
                                  min(max(step,0),3)])
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DanperStyle.red)
                    .frame(width:43,height:43)
                    .background(DanperStyle.red.opacity(0.10),
                                in:RoundedRectangle(cornerRadius:13))
                VStack(alignment:.leading,spacing:3) {
                    Text("PASO \(step+1) DE \(titles.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DanperStyle.red)
                    Text(titles[step])
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength:2)
                Text("\(Int(Double(step+1)/Double(titles.count)*100)) %")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    Capsule().fill(DanperStyle.red.opacity(0.12))
                    Capsule().fill(DanperStyle.gradient)
                        .frame(width: max(CGFloat(5), geo.size.width * CGFloat(step + 1) / CGFloat(titles.count)))
                }
            }
            .frame(height:6)
            .accessibilityLabel("Progreso \(step+1) de \(titles.count)")
        }
        .padding(15)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:18))
    }
}
struct DanperStatusBanner:View {
    let symbol:String
    let title:String
    let detail:String
    var body:some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:symbol).font(.headline)
                .foregroundStyle(DanperStyle.red)
                .frame(width:38,height:38)
                .background(DanperStyle.red.opacity(0.10),
                            in:RoundedRectangle(cornerRadius:12))
            VStack(alignment:.leading,spacing:5) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
        }
        .padding(14).frame(maxWidth:.infinity,alignment:.leading)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:17))
    }
}
