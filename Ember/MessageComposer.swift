//
//  MessageComposer.swift
//  Ember
//
//  Created by Marcus Win on 4/4/26.
//

import Foundation
// MessageComposer.swift
// Ember — SMS/iMessage Composer
//
// ============================================================
// WHAT THIS FILE IS
// ============================================================
// A SwiftUI wrapper around MFMessageComposeViewController —
// Apple's native message composer.
//
// iOS doesn't let apps send messages silently.
// The user always sees the draft and taps Send themselves.
// This is intentional — Ember suggests, the user decides.
//
// ============================================================
// LESSON: UIViewControllerRepresentable
// SwiftUI is built on top of UIKit — Apple's older framework.
// Some iOS features only exist in UIKit, not SwiftUI.
// UIViewControllerRepresentable is the bridge:
//   "Take this UIKit view controller and display it in SwiftUI."
//
// You implement two methods:
//   makeUIViewController — create the controller once
//   updateUIViewController — update it when SwiftUI state changes
//
// The Coordinator handles callbacks from UIKit back to SwiftUI.
// ============================================================

import SwiftUI
import MessageUI

struct MessageComposerView: UIViewControllerRepresentable {

    // The phone number to send to
    let recipient: String

    // The pre-drafted message body
    let body: String

    // Called when the user sends, cancels, or the sheet closes
    let onFinish: (MessageComposeResult) -> Void

    // ============================================================
    // LESSON: Coordinator
    // UIKit uses delegation for callbacks — one object tells
    // another "here's what happened."
    // The Coordinator is the delegate. It receives UIKit events
    // and translates them back into SwiftUI closures.
    // ============================================================
    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = [recipient]
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // Nothing to update — the composer is configured once
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void

        init(onFinish: @escaping (MessageComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        // ============================================================
        // LESSON: Delegate method
        // This fires when the user taps Send, Cancel, or Delete Draft.
        // result tells us what happened:
        //   .sent — message was sent
        //   .cancelled — user backed out
        //   .failed — something went wrong
        // We dismiss the sheet and call our closure.
        // ============================================================
        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true)
            onFinish(result)
        }
    }
}

// ============================================================
// LESSON: Checking capability
// Not all devices can send messages — iPads without cellular,
// simulators, devices in airplane mode.
// Always check MFMessageComposeViewController.canSendText()
// before showing the send button.
// ============================================================
extension MFMessageComposeViewController {
    static var isAvailable: Bool {
        canSendText()
    }
}
