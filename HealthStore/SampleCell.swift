import SweetUIKit
import UIKit

class SampleCell: UITableViewCell {
    private lazy var titleLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)

        view.numberOfLines = 0

        return view
    }()
    private lazy var dateLabel: UILabel = {
        let view = UILabel(withAutoLayout: true)

        view.font = .systemFont(ofSize: 9)
        view.textColor = .lightGray
        view.textAlignment = .left

        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)

        return view
    }()

    var title: String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }

    var dateString: String? {
        didSet {
            self.dateLabel.text = self.dateString
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.addSubview(self.dateLabel)
        self.addSubview(self.titleLabel)

        NSLayoutConstraint.activate([
            self.dateLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 8),
            self.dateLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -8),

            self.titleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 26),
            self.titleLabel.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 12),
            self.titleLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -12),
            self.titleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
