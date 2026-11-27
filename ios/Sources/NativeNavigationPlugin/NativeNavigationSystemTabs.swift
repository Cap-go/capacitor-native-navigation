import Foundation
import UIKit

struct NativeNavigationVisibleTabEntry: Equatable {
    let sourceIndex: Int
    let id: String
    let role: String?
    let enabled: Bool
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
        let enabled = tab["enabled"] as? Bool ?? true
        entries.append(NativeNavigationVisibleTabEntry(
            sourceIndex: sourceIndex,
            id: id,
            role: role,
            enabled: enabled
        ))
    }
    return entries
}

/// Matches `makeTabBarItems`: only the last `search` / `prominent` tab is kept as trailing.
func nativeNavigationNormalizedVisibleTabEntries(
    tabs: [[String: Any]],
    selectedId: String?
) -> [NativeNavigationVisibleTabEntry] {
    let entries = nativeNavigationVisibleTabEntries(tabs: tabs, selectedId: selectedId)
    guard let lastTrailingIndex = entries.lastIndex(where: { entry in
        entry.role == "search" || entry.role == "prominent"
    }) else {
        return entries
    }
    return entries.enumerated().compactMap { index, entry in
        if (entry.role == "search" || entry.role == "prominent") && index != lastTrailingIndex {
            return nil
        }
        return entry
    }
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