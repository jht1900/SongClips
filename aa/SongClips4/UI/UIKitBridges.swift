//
//  UIKitBridges.swift
//  SongClips4
//
//  SwiftUI wrappers for the UIKit views and pickers SwiftUI has no equivalent for.
//

import MediaPlayer
import MessageUI
import SwiftUI
import UIKit

/// Shows AVPlayer video in the song list's shared `PlaybackView`.
struct VideoLayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> PlaybackView {
        let view = SongList.shared.playbackView
        view.backgroundColor = .white
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: PlaybackView, context: Context) {}
}

/// Pick items from the Music library.
struct MediaPicker: UIViewControllerRepresentable {
    let prompt: String
    let onPick: (MPMediaItemCollection) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .any)
        picker.delegate = context.coordinator
        picker.allowsPickingMultipleItems = false
        picker.prompt = prompt
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        private let parent: MediaPicker

        init(_ parent: MediaPicker) {
            self.parent = parent
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            parent.dismiss()
            parent.onPick(mediaItemCollection)
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            parent.dismiss()
        }
    }
}

/// Take a photo with the camera.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Compose an email.
struct MailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    @Environment(\.dismiss) private var dismiss

    static var canSendMail: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setSubject(subject)
        mail.setMessageBody(body, isHTML: false)
        return mail
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let parent: MailComposer

        init(_ parent: MailComposer) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?
        ) {
            if result == .failed {
                appLog.error("Email failed: \(error?.localizedDescription ?? "", privacy: .public)")
            }
            parent.dismiss()
        }
    }
}
