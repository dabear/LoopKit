//
//  SmartwatchManager.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

// This protocol family is intentionally free of `DeviceManager` and of any other
// LoopKit type, so the same plugin builds against any AID's LoopKit (Loop loads it
// dynamically; Trio imports it statically). The UI layer (`SmartwatchManagerUI` in
// LoopKitUI) adds `DeviceManagerUI`, so a plugin conforms to `DeviceManager` in its
// own extension.

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
    /// Host-issued alerts: the host forwards its own alerts to the watch as they
    /// fire and retracts them. The host decides
    /// what alarms; the watch does not evaluate thresholds itself. A host forwards
    /// what its own mute lets through: Loop's mute silences every alert, so it
    /// forwards none while muted; a host whose critical alerts bypass its mute
    /// may forward those.
    public static let alerts = SmartwatchCapabilities(rawValue: 1 << 4)
    /// Boluses requested from the watch. The plugin must authenticate each
    /// request; the host then applies its own permission and safety checks.
    public static let remoteBolus = SmartwatchCapabilities(rawValue: 1 << 5)
    /// Therapy context: basal, insulin sensitivity, eventual glucose, sensitivity
    /// ratio, correction target and the active preset. Off unless a plugin declares it.
    public static let therapy = SmartwatchCapabilities(rawValue: 1 << 6)
    /// The watch can ask the host to mute its alerts. The host acts on it only if
    /// its user allowed muting from the watch.
    public static let remoteMute = SmartwatchCapabilities(rawValue: 1 << 7)
    /// The watch can ask the host to add a carb entry. The host acts on it only
    /// if its user allowed it.
    public static let remoteCarbs = SmartwatchCapabilities(rawValue: 1 << 8)
    /// The watch can ask the host to start or end an override preset. The host
    /// sends its presets and acts on requests only if its user allowed it.
    public static let remoteOverride = SmartwatchCapabilities(rawValue: 1 << 9)
    /// The watch can ask the host to start or end a temp target preset, for hosts
    /// that have temp targets. The host acts on it only if its user allowed it.
    public static let remoteTempTarget = SmartwatchCapabilities(rawValue: 1 << 10)
}

extension SmartwatchCapabilities: CustomStringConvertible {
    private static let names: [(SmartwatchCapabilities, String)] = [
        (.glucose, "glucose"),
        (.history, "history"),
        (.prediction, "prediction"),
        (.loopStatus, "loopStatus"),
        (.alerts, "alerts"),
        (.remoteBolus, "remoteBolus"),
        (.therapy, "therapy"),
        (.remoteMute, "remoteMute"),
        (.remoteCarbs, "remoteCarbs"),
        (.remoteOverride, "remoteOverride"),
        (.remoteTempTarget, "remoteTempTarget"),
    ]

    /// The capability names, for logs, for example "loopStatus, remoteBolus".
    /// Bits without a name show as their raw value.
    public var description: String {
        var parts = Self.names.filter { contains($0.0) }.map(\.1)
        let unnamed = subtracting(Self.names.reduce(into: []) { $0.formUnion($1.0) })
        if !unnamed.isEmpty {
            parts.append("raw value \(unnamed.rawValue)")
        }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
}

/// What the algorithm is working with right now, sent with `.therapy`. Glucose
/// values are mg/dL. A host leaves out what it doesn't have: Loop has no
/// sensitivity ratio, for example.
public struct SmartwatchTherapyContext: Equatable, Sendable {
    /// Units per hour of the running temp basal; `nil` while none is running.
    public var tempBasalRate: Double?

    /// Units per hour of the scheduled basal now.
    public var scheduledBasalRate: Double?

    /// mg/dL per unit, the insulin sensitivity now.
    public var insulinSensitivity: Double?

    /// mg/dL, where the latest forecast ends.
    public var eventualGlucose: Double?

    /// The algorithm's sensitivity ratio (1 = no adjustment), for hosts that have one.
    public var sensitivityRatio: Double?

    /// mg/dL, the correction range in effect now, including any preset or temp target.
    public var correctionRange: ClosedRange<Double>?

    /// The name of the active preset, override or temp target.
    public var activePresetName: String?

    /// When the active preset ends; `nil` while none is active or it runs indefinitely.
    public var activePresetEnd: Date?

