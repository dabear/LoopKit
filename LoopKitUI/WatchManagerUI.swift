//
//  WatchManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopAlgorithm

public struct WatchManagerDescriptor {
    public let identifier: String
    public let localizedTitle: String
    /// The watches the plugin supports, or other details shown under the title in the picker
    public let subtitle: String?
    public let manufacturer: String?
    public let image: UIImage?

    public init(
        identifier: String,
        localizedTitle: String,
        subtitle: String? = nil,
        manufacturer: String?,
        image: UIImage?
    ) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
        self.subtitle = subtitle
        self.manufacturer = manufacturer
        self.image = image
    }
}

public typealias WatchManagerViewController = (UIViewController & WatchManagerOnboarding & CompletionNotifying)

public protocol WatchManagerUI: WatchManager, DeviceManagerUI, DisplayGlucoseUnitObserver {
    /// Create and onboard a new watch manager.
    ///
    /// - Parameters:
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - displayGlucosePreference: The glucose units to use for display.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the watch manager or a newly created and onboarded watch manager.
    @MainActor
    static func setupViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> SetupUIResult<WatchManagerViewController, WatchManagerUI>

    /// Configure settings for an existing watch manager.
    ///
    /// - Parameters:
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - displayGlucosePreference: The glucose units to use for display.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing watch manager.
    @MainActor
    func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> WatchManagerViewController

    /// A message from the watch that needs to be brought to the user's attention in Settings → Devices.
    var watchStatusHighlight: DeviceStatusHighlight? { get }
}

extension WatchManagerUI {
    public var watchStatusHighlight: DeviceStatusHighlight? { nil }

    /// When conformance to the DisplayGlucoseUnitObserver is desired, use this function to be notified when the user display glucose unit changes
    public func unitDidChange(to displayGlucoseUnit: LoopUnit) {
        // optional
    }
}

@MainActor
public protocol WatchManagerOnboardingDelegate: AnyObject {
    /// Informs the delegate that the specified watch manager was created.
    ///
    /// - Parameters:
    ///     - watchManager: The watch manager created.
    func watchManagerOnboarding(didCreateWatchManager watchManager: WatchManagerUI)

    /// Informs the delegate that the specified watch manager was onboarded.
    ///
    /// - Parameters:
    ///     - watchManager: The watch manager onboarded.
    func watchManagerOnboarding(didOnboardWatchManager watchManager: WatchManagerUI)
}

@MainActor
public protocol WatchManagerOnboarding {
    /// Delegate to notify about watch manager onboarding.
    var watchManagerOnboardingDelegate: WatchManagerOnboardingDelegate? { get set }
}
