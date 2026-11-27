import Foundation
import UIKit

struct NativeNavigationVisibleTabEntry: Equatable {
    let sourceIndex: Int
    let id: String
    let role: String?
}

/// Visible tabs after applying the same hidden-tab rules as `makeTabBarItems`.
func nativeNavigationVisibleTabEntries(
    tabs: [[String: Any]],
    selectedId: String?
) -> [NativeNavigationVisibleTabEntry] {
    var entries: [NativeNavigationVisibleTabEntry] = []
    for (sourceIndex, tab) in tabs.enumerated() {
        let id = tab["id"] as? String ?? "tab-\(sourceIndex)"
        let isHidden = tab["hidden"] as? Bool ?? false
        if isHidden && id != selectedId {
            continue
        }
        let role = (tab["role"] as? String)?.lowercased()
        entries.append(NativeNavigationVisibleTabEntry(sourceIndex: sourceIndex, id: id, role: role))
    }
    return entries
}

/// iOS 26+ Liquid Glass detached search needs `UITab` / `UISearchTab`, not `setViewControllers`.
func nativeNavigationUsesUITabSearchAPI(visibleTabs: [NativeNavigationVisibleTabEntry]) -> Bool {
    guard let last = visibleTabs.last else {
        return false
    }
    return last.role == "search" || last.role == "prominent"
}

func nativeNavigationIndexForTabIdentifier(_ identifiers: [String], identifier: String?) -> Int? {
    guard let identifier else {
        return nil
    }
    return identifiers.firstIndex(of: identifier)
}

func nativeNavigationTabImageForSelection(
    isSelected: Bool,
    base: UIImage?,
    selected: UIImage?
) -> UIImage? {
    isSelected ? (selected ?? base) : base
}

func nativeNavigationSourceIndexForVisibleTab(
    visibleIndex: Int,
    visibleSourceIndices: [Int]
) -> Int? {
    guard visibleSourceIndices.indices.contains(visibleIndex) else {
        return nil
    }
    return visibleSourceIndices[visibleIndex]
}