    public init(
        tempBasalRate: Double? = nil,
        scheduledBasalRate: Double? = nil,
        insulinSensitivity: Double? = nil,
        eventualGlucose: Double? = nil,
        sensitivityRatio: Double? = nil,
        correctionRange: ClosedRange<Double>? = nil,
        activePresetName: String? = nil,
        activePresetEnd: Date? = nil
    ) {
        self.tempBasalRate = tempBasalRate
        self.scheduledBasalRate = scheduledBasalRate
        self.insulinSensitivity = insulinSensitivity
        self.eventualGlucose = eventualGlucose
        self.sensitivityRatio = sensitivityRatio
        self.correctionRange = correctionRange
        self.activePresetName = activePresetName
        self.activePresetEnd = activePresetEnd
    }
}

/// A glucose display unit. Plugins get plain values instead of a quantity type,
/// so they build against any LoopKit variant a host uses.
public enum SmartwatchGlucoseUnit: Equatable, Sendable {
    case milligramsPerDeciliter
    case millimolesPerLiter
}

/// A glucose trend, independent of LoopKit's `GlucoseTrend` so the wire model
/// carries no LoopKit type. Raw values match `GlucoseTrend` (1...7), so a host
/// maps with `SmartwatchGlucoseTrend(rawValue:)`.
public enum SmartwatchGlucoseTrend: Int, Equatable, Sendable, CaseIterable {
    case upUpUp = 1
    case upUp
    case up
    case flat
    case down
    case downDown
    case downDownDown
}

/// A stored glucose reading, in mg/dL.
public struct SmartwatchGlucoseReading: Equatable, Sendable {
    public var date: Date
    public var milligramsPerDeciliter: Double
    public var trend: SmartwatchGlucoseTrend?
    /// mg/dL per minute, if the CGM reports a rate.
    public var trendRate: Double?
    /// Entered by the user, such as a fingerstick.
    public var wasUserEntered: Bool
    /// Shown by the CGM but not to be used for dosing or graphs.
    public var isDisplayOnly: Bool

