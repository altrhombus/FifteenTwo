#if os(iOS)
import SwiftUI
import UIKit
import MultipeerConnectivity

/// Wraps the system's own peer picker — see docs/plan.md: finding the right nearby device
/// is the part of Multipeer connection actually worth a UI, and Apple already built one.
struct PeerBrowserView: UIViewControllerRepresentable {
    let browser: MCNearbyServiceBrowser
    let session: MCSession
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MCBrowserViewController {
        let controller = MCBrowserViewController(browser: browser, session: session)
        controller.delegate = context.coordinator
        controller.minimumNumberOfPeers = 2
        controller.maximumNumberOfPeers = 2
        return controller
    }

    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MCBrowserViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
            browserViewController.dismiss(animated: true)
            onFinish()
        }

        func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
            browserViewController.dismiss(animated: true)
            onFinish()
        }
    }
}
#elseif os(macOS)
import SwiftUI
import AppKit
import MultipeerConnectivity

struct PeerBrowserView: NSViewControllerRepresentable {
    let browser: MCNearbyServiceBrowser
    let session: MCSession
    let onFinish: () -> Void

    func makeNSViewController(context: Context) -> MCBrowserViewController {
        let controller = MCBrowserViewController(browser: browser, session: session)
        controller.delegate = context.coordinator
        controller.minimumNumberOfPeers = 2
        controller.maximumNumberOfPeers = 2
        return controller
    }

    func updateNSViewController(_ nsViewController: MCBrowserViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MCBrowserViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
            browserViewController.dismiss(nil)
            onFinish()
        }

        func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
            browserViewController.dismiss(nil)
            onFinish()
        }
    }
}
#endif
