import SwiftUI
import UIKit
import CoreImage

/// Presentation primitives used only by Access and the protected clinical Home.
/// Shared form styles and the user's palette preference are deliberately untouched.
enum GlassClinical {
    static let red = Color(red:0.94,green:0.025,blue:0.14)
    static let deepRed = Color(red:0.48,green:0.015,blue:0.10)
    static let gradient = LinearGradient(colors:[red,deepRed],startPoint:.topLeading,endPoint:.bottomTrailing)
    static let canvas = Color(uiColor:UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red:0.035,green:0.04,blue:0.055,alpha:1)
            : UIColor(red:0.96,green:0.965,blue:0.98,alpha:1)
    })
    // Same alpha extraction as the existing header, retaining the authentic asset.
    static let wordmark:UIImage? = {
        guard let original=UIImage(named:"BrandLogo"),let input=CIImage(image:original),
              let filter=CIFilter(name:"CIColorMatrix") else{return UIImage(named:"BrandLogo")}
        filter.setValue(input,forKey:kCIInputImageKey)
        filter.setValue(CIVector(x:0,y:1,z:0,w:0),forKey:"inputAVector")
        guard let output=filter.outputImage,
              let cg=CIContext().createCGImage(output,from:output.extent) else{return original}
        return UIImage(cgImage:cg)
    }()
}

struct GlassClinicalWordmark:View {
    var body:some View {
        Image(uiImage:GlassClinical.wordmark ?? UIImage())
            .renderingMode(.template).resizable().scaledToFill()
            .frame(width:154,height:52).clipped()
            .accessibilityLabel("Danper")
    }
}

struct GlassClinicalSurface:ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var opaque
    var radius:CGFloat=20
    func body(content:Content)->some View {
        content
            .background {
                RoundedRectangle(cornerRadius:radius,style:.continuous)
                    .fill(scheme == .dark ? Color(red:0.09,green:0.10,blue:0.12) : .white)
                if !opaque {
                    RoundedRectangle(cornerRadius:radius,style:.continuous)
                        .fill(LinearGradient(colors:[.white.opacity(scheme == .dark ? 0.055 : 0.5),.clear],
                                             startPoint:.topLeading,endPoint:.bottomTrailing))
                }
            }
            .overlay(RoundedRectangle(cornerRadius:radius,style:.continuous)
                .strokeBorder(scheme == .dark ? .white.opacity(0.10) : .black.opacity(0.07)))
            .shadow(color:.black.opacity(scheme == .dark ? 0.12 : 0.035),radius:10,y:4)
    }
}

/// Curved native overlay; never bakes UI or corporate lettering into the photo.
struct GlassClinicalWave:Shape {
    func path(in rect:CGRect)->Path {
        var path=Path()
        path.move(to:CGPoint(x:0,y:rect.height*0.05))
        path.addCurve(to:CGPoint(x:rect.width,y:rect.height*0.70),
                      control1:CGPoint(x:rect.width*0.30,y:rect.height*0.30),
                      control2:CGPoint(x:rect.width*0.67,y:rect.height*0.25))
        path.addLine(to:CGPoint(x:rect.width,y:rect.height))
        path.addLine(to:CGPoint(x:0,y:rect.height))
        path.closeSubpath()
        return path
    }
}
