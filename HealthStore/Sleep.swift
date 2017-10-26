import Foundation
import HealthKit

class SleepAnalysis: NSObject {
    let state: HKCategoryValueSleepAnalysis

    let startDate: Date
    let endDate: Date

    init(state: HKCategoryValueSleepAnalysis, startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
        self.state = state

        super.init()
    }
}
