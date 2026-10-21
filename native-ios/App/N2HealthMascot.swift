import SwiftUI

/// Small, native vector illustration of a male nurse/doctor.
/// No external photograph, no additional image files or patient data.
struct N2HealthMascot:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating=false

    var body:some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width:110,height:110)
            // Coat
            RoundedRectangle(cornerRadius:22)
                .fill(.white)
                .frame(width:68,height:62)
                .offset(y:30)
                .shadow(color:.black.opacity(0.10),radius:6,y:4)
            RoundedRectangle(cornerRadius:4)
                .fill(Color(red:0.04,green:0.55,blue:0.83))
                .frame(width:8,height:52).offset(y:29)
            // Neck and head
            RoundedRectangle(cornerRadius:9)
                .fill(Color(red:0.91,green:0.66,blue:0.46))
                .frame(width:16,height:20).offset(y:3)
            Ellipse()
                .fill(Color(red:0.96,green:0.74,blue:0.54))
                .frame(width:44,height:47).offset(y:-19)
            // Hair
            Capsule()
                .fill(Color(red:0.16,green:0.23,blue:0.35))
                .frame(width:43,height:16).offset(y:-39)
            HStack(spacing:16) {
                Circle().frame(width:4,height:4)
                Circle().frame(width:4,height:4)
            }
            .foregroundStyle(Color(red:0.18,green:0.24,blue:0.31))
            .offset(y:-17)
            Capsule().fill(Color(red:0.60,green:0.34,blue:0.26))
                .frame(width:12,height:2).offset(y:-6)
            // Professional cap and medical cross
            RoundedRectangle(cornerRadius:6)
                .fill(Color(red:0.06,green:0.43,blue:0.80))
                .frame(width:39,height:15).offset(y:-46)
            Image(systemName:"cross.fill")
                .font(.system(size:9,weight:.bold))
                .foregroundStyle(.white)
                .offset(y:-47)
            Image(systemName:"stethoscope")
                .font(.system(size:30,weight:.medium))
                .foregroundStyle(Color(red:0.02,green:0.56,blue:0.81))
                .offset(x:15,y:34)
            Image(systemName:"heart.fill")
                .font(.system(size:12,weight:.bold))
                .foregroundStyle(Color(red:0.89,green:0.09,blue:0.21))
                .offset(x:-19,y:25)
        }
        .offset(y:floating && !reduceMotion ? -3 : 0)
        .onAppear {
            guard !reduceMotion else{return}
            withAnimation(.easeInOut(duration:1.9).repeatForever(autoreverses:true)) {
                floating=true
            }
        }
        .accessibilityHidden(true)
    }
}
