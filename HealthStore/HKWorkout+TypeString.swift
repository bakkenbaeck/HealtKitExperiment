import HealthKit

extension HKWorkout {
    var activityTypeString: String {
        switch self.workoutActivityType {
        case .americanFootball:
            return NSLocalizedString("American Football", comment: "")
        case .archery:
            return NSLocalizedString("Archery", comment: "")
        case .australianFootball:
            return NSLocalizedString("Australian Football", comment: "")
        case .badminton:
            return NSLocalizedString("Badminton", comment: "")
        case .baseball:
            return NSLocalizedString("Baseball", comment: "")
        case .basketball:
            return NSLocalizedString("Basketball", comment: "")
        case .bowling:
            return NSLocalizedString("Bowling", comment: "")
        case .boxing:
            return NSLocalizedString("Boxing", comment: "")
        case .climbing:
            return NSLocalizedString("Climbing", comment: "")
        case .cricket:
            return NSLocalizedString("Cricket", comment: "")
        case .crossTraining:
            return NSLocalizedString("Cross Training", comment: "")
        case .curling:
            return NSLocalizedString("Curling", comment: "")
        case .cycling:
            return NSLocalizedString("Cycling", comment: "")
        case .dance:
            return NSLocalizedString("Dance", comment: "")
        case .barre:
            return NSLocalizedString("Barre", comment: "")
        case .pilates:
            return NSLocalizedString("Pilates", comment: "")
        case .elliptical:
             return NSLocalizedString("Elliptical", comment: "")
        case .equestrianSports:
            return NSLocalizedString("Equestrian Sports", comment: "")
        case .fencing:
            return NSLocalizedString("Fencing", comment: "")
        case .fishing:
            return NSLocalizedString("Fishing", comment: "")
        case .functionalStrengthTraining:
            return NSLocalizedString("Functional Strenght Training", comment: "")
        case .golf:
            return NSLocalizedString("Golf", comment: "")
        case .gymnastics:
            return NSLocalizedString("Gymnastics", comment: "")
        case .handball:
            return NSLocalizedString("Handball", comment: "")
        case .hiking:
            return NSLocalizedString("Hiking", comment: "")
        case .hockey:
            return NSLocalizedString("Hockey", comment: "")
        case .handCycling:
            return NSLocalizedString("Hand-cycling", comment: "")
        case .hunting:
            return NSLocalizedString("Hunting", comment: "")
        case .lacrosse:
            return NSLocalizedString("Lacrosse", comment: "")
        case .martialArts:
            return NSLocalizedString("Martial Arts", comment: "")
        case .mindAndBody:
            return NSLocalizedString("Mind and Body", comment: "")
        case .mixedCardio:
            return NSLocalizedString("Mixed cardion", comment: "")
        case .paddleSports:
            return NSLocalizedString("Paddling", comment: "")
        case .play:
            return NSLocalizedString("Playing", comment: "")
        case .preparationAndRecovery:
            return NSLocalizedString("Preperation and Recovery", comment: "")
        case .racquetball:
            return NSLocalizedString("Racquetball", comment: "")
        case .rowing:
            return NSLocalizedString("Rowing", comment: "")
        case .rugby:
            return NSLocalizedString("Rugby", comment: "")
        case .running:
            return NSLocalizedString("Running", comment: "")
        case .sailing:
            return NSLocalizedString("Sailing", comment: "")
        case .skatingSports:
            return NSLocalizedString("Skating", comment: "")
        case .snowSports:
            return NSLocalizedString("Snow sports", comment: "")
        case .snowboarding:
            return NSLocalizedString("Snowboarding", comment: "")
        case .soccer:
            return NSLocalizedString("Football", comment: "")
        case .softball:
            return NSLocalizedString("Softball", comment: "")
        case .squash:
            return NSLocalizedString("Squash", comment: "")
        case .stairs, .stairClimbing:
            return NSLocalizedString("Stair climbing", comment: "")
        case .swimming:
            return NSLocalizedString("Swimming", comment: "")
        case .tableTennis:
            return NSLocalizedString("Table Tennis", comment: "")
        case .tennis:
            return NSLocalizedString("Tennis", comment: "")
        case .trackAndField:
            return NSLocalizedString("Track and Field", comment: "")
        case .traditionalStrengthTraining:
            return NSLocalizedString("Traditional Strenght Training", comment: "")
        case .volleyball:
            return NSLocalizedString("Volleyball", comment: "")
        case .walking:
            return NSLocalizedString("Walking", comment: "")
        case .waterPolo:
            return NSLocalizedString("Water Polo", comment: "")
        case .waterFitness:
            return NSLocalizedString("Water fitnness training", comment: "")
        case .waterSports:
            return NSLocalizedString("Water sports", comment: "")
        case .wrestling:
            return NSLocalizedString("Wresting", comment: "")
        case .yoga:
            return NSLocalizedString("Yoga", comment: "")
        case .other:
            return NSLocalizedString("Other", comment: "")
        case .coreTraining:
            return NSLocalizedString("Core training", comment: "")
        case .crossCountrySkiing:
            return NSLocalizedString("Cross-country Skiing", comment: "")
        case .downhillSkiing:
            return NSLocalizedString("Downhill Skiing", comment: "")
        case .flexibility:
            return NSLocalizedString("Flexbility training", comment: "")
        case .highIntensityIntervalTraining:
            return NSLocalizedString("HIIT", comment: "")
        case .jumpRope:
            return NSLocalizedString("Jumping Rope", comment: "")
        case .kickboxing:
            return NSLocalizedString("Kickboxing", comment: "")
        case .stepTraining:
            return NSLocalizedString("Step traning", comment: "")
        case .wheelchairRunPace:
            return NSLocalizedString("Wheelchair run", comment: "")
        case .wheelchairWalkPace:
            return NSLocalizedString("Wheelchair walk", comment: "")
        case .danceInspiredTraining:
            return NSLocalizedString("Dance-based excercise", comment: "")
        case .mixedMetabolicCardioTraining:
            return NSLocalizedString("Mixed metabolic-cardio training", comment: "")
        case .surfingSports:
            return NSLocalizedString("Surfing", comment: "")
        case .taiChi:
            return NSLocalizedString("Tai Chi", comment: "")
        }
    }
}
