//
//  Cells.swift
//  SongClips
//
//  Table cells and the navigation title view. Each loads its layout from a XIB
//  whose File's Owner is the view itself.
//

import UIKit

final class SongCell: UITableViewCell {
    static let reuseIdentifier = "SongCell"

    @IBOutlet private var fView: UIView!
    @IBOutlet var fTitle: UILabel!
    @IBOutlet var fDetail: UILabel!
    @IBOutlet var fImage: UIImageView!

    init() {
        super.init(style: .default, reuseIdentifier: Self.reuseIdentifier)
        Bundle.main.loadNibNamed(UIDevice.isPad ? "SongCell-iPad" : "SongCell", owner: self)
        contentView.addSubview(fView)
    }

    required init?(coder: NSCoder) {
        fatalError("SongCell loads from its own XIB")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fView.frame = contentView.bounds
    }
}

final class ClipCell: UITableViewCell {
    static let reuseIdentifier = "ClipCell"

    @IBOutlet var fView: UIView!
    @IBOutlet var fNotes: UILabel!
    @IBOutlet var fStartTime: UILabel!
    @IBOutlet var fDuration: UILabel!
    @IBOutlet var fCurPos: UILabel!
    @IBOutlet var fImage: UIImageView!

    init() {
        super.init(style: .default, reuseIdentifier: Self.reuseIdentifier)
        Bundle.main.loadNibNamed(UIDevice.isPad ? "ClipCell-iPad" : "ClipCell", owner: self)
        contentView.addSubview(fView)
    }

    required init?(coder: NSCoder) {
        fatalError("ClipCell loads from its own XIB")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fView.frame = contentView.bounds
    }
}

/// Two-line title (song label over details) shown in the navigation bar.
final class TitleView: UIView {
    @IBOutlet private var fView: UIView!
    @IBOutlet var fTop: UILabel!
    @IBOutlet var fBottom: UILabel!

    init(width: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: 40))
        Bundle.main.loadNibNamed(UIDevice.isPad ? "TitleView-iPad" : "TitleView", owner: self)
        addSubview(fView)
    }

    required init?(coder: NSCoder) {
        fatalError("TitleView loads from its own XIB")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fView.frame = bounds
    }
}
