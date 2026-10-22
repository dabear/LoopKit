//
//  SmartwatchManager.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// What a watch plugin shows. The host only builds and sends the parts a
/// plugin declares.
public struct SmartwatchCapabilities: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The latest glucose reading.
    public static let glucose = SmartwatchCapabilities(rawValue: 1 << 0)
    /// Recent glucose readings, for a graph.
    public static let history = SmartwatchCapabilities(rawValue: 1 << 1)
    /// Predicted glucose from the last loop run.
    public static let prediction = SmartwatchCapabilities(rawValue: 1 << 2)
    /// Insulin and carbs on board, last loop completion and closed loop state.
    public static let loopStatus = SmartwatchCapabilities(rawValue: 1 << 3)
    /// Loop's glucose alert settings and alert mute, for watches that alarm on
    /// their own instead of mirroring the phone's notifications.
    public static let alerts = SmartwatchCapabilities(rawValue: 1 << 4)
    /// Boluses requested from the watch. The plugin must authenticate each
    /// request; the host then applies its own permission and safety checks.
    public static let bolus = SmartwatchCapabilities(rawValue: 1 << 5)
}

/// What a watch needs to request a bolus, sent with `.bolus`.
public struct SmartwatchBolusContext: Equatable {
    /// Identifies the state the recommendation was computed from. A request must
    /// echo it, and the host rejects requests made against an older state.
    public var token: UUID

    /// When the host issued this context.
    public var issuedAt: Date

    /// The current manual bolus recommendation, in units. `nil` when Loop
    /// recommends no bolus; the host then rejects watch boluses.
    public var recommendedBolus: Double?

    /// The user's maximum bolus, in units.
    public var maximumBolus: Double?

    /// Bolus volumes the pump can deliver, in units.
    public var supportedBolusVolumes: [Double]

    public init(token: UUID, issuedAt: Date, recommendedBolus: Double?, maximumBolus: Double?, supportedBolusVolumes: [Double]) {
        self.token = token
        self.issuedAt = issuedAt
        self.recommendedBolus = recommendedBolus
        self.maximumBolus = maximumBolus
        self.supportedBolusVolumes = supportedBolusVolumes
    }
}

/// A bolus the user confirmed on the watch, after the plugin authenticated it.
public struct SmartwatchBolusRequest: Equatable {
    public var units: Double
    /// `SmartwatchBolusContext.token` from the snapshot the watch showed.
    public var contextToken: UUID
    /// When the user confirmed the bolus on the watch.
    public var requestedAt: Date

    public init(units: Double, contextToken: UUID, requestedAt: Date) {
        self.units = units
        self.contextToken = contextToken
        self.requestedAt = requestedAt
    }
}

/// Why the host did not deliver a watch bolus.
public enum SmartwatchBolusError: Error, Equatable {
    /// Watch boluses are turned off, or the plugin lacks `.bolus`.
    case notAllowed
    case invalidAmount
    /// The request is too old, or dated in the future.
    case expiredRequest
    /// The request was made against an older state than the current one.
    case staleContext
    case exceedsMaximumBolus
    case exceedsRecommendation
    /// Too soon after the previous watch bolus.
    case rateLimited
    /// Watch boluses in the last 24 hours would exceed the daily limit.
    case dailyLimitReached
    case deliveryFailed(String)
}

/// A glucose display unit. Plugins get plain values instead of a quantity type,
/// so they build against any LoopKit variant a host uses.
public enum SmartwatchGlucoseUnit: Equatable, Sendable {
    case milligramsPerDeciliter
    case millimolesPerLiter
}

/// A stored glucose reading, in mg/dL.
public struct SmartwatchGlucoseReading: Equatable, Sendable {
    public var date: Date
    public var milligramsPerDeciliter: Double
    public var trend: GlucoseTrend?
    /// mg/dL per minute, if the CGM reports a rate.
    public var trendRate: Double?
    /// Entered by the user, such as a fingerstick.
    public var wasUserEntered: Bool
    /// Shown by the CGM but not to be used for dosing or graphs.
    public var isDisplayOnly: Bool

    public init(date: Date, milligramsPerDeciliter: Double, trend: GlucoseTrend? = nil, trendRate: Double? = nil, wasUserEntered: Bool = false, isDisplayOnly: Bool = false) {
        self.date = date
        self.milligramsPerDeciliter = milligramsPerDeciliter
        self.trend = trend
        self.trendRate = trendRate
        self.wasUserEntered = wasUserEntered
        self.isDisplayOnly = isDisplayOnly
    }
}

