import Foundation
import UIKit

struct NativeNavigationVisibleTabDescriptor: Equatable {
    let sourceIndex: Int
    let id: String
    let role: String?
    let isDetachedTrailing: Bool
}

struct SystemTabBarBuildResult {
    let items: [UITabBarItem]
    let selectedIndex: Int?
    let visibleSourceIndexes: [Int]
    let hasDetachedSearchTab: Bool
}

func nativeNavigationVisibleTabDescriptors(
    tabs: [[String: Any]],
    selectedId: String?
) -> [NativeNavigationVisibleTabDescriptor] {
    var descriptors: [NativeNavigationVisibleTabDescriptor] = []
    var trailing: NativeNavigationVisibleTabDescriptor?

    for (sourceIndex, tab) in tabs.enumerated() {
        let id = tab["id"] as? String ?? "tab-\(sourceIndex)"
        let isHidden = tab["hidden"] as? Bool ?? false
        if isHidden && id != selectedId {
            continue
        }
        let role = (tab["role"] as? String)?.lowercased()
        let isDetachedTrailing = role == "search" || role == "prominent"
        let descriptor = NativeNavigationVisibleTabDescriptor(
            sourceIndex: sourceIndex,
            id: id,
            role: role,
            isDetachedTrailing: isDetachedTrailing
        )
        if isDetachedTrailing {
            trailing = descriptor
        } else {
            descriptors.append(descriptor)
        }
    }

    if let trailing {
        descriptors.append(trailing)
    }
    return descriptors
}

func nativeNavigationPrefersSystemUITabAPI(hasDetachedSearchTab: Bool) -> Bool {
    guard hasDetachedSearchTab else {
        return false
    }
    if #available(iOS 26.0, *) {
        return true
    }
    return false
}

func nativeNavigationSystemTabIdentifier(forTabId id: String) -> String {
    "app.capgo.nativenavigation.\(id)"
}