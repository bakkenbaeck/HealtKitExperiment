import SweetUIKit
import SweetSwift
import UIKit

class SampleCell: UITableViewCell {
    private lazy var titleLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)

        return view
    }()

    var title: String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.addSubview(self.titleLabel)

        self.titleLabel.fillSuperview(with: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