/// One point of the predicted glucose curve, in mg/dL.
public struct SmartwatchPredictedGlucose: Equatable, Sendable {
    public var date: Date
    public var milligramsPerDeciliter: Double

    public init(date: Date, milligramsPerDeciliter: Double) {
        self.date = date
        self.milligramsPerDeciliter = milligramsPerDeciliter
    }
}

/// The state a watch shows, built by the host from the same data it sends to
/// the Apple Watch.
///
/// The host sends a new snapshot as soon as a new CGM reading is stored, before
/// the loop runs, and again when the loop's output changes. Loop-derived values
/// keep their last known value until the loop updates them.
public struct SmartwatchStatusSnapshot: Equatable {
    /// How far back `glucoseHistory` reaches.
    public static let historyInterval: TimeInterval = .hours(3)

    public var displayUnit: SmartwatchGlucoseUnit

    /// Bolus context, with `.bolus`. Replaced whenever the recommendation, the
    /// maximum bolus or the latest glucose changes, and after each watch bolus.
    public var bolusContext: SmartwatchBolusContext?

    /// The latest stored reading, including user-entered and display-only
    /// readings; check their flags before showing one as a CGM reading.
    public var glucose: SmartwatchGlucoseReading?

    /// Stored readings from the last `historyInterval`, oldest first.
    /// Empty unless the plugin declares `.history`.
    public var glucoseHistory: [SmartwatchGlucoseReading]

    /// Predicted glucose from the last loop run. `nil` unless the plugin
    /// declares `.prediction`, or before the loop has run.
    public var predictedGlucose: [SmartwatchPredictedGlucose]?

    /// Units of insulin on board, with `.loopStatus`.
    public var insulinOnBoard: Double?

    /// Grams of carbs on board, with `.loopStatus`.
    public var carbsOnBoard: Double?

    /// When the loop last completed, with `.loopStatus`.
    public var lastLoopCompleted: Date?

    /// Whether automatic dosing is on, with `.loopStatus`.
    public var isClosedLoop: Bool?

    public init(
        displayUnit: SmartwatchGlucoseUnit,
        glucose: SmartwatchGlucoseReading?,
        glucoseHistory: [SmartwatchGlucoseReading] = [],
        predictedGlucose: [SmartwatchPredictedGlucose]? = nil,
        insulinOnBoard: Double? = nil,
        carbsOnBoard: Double? = nil,
        lastLoopCompleted: Date? = nil,
        isClosedLoop: Bool? = nil,
        bolusContext: SmartwatchBolusContext? = nil
    ) {
        self.displayUnit = displayUnit
        self.glucose = glucose
        self.glucoseHistory = glucoseHistory
        self.predictedGlucose = predictedGlucose
        self.insulinOnBoard = insulinOnBoard
        self.carbsOnBoard = carbsOnBoard
        self.lastLoopCompleted = lastLoopCompleted
        self.isClosedLoop = isClosedLoop
        self.bolusContext = bolusContext
    }
}

/// The host's glucose alert settings and mute, for watches that alarm on their own.
///
/// The Apple Watch does not need this: it mirrors the phone's notifications.
public struct SmartwatchGlucoseAlertState: Equatable {
    /// The active glucose alert profile, in mg/dL.
    public struct Configuration: Equatable {
        public var urgentLowThreshold: Double
        public var lowThreshold: Double
        public var highThreshold: Double
        public var urgentLowEnabled: Bool
        public var lowEnabled: Bool
        public var highEnabled: Bool
        public var urgentLowRepeatInterval: TimeInterval
        /// `nil` when the host alerts once per low episode.
        public var lowRepeatInterval: TimeInterval?
        /// `nil` when the host alerts once per high episode.
        public var highRepeatInterval: TimeInterval?

