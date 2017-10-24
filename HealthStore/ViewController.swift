import UIKit
import HealthKit
import HealthKitUI
import MapKit
import SweetUIKit
import SweetSwift

extension UIColor {
    static var random: UIColor {
        let colours = [UIColor.blue, .red, .green, .cyan, .yellow, .brown, .black, .orange, .magenta, .purple]

        return colours[Int(arc4random()) % colours.count]
    }
}

class ViewController: UIViewController {
    var cyclingActivitySamples: Set<HKWorkout> = [] {
        didSet {
            DispatchQueue.main.sync {
                self.mapView.removeOverlays(self.mapView.overlays)
            }

            for workout in self.cyclingActivitySamples {
                let query = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(), predicate: HKQuery.predicateForObjects(from: workout), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, routes, error in

                    guard let routes = routes as? [HKWorkoutRoute], !routes.isEmpty else { return }

                    for route in routes {
                        let query = HKWorkoutRouteQuery(route: route) { (routeQuery, locations, done, error) in
                            guard let locations = locations else { return }

                            DispatchQueue.main.async {
                                let coordinates = locations.map({ location -> CLLocationCoordinate2D in return location.coordinate })
                                let line = MKGeodesicPolyline(coordinates: UnsafePointer<CLLocationCoordinate2D>(coordinates), count: coordinates.count)

                                self.mapView.add(line)

//                                if let coordinate = locations.last?.coordinate {
//                                    let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
//                                    let region = MKCoordinateRegion(center: coordinate, span: span)
//
//                                    self.mapView.setRegion(region, animated: true)
//                                }
                            }
                        }

                        self.healthStore.execute(query)
                    }
                }

                self.healthStore.execute(query)
            }
        }
    }

    lazy var mapView: MKMapView = {
        let view = MKMapView(withAutoLayout: true)
        view.delegate = self

        return view
    }()

    let healthStore = HKHealthStore()

    let cyclingPredicate = HKQuery.predicateForWorkouts(with: .cycling)

    lazy var observerQuery: HKObserverQuery = {
        let query = HKObserverQuery(sampleType: HKWorkoutType.workoutType(), predicate: self.cyclingPredicate) { query, completion, error in
            guard error == nil else { return }

            self.updateActivities()

            completion()
        }

        return query
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.mapView)
        self.mapView.fillSuperview()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.requestHealthAccessAuthorisationIfNeeded()
        self.updateActivities()

        self.healthStore.execute(self.observerQuery)
    }

    private func requestHealthAccessAuthorisationIfNeeded() {
        let readSet = Set([HKWorkoutType.workoutType(),
                           HKSeriesType.workoutRoute(),
                           HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
                           HKObjectType.quantityType(forIdentifier: .distanceCycling)!
                           ])
        self.healthStore.requestAuthorization(toShare: nil, read: readSet) { success, error in
            if let error = error {
                print(error)

                return;
            }

            print(success)
        }
    }

    private func updateActivities() {
        let sampleQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: self.cyclingPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { query, samples, error in
            guard error == nil else { return }

            if let samples = samples {
                self.cyclingActivitySamples.formUnion(samples as! [HKWorkout])
            }
        }

        self.healthStore.execute(sampleQuery)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKGeodesicPolyline else {
            return MKOverlayRenderer()
        }

        let renderer = MKPolylineRenderer(overlay: polyline)
        renderer.lineWidth = 3.0
        renderer.strokeColor = .random

        return renderer
    }
}

