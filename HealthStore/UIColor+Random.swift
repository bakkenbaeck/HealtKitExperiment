import UIKit

extension UIColor {
    static var random: UIColor {
        let colours = [UIColor.blue, .red, .green, .cyan, .yellow, .brown, .black, .orange, .magenta, .purple]

        return colours[Int(arc4random()) % colours.count]
    }
}
