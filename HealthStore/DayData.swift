import Foundation
import HealthKit

class DayData: NSObject {
    let date: Date

    var sleep: SleepAnalysis?

    var steps: HKStatistics?

    var energy: Energy?

    var distance: HKStatistics?

    var asJSON: [String: Any] {
        return [
            "date": self.ISODateFormatter.string(from: self.date),
            "steps": self.steps?.sumQuantity()?.doubleValue(for: .count()) ?? 0.0,
            "distance": self.distance?.sumQuantity()?.doubleValue(for: HKUnit.meter()) ?? 0.0,
            "energy": [
                "basal": self.energy?.basalDataPoint.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0,
                "active": self.energy?.activeDataPoint?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0.0,
            ]
        ]
    }

    var asString: String {
        let dateString = self.dateFormatter.string(from: self.date)

        return "\(dateString): \(self.stepsString) | \(self.distanceString) | \(self.energyString)"
    }

    fileprivate var stepsString: String {
        return self.steps != nil && self.steps!.sumQuantity() != nil ? String(describing: self.steps!.sumQuantity()!) : ""
    }

    fileprivate var distanceString: String {
        return self.distance != nil && self.distance!.sumQuantity() != nil ? String(describing: self.distance!.sumQuantity()!) : ""
    }

    fileprivate var sleepString: String {
        var sleepString = ""

        if let sleep = self.sleep {
            let start = self.dateFormatter.string(from: sleep.startDate)
            let end = self.dateFormatter.string(from: sleep.endDate)
            let state = sleep.state == .asleep ? "Asleep" : "In bed"

            sleepString = "\(state) from \(start) to \(end)"
        }

        return sleepString
    }

    fileprivate var energyString: String {
        var energyString = ""

        if let energy = self.energy {
            if let basalSum = energy.basalDataPoint.sumQuantity() {
                energyString.append("Basal: \(basalSum)")
            }
            if let active = energy.activeDataPoint, let activeSum = active.sumQuantity() {
                energyString.append(" Active: \(activeSum)")
            }
        }

        return energyString
    }

    fileprivate lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        return dateFormatter
    }()

    fileprivate lazy var ISODateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZ"

        return dateFormatter
    }()


    init(date: Date, sleep: SleepAnalysis? = nil, steps: HKStatistics? = nil, energy: Energy? = nil, distance: HKStatistics? = nil) {
        self.date = date
        self.sleep = sleep
        self.steps = steps
        self.energy = energy
        self.distance = distance

        super.init()
    }
}
