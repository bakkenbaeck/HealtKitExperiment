import Foundation
import HealthKit

class Energy: NSObject {
    let activeDataPoint: HKStatistics?
    let basalDataPoint: HKStatistics

    var totalEnergy: HKQuantity {
        let kcal: HKUnit = .kilocalorie()

        let basal = self.basalDataPoint.sumQuantity()?.doubleValue(for: kcal) ?? 0.0
        let active = self.activeDataPoint?.sumQuantity()?.doubleValue(for: kcal) ?? 0.0

        let sum = basal + active

        return HKQuantity(unit: kcal, doubleValue: sum)
    }

    init(activeDataPoint: HKStatistics? = nil, basalDataPoint: HKStatistics) {
        self.activeDataPoint = activeDataPoint
        self.basalDataPoint = basalDataPoint
    }
}
