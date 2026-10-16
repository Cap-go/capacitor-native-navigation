import UIKit

/// Pull distance (points) that arms a refresh, like `UIRefreshControl`.
let nativeNavigationPullToRefreshThreshold: CGFloat = 90

/// Spinner state for a pull distance: how far it slides down, how visible it is, and whether release refreshes.
struct NativeNavigationPullState: Equatable {
    let offset: CGFloat
    let progress: CGFloat
    let armed: Bool
}

func nativeNavigationPullState(distance: CGFloat, threshold: CGFloat = nativeNavigationPullToRefreshThreshold) -> NativeNavigationPullState {
    let pull = max(0, distance)
    let progress = min(1, pull / threshold)
    // Rubber band: the spinner follows the finger at half speed and slows down past the threshold.
    let offset = pull <= threshold ? pull * 0.5 : threshold * 0.5 + (pull - threshold) * 0.15
    return NativeNavigationPullState(offset: offset, progress: progress, armed: pull >= threshold)
}

/// Opt-in pull-to-refresh for the WebView. Web apps usually scroll an inner element (`#app`, Ionic content)
/// rather than the WKWebView scroll view, so `UIRefreshControl` never sees the overscroll. A simultaneous pan
/// gesture plus the scroll offset reported by the page decides when the user pulls from the top, and the
/// system activity indicator is shown below the native navbar.
final class NativeNavigationPullToRefresh: NSObject, UIGestureRecognizerDelegate {
    private weak var webView: UIView?
    private weak var scrollView: UIScrollView?
    private var panGesture: UIPanGestureRecognizer?
    private var spinner: UIActivityIndicatorView?
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    private let onRefresh: () -> Void
    private var tracking = false
    private var armed = false
    private var refreshing = false
    private var webScrollOffsetY: CGFloat = 0
    private var topInset: CGFloat = 0

    init(onRefresh: @escaping () -> Void) {
        self.onRefresh = onRefresh
    }

    var isEnabled: Bool {
        panGesture != nil
    }

    var isRefreshing: Bool {
        refreshing
    }

    func enable(on webView: UIView, scrollView: UIScrollView?, tintColor: UIColor?) {
        if self.webView !== webView {
            disable()
        }
        if panGesture == nil {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.cancelsTouchesInView = false
            pan.delaysTouchesBegan = false
            pan.delaysTouchesEnded = false
            pan.delegate = self
            webView.addGestureRecognizer(pan)
            panGesture = pan

            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.hidesWhenStopped = false
            indicator.alpha = 0
            indicator.isUserInteractionEnabled = false
            webView.addSubview(indicator)
            spinner = indicator

            self.webView = webView
            self.scrollView = scrollView
            webScrollOffsetY = 0
        }
        spinner?.color = tintColor
        layoutSpinner(offset: refreshing ? nativeNavigationPullState(distance: nativeNavigationPullToRefreshThreshold).offset : 0)
    }

    func disable() {
        if let pan = panGesture {
            pan.view?.removeGestureRecognizer(pan)
        }
        spinner?.removeFromSuperview()
        panGesture = nil
        spinner = nil
        webView = nil
        scrollView = nil
        tracking = false
        armed = false
        refreshing = false
    }

    func reportWebScroll(offsetY: CGFloat) {
        webScrollOffsetY = offsetY
    }

    func resetWebScroll() {
        webScrollOffsetY = 0
    }

    /// Keeps the spinner below the native navbar instead of behind it.
    func updateTopInset(_ inset: CGFloat) {
        topInset = inset
        if spinner?.alpha ?? 0 > 0 {
            layoutSpinner(offset: currentSpinnerOffset)
        }
    }

    func endRefreshing() {
        guard refreshing else {
            return
        }
        refreshing = false
        hideSpinner()
    }

    private var currentSpinnerOffset: CGFloat = 0

    private var isAtTop: Bool {
        guard webScrollOffsetY <= 0.5 else {
            return false
        }
        guard let scrollView = scrollView else {
            return true
        }
        return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let view = pan.view else {
            return
        }
        switch pan.state {
        case .began:
            beginTracking(velocity: pan.velocity(in: view))
        case .changed:
            updatePull(distance: pan.translation(in: view).y)
        case .ended, .cancelled, .failed:
            guard tracking else {
                return
            }
            tracking = false
            if pan.state == .ended && armed {
                startRefreshing()
            } else {
                hideSpinner()
            }
        default:
            break
        }
    }

    private func beginTracking(velocity: CGPoint) {
        tracking = !refreshing && isAtTop && velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
        armed = false
        if tracking {
            feedback.prepare()
            spinner?.stopAnimating()
        }
    }

    private func updatePull(distance: CGFloat) {
        guard tracking else {
            return
        }
        let state = nativeNavigationPullState(distance: distance)
        if state.armed && !armed {
            feedback.impactOccurred()
        }
        armed = state.armed
        spinner?.alpha = state.progress
        spinner?.transform = CGAffineTransform(rotationAngle: state.progress * .pi)
        layoutSpinner(offset: state.offset)
    }

    private func startRefreshing() {
        refreshing = true
        armed = false
        spinner?.startAnimating()
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.spinner?.alpha = 1
            self.spinner?.transform = .identity
            self.layoutSpinner(offset: nativeNavigationPullState(distance: nativeNavigationPullToRefreshThreshold).offset)
        }
        onRefresh()
    }

    private func hideSpinner() {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.spinner?.alpha = 0
            self.spinner?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.layoutSpinner(offset: 0)
        } completion: { _ in
            if !self.refreshing {
                self.spinner?.stopAnimating()
                self.spinner?.transform = .identity
            }
        }
    }

    private func layoutSpinner(offset: CGFloat) {
        guard let spinner = spinner, let webView = webView else {
            return
        }
        currentSpinnerOffset = offset
        webView.bringSubviewToFront(spinner)
        spinner.center = CGPoint(x: webView.bounds.midX, y: topInset + 12 + offset)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
