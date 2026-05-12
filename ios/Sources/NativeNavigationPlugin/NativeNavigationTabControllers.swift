import UIKit

final class NativeNavigationTabController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
        tabBar.isTranslucent = true
    }
}

final class NativeNavigationTabContentController: UIViewController {
    private weak var hostedWebView: UIView?

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        self.view = view
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard hostedWebView?.superview === view else {
            hostedWebView = nil
            return
        }
        hostedWebView?.frame = view.bounds
    }

    func clearHostedWebView(ifMatching webView: UIView? = nil) {
        guard webView == nil || hostedWebView === webView else {
            return
        }
        hostedWebView = nil
    }

    func host(webView: UIView) {
        if hostedWebView !== webView {
            hostedWebView = webView
        }

        if view === webView || view.isDescendant(of: webView) {
            return
        }

        if webView.superview !== view {
            webView.removeFromSuperview()
            view.addSubview(webView)
        }
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.frame = view.bounds
    }
}

