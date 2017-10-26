import Foundation
import HealthKit

private var AssociatedObjectHandle: UInt8 = 0

extension HKWorkout {
    var heartRateSamples: [HKQuantitySample] {
        get {
            if let samples = objc_getAssociatedObject(self, &AssociatedObjectHandle) as? [HKQuantitySample] {
                return samples
            }

            self.heartRateSamples = []

            return []
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObjectHandle, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
