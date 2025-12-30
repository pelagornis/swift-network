import Foundation
import Network

/**
 * Network connection type.
 */
public enum ConnectionType: String, Sendable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case loopback = "Loopback"
    case other = "Other"
    case unavailable = "Unavailable"
}

/**
 * Network connection status.
 */
public enum NetworkStatus: Sendable {
    case connected(ConnectionType)
    case disconnected
    case connecting
    case requiresConnection
}

/**
 * A protocol for monitoring network connectivity.
 * 
 * NetworkMonitor provides real-time information about the device's network
 * connection status, including connection type (WiFi, Cellular, etc.) and
 * availability. This allows your app to adapt its behavior based on network conditions.
 * 
 * ## Usage
 * ```swift
 * let monitor = DefaultNetworkMonitor()
 * 
 * // Check current status
 * let status = await monitor.currentStatus
 * if case .connected(let type) = status {
 *     print("Connected via \(type)")
 * }
 * 
 * // Observe status changes
 * for await status in monitor.statusUpdates {
 *     switch status {
 *     case .connected(let type):
 *         print("Connected via \(type)")
 *     case .disconnected:
 *         print("No connection")
 *     default:
 *         break
 *     }
 * }
 * ```
 */
public protocol NetworkMonitor: Sendable {
    /// The current network status
    var currentStatus: NetworkStatus { get async }
    
    /// An async sequence of network status updates
    var statusUpdates: AsyncStream<NetworkStatus> { get }
    
    /// Whether the device is currently connected to the internet
    var isConnected: Bool { get async }
    
    /// The current connection type, if connected
    var connectionType: ConnectionType? { get async }
    
    /// Starts monitoring network connectivity
    func startMonitoring()
    
    /// Stops monitoring network connectivity
    func stopMonitoring()
}

/**
 * Default implementation of NetworkMonitor using Network Framework.
 * 
 * This monitor uses NWPathMonitor to track network connectivity and provides
 * real-time updates about connection status and type.
 */
public class DefaultNetworkMonitor: NetworkMonitor, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var statusContinuation: AsyncStream<NetworkStatus>.Continuation?
    private var currentStatusValue: NetworkStatus = .disconnected
    
    public init(requiredInterfaceType: NWInterface.InterfaceType? = nil) {
        if let interfaceType = requiredInterfaceType {
            self.monitor = NWPathMonitor(requiredInterfaceType: interfaceType)
        } else {
            self.monitor = NWPathMonitor()
        }
        self.queue = DispatchQueue(label: "com.networkkit.monitor")
    }
    
    public var currentStatus: NetworkStatus {
        get async {
            return await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(returning: self.currentStatusValue)
                }
            }
        }
    }
    
    public var statusUpdates: AsyncStream<NetworkStatus> {
        AsyncStream { continuation in
            statusContinuation = continuation
            
            monitor.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }
                
                let status = self.status(from: path)
                self.currentStatusValue = status
                
                self.queue.async {
                    continuation.yield(status)
                }
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.stopMonitoring()
            }
        }
    }
    
    public var isConnected: Bool {
        get async {
            let status = await currentStatus
            if case .connected = status {
                return true
            }
            return false
        }
    }
    
    public var connectionType: ConnectionType? {
        get async {
            let status = await currentStatus
            if case .connected(let type) = status {
                return type
            }
            return nil
        }
    }
    
    public func startMonitoring() {
        monitor.start(queue: queue)
    }
    
    public func stopMonitoring() {
        monitor.cancel()
        statusContinuation?.finish()
        statusContinuation = nil
    }
    
    private func status(from path: NWPath) -> NetworkStatus {
        guard path.status == .satisfied else {
            if path.status == .requiresConnection {
                return .requiresConnection
            }
            return .disconnected
        }
        
        // Determine connection type
        let connectionType: ConnectionType
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.usesInterfaceType(.loopback) {
            connectionType = .loopback
        } else {
            connectionType = .other
        }
        
        return .connected(connectionType)
    }
}

/**
 * A network monitor that only checks WiFi connectivity.
 */
public final class WiFiNetworkMonitor: DefaultNetworkMonitor, @unchecked Sendable {
    public init() {
        super.init(requiredInterfaceType: .wifi)
    }
}

/**
 * A network monitor that only checks cellular connectivity.
 */
public final class CellularNetworkMonitor: DefaultNetworkMonitor, @unchecked Sendable {
    public init() {
        super.init(requiredInterfaceType: .cellular)
    }
}
