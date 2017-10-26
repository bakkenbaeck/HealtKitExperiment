import Foundation
import HealthKit

class DayData: NSObject {
    let date: Date

    var sleep: SleepAnalysis?

    var steps: HKStatistics?

    var energy: Energy?

    var distance: HKStatistics?

    var asJSON: [String: Any] {
        return [:]
    }

    init(date: Date, sleep: SleepAnalysis? = nil, steps: HKStatistics? = nil, energy: Energy? = nil, distance: HKStatistics? = nil) {
        self.date = date
        self.sleep = sleep
        self.steps = steps
        self.energy = energy
        self.distance = distance

        super.init()
    }
}