        public init(
            urgentLowThreshold: Double,
            lowThreshold: Double,
            highThreshold: Double,
            urgentLowEnabled: Bool,
            lowEnabled: Bool,
            highEnabled: Bool,
            urgentLowRepeatInterval: TimeInterval,
            lowRepeatInterval: TimeInterval?,
            highRepeatInterval: TimeInterval?
        ) {
            self.urgentLowThreshold = urgentLowThreshold
            self.lowThreshold = lowThreshold
            self.highThreshold = highThreshold
            self.urgentLowEnabled = urgentLowEnabled
            self.lowEnabled = lowEnabled
            self.highEnabled = highEnabled
            self.urgentLowRepeatInterval = urgentLowRepeatInterval
            self.lowRepeatInterval = lowRepeatInterval
            self.highRepeatInterval = highRepeatInterval
        }
    }

    /// `nil` when the host has no glucose alert settings.
    public var configuration: Configuration?

    /// `false` while the host leaves glucose alerts to the CGM's own alerts.
    public var hostAlertsActive: Bool

    /// When the host's alert mute ends, if its alerts are muted now.
    public var mutedUntil: Date?

    public init(configuration: Configuration?, hostAlertsActive: Bool, mutedUntil: Date?) {
        self.configuration = configuration
        self.hostAlertsActive = hostAlertsActive
        self.mutedUntil = mutedUntil
    }
}

public protocol SmartwatchManagerDelegate: DeviceManagerDelegate {
    /// Informs the delegate that the manager's `rawState` changed and should be saved.
    func smartwatchManagerDidUpdateState(_ manager: SmartwatchManager)

    /// Asks the delegate to remove the manager.
    func smartwatchManagerWantsDeletion(_ manager: SmartwatchManager) async

    /// Stored readings since `start`, oldest first, for a watch that needs more
    /// history than the snapshots carry.
    func smartwatchManager(_ manager: SmartwatchManager, glucoseSamplesSince start: Date) async throws -> [SmartwatchGlucoseReading]

    /// Asks the delegate to send the current snapshot and alert state again, for
    /// example after the watch reconnects.
    func smartwatchManagerRequestsRefresh(_ manager: SmartwatchManager)

    /// Asks the host to deliver a bolus the user confirmed on the watch. Call
    /// only after authenticating the request. The host checks its own
    /// permission, the request's age and context, the maximum bolus, the
    /// recommendation and rate limits before delivering.
    ///
    /// - Returns: The delivered units, rounded to a supported volume.
    /// - Throws: `SmartwatchBolusError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestBolus request: SmartwatchBolusRequest) async throws -> Double
}

/// A watch that shows the host app's state, implemented by a plugin.
///
/// The host calls the update methods on the main actor; delegate methods are
/// called on `delegateQueue`.
public protocol SmartwatchManager: DeviceManager {
    var smartwatchManagerDelegate: SmartwatchManagerDelegate? { get set }

    /// The queue on which SmartwatchManagerDelegate methods are called.
    /// Setting to nil resets to a default provided by the manager.
    var delegateQueue: DispatchQueue! { get set }

    /// What the watch shows; the host leaves out the rest.
    static var capabilities: SmartwatchCapabilities { get }

    /// The latest snapshot. Called as soon as a new glucose reading is stored and
    /// whenever the loop's output changes.
    @MainActor
    func watchDataDidUpdate(_ snapshot: SmartwatchStatusSnapshot)

    /// The host's glucose alert settings or mute changed. Only called with `.alerts`.
    @MainActor
    func glucoseAlertStateDidUpdate(_ state: SmartwatchGlucoseAlertState)

    /// Stops the manager before it is removed.
    func delete(completion: @escaping () -> Void)
}

public extension SmartwatchManager {
    @MainActor
    func glucoseAlertStateDidUpdate(_ state: SmartwatchGlucoseAlertState) {}

    /// Convenience wrapper for notifying the delegate of deletion on the delegate queue
    ///
    /// - Parameters:
    ///   - completion: A closure called from the delegate queue after the delegate is called
    func notifyDelegateOfDeletion(completion: @escaping () -> Void) {
        delegateQueue.async {
            Task {
                await self.smartwatchManagerDelegate?.smartwatchManagerWantsDeletion(self)
                completion()
            }
        }
    }

    /// Override this default behaviour if the watch manager needs to complete tasks before being deleted
    func delete(completion: @escaping () -> Void) {
        notifyDelegateOfDeletion(completion: completion)
    }

    // Watches don't issue LoopKit alerts by default. Defaulting these keeps
    // plugins independent of the host's AlertResponder signature.
    func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) async throws {}
    func getSoundBaseURL() -> URL? { nil }
    func getSounds() -> [Alert.Sound] { [] }
}