    public init(date: Date, milligramsPerDeciliter: Double, trend: SmartwatchGlucoseTrend? = nil, trendRate: Double? = nil, wasUserEntered: Bool = false, isDisplayOnly: Bool = false) {
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

/// The state a watch shows, built by the host.
///
/// The host sends a new snapshot as soon as a new CGM reading is stored, before
/// the loop runs, and again when the loop's output changes. Loop-derived values
/// keep their last known value until the loop updates them.
public struct SmartwatchStatusSnapshot: Equatable {
    /// How far back `glucoseHistory` reaches.
    public static let historyInterval: TimeInterval = .hours(3)

    public var displayUnit: SmartwatchGlucoseUnit

    /// Bolus context, with `.remoteBolus`. Replaced whenever the recommendation, the
    /// maximum bolus or the latest glucose changes, and after each watch bolus.
    public var bolusContext: SmartwatchBolusContext?

    /// The host's override presets, with `.remoteOverride`.
    public var overridePresets: [SmartwatchPreset]?

    /// The host's temp target presets, with `.remoteTempTarget`.
    public var tempTargetPresets: [SmartwatchPreset]?

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

    /// Whether automatic dosing is on, with `.loopStatus`. True only in full
    /// closed loop; hosts with other modes (open loop, low glucose suspend only,
    /// basal testing) send false for them.
    public var isClosedLoop: Bool?

    /// Basal, sensitivity and target context, with `.therapy`.
    public var therapy: SmartwatchTherapyContext?

    public init(
        displayUnit: SmartwatchGlucoseUnit,
        glucose: SmartwatchGlucoseReading?,
        glucoseHistory: [SmartwatchGlucoseReading] = [],
        predictedGlucose: [SmartwatchPredictedGlucose]? = nil,
        insulinOnBoard: Double? = nil,
        carbsOnBoard: Double? = nil,
        lastLoopCompleted: Date? = nil,
        isClosedLoop: Bool? = nil,
        bolusContext: SmartwatchBolusContext? = nil,
        therapy: SmartwatchTherapyContext? = nil,
        overridePresets: [SmartwatchPreset]? = nil,
        tempTargetPresets: [SmartwatchPreset]? = nil
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
        self.therapy = therapy
        self.overridePresets = overridePresets
        self.tempTargetPresets = tempTargetPresets
    }
}

/// Identifies a host alert so it can be retracted.
public struct SmartwatchAlertIdentifier: Equatable, Hashable, Sendable {
    public var value: String
    public init(_ value: String) {
        self.value = value
    }
}

/// How urgent a host alert is. Maps from the host's own interruption levels.
public enum SmartwatchAlertLevel: Int, Equatable, Sendable {
    case informational
    case warning
    case critical
}

/// Which glucose alert a host alert is. The host sets it on `SmartwatchAlert`;
/// `nil` means the alert isn't a glucose alert.
///
/// Why a dedicated type rather than reading the alert itself:
/// - A watch needs to know *which* glucose alert is active, for example to colour
///   its glucose ring red for a low and amber for a high, without thresholds of
///   its own (they would drift from the host's alert settings).
/// - The alert identifier can't tell it reliably: every host names its alerts
///   differently. Loop uses `GlucoseAlertManager.glucose.low`, Trio
///   `Trio.glucose.low.<UUID>` and calls its predicted low `forecastedLow`. A
///   plugin matching such strings works with one host and silently does nothing
///   with another.
/// - The interruption level can't either: low and high are both time-sensitive,
///   and urgent low is critical only in builds with the critical-alerts
///   entitlement.
/// - Pump, CGM and other alerts must not change a glucose display, so they are
///   `nil` rather than guessed from their text.
///
/// So the host, which knows its own alerts, maps them once to these cases.
public enum SmartwatchGlucoseAlertType: String, Equatable, Sendable {
    case urgentLow
    case low
    case high
    /// A low the host forecasts, before glucose is low.
    case predictedLow
}

/// An alert the host issued and forwarded to the watch. The host evaluates its
/// own alerts (on a background CGM or pump update) and sends the result; the
/// watch shows it and vibrates.
public struct SmartwatchAlert: Equatable, Sendable {
    public var identifier: SmartwatchAlertIdentifier
    public var level: SmartwatchAlertLevel
    public var title: String?
    public var body: String?
    /// When the host issued the alert.
    public var issuedAt: Date
    /// Set by the host for glucose alerts; `nil` for any other alert.
    public var glucoseAlertType: SmartwatchGlucoseAlertType?

    public init(identifier: SmartwatchAlertIdentifier, level: SmartwatchAlertLevel, title: String? = nil, body: String? = nil, issuedAt: Date, glucoseAlertType: SmartwatchGlucoseAlertType? = nil) {
        self.identifier = identifier
        self.level = level
        self.title = title
        self.body = body
        self.issuedAt = issuedAt
        self.glucoseAlertType = glucoseAlertType
    }
}

/// One line for the host's device log, sent by the plugin. Mirrors LoopKit's
/// `DeviceLogEntryType` so a host that keeps a device log maps it directly,
/// without the plugin depending on `DeviceManagerDelegate`.
public struct SmartwatchDeviceLogEntry: Equatable, Sendable {
    public enum EntryType: String, Sendable {
        case send, receive, error, delegate, delegateResponse, connection
    }
    public var type: EntryType
    public var message: String
    /// The watch the line is about (for example the watchface UUID), if any.
    public var deviceIdentifier: String?

    public init(type: EntryType, message: String, deviceIdentifier: String? = nil) {
        self.type = type
        self.message = message
        self.deviceIdentifier = deviceIdentifier
    }
}

public protocol SmartwatchManagerDelegate: AnyObject {
    /// Informs the delegate that the manager's `rawState` changed and should be saved.
    func smartwatchManagerDidUpdateState(_ manager: SmartwatchManager)

    /// Asks the delegate to remove the manager.
    func smartwatchManagerWantsDeletion(_ manager: SmartwatchManager) async

    /// Asks the delegate to send the current snapshot again, for example after
    /// the watch reconnects.
    func smartwatchManagerRequestsRefresh(_ manager: SmartwatchManager)

    /// A line for the host's device log. The host routes it to wherever it keeps
    /// device communication logs; a host without one may ignore it.
    func smartwatchManager(_ manager: SmartwatchManager, didLogEvent event: SmartwatchDeviceLogEntry)

    /// Asks the host to deliver a bolus the user confirmed on the watch. Call
    /// only after authenticating the request. The host checks its own
    /// permission, the request's age and context, the maximum bolus, the
    /// recommendation and rate limits before delivering.
    ///
    /// - Returns: The delivered units, rounded to a supported volume.
    /// - Throws: `SmartwatchBolusError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestBolus request: SmartwatchBolusRequest) async throws -> Double

    /// The user asked on the watch to mute the host's alerts.
    /// Only called with `.remoteMute`; the host decides whether its user allowed it.
    ///
    /// - Returns: When the mute ends.
    /// - Throws: `SmartwatchAlertMuteError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestAlertMute request: SmartwatchAlertMuteRequest) async throws -> Date

    /// The user asked on the watch to add carbs now. Only called with
    /// `.remoteCarbs`; the host decides whether its user allowed it.
    ///
    /// - Returns: The grams added.
    /// - Throws: `SmartwatchCarbEntryError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestCarbEntry request: SmartwatchCarbEntryRequest) async throws -> Double

    /// The user started or ended an override preset on the watch. Only called with
    /// `.remoteOverride`; the host decides whether its user allowed it.
    ///
    /// - Throws: `SmartwatchPresetError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestOverride request: SmartwatchOverrideRequest) async throws

    /// The user started or ended a temp target preset on the watch. Only called
    /// with `.remoteTempTarget`; the host decides whether its user allowed it.
    ///
    /// - Throws: `SmartwatchPresetError`.
    func smartwatchManager(_ manager: SmartwatchManager, requestTempTarget request: SmartwatchTempTargetRequest) async throws
}

/// Every remote action is refused unless the host implements it.
public extension SmartwatchManagerDelegate {
    func smartwatchManager(_ manager: SmartwatchManager, requestBolus request: SmartwatchBolusRequest) async throws -> Double {
        throw SmartwatchBolusError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestAlertMute request: SmartwatchAlertMuteRequest) async throws -> Date {
        throw SmartwatchAlertMuteError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestCarbEntry request: SmartwatchCarbEntryRequest) async throws -> Double {
        throw SmartwatchCarbEntryError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestOverride request: SmartwatchOverrideRequest) async throws {
        throw SmartwatchPresetError.notAllowed
    }

    func smartwatchManager(_ manager: SmartwatchManager, requestTempTarget request: SmartwatchTempTargetRequest) async throws {
        throw SmartwatchPresetError.notAllowed
    }
}

/// A watch that shows the host app's state, implemented by a plugin.
///
/// The host calls the update methods on the main actor; the delegate may be
/// called from any thread.
public protocol SmartwatchManager: AnyObject {
    typealias RawStateValue = [String: Any]

    /// Recreate the manager from its persisted state. Returns nil if the state
    /// cannot be restored.
    init?(rawState: RawStateValue)

    /// The state to persist, so the host can recreate the manager on next launch.
    var rawState: RawStateValue { get }

    /// A stable identifier for this watch manager, used to persist, restore and
    /// log it. When the manager also conforms to `Pluggable` (via a host's
    /// `DeviceManager`), the same value satisfies both.
    var pluginIdentifier: String { get }

    var smartwatchManagerDelegate: SmartwatchManagerDelegate? { get set }

    /// What the watch can show or do; the host leaves out the rest.
    static var capabilities: SmartwatchCapabilities { get }

    /// What the watch wants right now, for example less than `capabilities` when
    /// the user turned a display element off. Only declared capabilities count:
    /// anything requested beyond `capabilities` is ignored (see
    /// `effectiveCapabilities`). Call `smartwatchManagerRequestsRefresh` after it
    /// changes. Defaults to `capabilities`.
    var requestedCapabilities: SmartwatchCapabilities { get }

    /// The latest snapshot. Called as soon as a new glucose reading is stored and
    /// whenever the loop's output changes.
    @MainActor
    func watchDataDidUpdate(_ snapshot: SmartwatchStatusSnapshot)

    /// A host alert fired and should show on the watch. Only called with `.alerts`.
    @MainActor
    func watchAlertDidIssue(_ alert: SmartwatchAlert)

    /// A host alert was retracted and should clear on the watch. Only called with `.alerts`.
    @MainActor
    func watchAlertDidRetract(_ identifier: SmartwatchAlertIdentifier)

    /// A note from the host about the watch, such as why an alert was not sent to
    /// it or when the host repeats one. The host has already written it to its own
    /// device log; the plugin may show it in its own log next to the watch traffic.
    @MainActor
    func watchHostDidLog(_ message: String)

    /// The host received a URL meant for watch plugins, such as a companion
    /// app's callback after the user picked a watch there. Returns whether the
    /// plugin handled it; the host registers the URL scheme. Defaulted to `false`.
    @MainActor
    func watchHostDidReceiveURL(_ url: URL) -> Bool

    /// Stops the manager before it is removed.
    func delete(completion: @escaping () -> Void)
}

public extension SmartwatchManager {
    var requestedCapabilities: SmartwatchCapabilities { Self.capabilities }

    /// What the host acts on: the requested capabilities the plugin declares.
    /// Hosts use this for every capability check (snapshot contents, alerts and
    /// remote actions), so a plugin can't obtain a capability it didn't declare.
    /// Not a protocol requirement, so a plugin can't override it.
    var effectiveCapabilities: SmartwatchCapabilities {
        Self.capabilities.intersection(requestedCapabilities)
    }

    /// Requested capabilities the plugin doesn't declare; ignored by hosts.
    var undeclaredRequestedCapabilities: SmartwatchCapabilities {
        requestedCapabilities.subtracting(Self.capabilities)
    }

    // Alerts are capability-gated; a plugin without `.alerts` need not implement these.
    @MainActor
    func watchAlertDidIssue(_ alert: SmartwatchAlert) {}
    @MainActor
    func watchAlertDidRetract(_ identifier: SmartwatchAlertIdentifier) {}
    @MainActor
    func watchHostDidLog(_ message: String) {}
    @MainActor
    func watchHostDidReceiveURL(_ url: URL) -> Bool { false }

    /// Asks the delegate to remove the manager, then calls `completion`.
    func notifyDelegateOfDeletion(completion: @escaping () -> Void) {
        Task {
            await smartwatchManagerDelegate?.smartwatchManagerWantsDeletion(self)
            completion()
        }
    }

    /// Override this default behaviour if the watch manager needs to complete tasks before being deleted
    func delete(completion: @escaping () -> Void) {
        notifyDelegateOfDeletion(completion: completion)
    }
}
