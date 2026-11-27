//
//  TouchView.swift
//  SongClips
//
//  The clip image area of the player. A tap shows or hides the controls.
//

import UIKit

final class TouchView: UIView {
    @IBOutlet weak var mainViewCtl: ClipPlayCtl?

    // This view handles its touches itself, so it overrides every touch method without calling super.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        mainViewCtl?.clickImageAction(nil)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}
