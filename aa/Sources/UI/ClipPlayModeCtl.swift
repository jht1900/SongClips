//
//  ClipPlayModeCtl.swift
//  SongClips
//
//  Choose what happens at the end of each clip.
//

import UIKit

final class ClipPlayModeCtl: UITableViewController {
    private static let modes: [ClipPlayMode] = [.continue, .repeat, .pause, .pauseThenContinue, .pauseThenRepeat]

    /// Called after a mode is chosen. When nil, the controller pops itself.
    var onDone: (() -> Void)?

    init() {
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("ClipPlayModeCtl is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "At end of clip:"
        preferredContentSize = CGSize(width: 300, height: 260)
        tableView.rowHeight = 44

        if !UIDevice.isPad {
            let backButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
            backButton.setBackgroundImage(UIImage(named: "back_arrow.png"), for: .normal)
            backButton.addTarget(self, action: #selector(actionBack), for: .touchUpInside)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        }
    }

    @objc private func actionBack() {
        navigationController?.popViewController(animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Self.modes.count
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 2 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell1")
            ?? UITableViewCell(style: .default, reuseIdentifier: "Cell1")
        let mode = Self.modes[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = mode.title
        cell.contentConfiguration = content
        cell.accessoryType = SongList.shared.playMode == mode ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        SongList.shared.setPlayMode(Self.modes[indexPath.row])
        tableView.reloadData()
        // Leave the checkmark visible briefly before closing.
        Task {
            try? await Task.sleep(for: .seconds(0.25))
            if let onDone {
                onDone()
            } else {
                navigationController?.popViewController(animated: true)
            }
        }
    }
}
