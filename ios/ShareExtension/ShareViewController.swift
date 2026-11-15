import UIKit
import SwiftUI

/// Principal class de la Share Extension: hospeda la vista SwiftUI de composición.
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareComposeView(extensionContext: extensionContext))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}
