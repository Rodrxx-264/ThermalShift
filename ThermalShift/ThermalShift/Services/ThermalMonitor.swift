import Foundation

@MainActor
protocol ThermalMonitoring: AnyObject {
    var current: ThermalState { get }
    var onUpdate: ((ThermalState) -> Void)? { get set }
    /// Short label explaining where the values come from, e.g. "Simulated",
    /// "PECI probe" or "VoltageShift · MSR".
    var dataDetail: String { get }
    func start(interval: Double)
    func stop()
}