//
//  Sprint3TestSupport.swift
//  GridLineTests
//
//  Created by Kenton & Ethan.
//

import CoreLocation
import Foundation
@testable import GridLine

// MARK: - Route Helpers

/// One degree of latitude near the test coordinates is about 111 km, so this
/// step moves roughly 11.1 meters. That is above the 5 meter distance deadband
/// used with 5 meter accuracy and well within the plausibility limit.
let sprint3LatitudeStep = 0.0001

/// Every route sample identifier, flattened in segment order.
func routeSampleIDs(
    _ segments: [RouteSegment]
) -> [UUID] {

    segments.flatMap { segment in
        segment.samples.map(\.id)
    }
}

// MARK: - Queued Callback Delivery

extension Sprint2MockLocationService {

    /// Delivers a location from a background thread.
    ///
    /// The ViewModel captures the current session generation on that thread
    /// and queues its work on the main queue. Because this method returns
    /// before the main queue runs, a test can Stop or restart the session
    /// while the older callback is still waiting to be delivered.
    func emitQueuedLocation(_ location: CLLocation) {

        nonisolated(unsafe) let callback = onLocationUpdate

        runOnBackgroundThread {
            callback?(location)
        }
    }

    /// Same as `emitQueuedLocation`, but for location errors.
    func emitQueuedError(_ error: Error) {

        nonisolated(unsafe) let callback = onError

        runOnBackgroundThread {
            callback?(error)
        }
    }

    private func runOnBackgroundThread(
        _ work: @escaping () -> Void
    ) {

        nonisolated(unsafe) let work = work

        let delivered = DispatchSemaphore(value: 0)

        let thread = Thread {
            work()
            delivered.signal()
        }

        thread.start()

        delivered.wait()
    }
}
