import Foundation

/// Presentation only. No clinical identity, storage or network access.
enum DanperGreeting {
    static func text(name:String,at date:Date,calendar:Calendar = .current)->String {
        let hour=calendar.component(.hour,from:date)
        let phrase:String,emoji:String
        switch hour {
        case 5..<12: phrase="Buenos días";emoji="☀️"
        case 12..<19: phrase="Buenas tardes";emoji="🌤️"
        default: phrase="Buenas noches";emoji="🌙"
        }
        let clean=name.trimmingCharacters(in:.whitespacesAndNewlines)
        return phrase+(clean.isEmpty ? "":" "+clean)+" "+emoji
    }
    static func nextBoundary(after date:Date,calendar:Calendar = .current)->Date {
        [5,12,19].compactMap { hour in
            calendar.nextDate(after:date,matching:DateComponents(hour:hour,minute:0,second:0),
                              matchingPolicy:.nextTime,repeatedTimePolicy:.first,direction:.forward)
        }.min() ?? date.addingTimeInterval(3600)
    }
}

struct DanperGreetingClock {
    var now:()->Date
    static var device:Self {
        #if DEBUG && targetEnvironment(simulator)
        // Ephemeral injected clock only in the existing isolated UI DEMO probe.
        // Release and all operational launches always use real local time.
        if ProcessInfo.processInfo.arguments.contains("--danper-redesign-demo"),
           let value=ProcessInfo.processInfo.environment["DANPER_GREETING_TEST_LOCAL"] {
            let format=DateFormatter()
            format.locale=Locale(identifier:"en_US_POSIX")
            format.calendar=Calendar.current;format.timeZone = .current
            format.dateFormat="yyyy-MM-dd'T'HH:mm:ss";format.isLenient=false
            if let anchor=format.date(from:value) {
                let uptime=ProcessInfo.processInfo.systemUptime
                return Self(now:{anchor.addingTimeInterval(ProcessInfo.processInfo.systemUptime-uptime)})
            }
        }
        #endif
        return Self(now:{Date()})
    }
}
