//
//  RouteMapView.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI
import MapKit
import CoreLocation

/// Draws a recorded route as separate polylines, one per continuous segment.
///
/// Takes identified coordinate groups so the same view can present the live
/// route and a saved route without reconstructing `LocationSample` values.
/// MapKit basemap availability does not affect the route data shown.
struct RouteMapView: View {

    let segments: [RouteSegmentSnapshot]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {

        Map(position: $position) {

            ForEach(segments) { segment in

                if segment.points.count >= 2 {

                    MapPolyline(
                        coordinates: segment.coordinates
                    )
                    .stroke(
                        .blue,
                        lineWidth: 4
                    )
                }
            }

            if let startCoordinate {
                Marker(
                    "Start",
                    coordinate: startCoordinate
                )
            }

            if routePointCount > 1,
               let endCoordinate {

                Marker(
                    "End",
                    coordinate: endCoordinate
                )
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .frame(height: 260)
        .clipShape(
            RoundedRectangle(cornerRadius: 18)
        )
        .onAppear {
            position = .automatic
        }
        .onChange(of: segments) { _, _ in
            position = .automatic
        }
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        segments.first?.points.first?.coordinate
    }

    private var endCoordinate: CLLocationCoordinate2D? {
        segments.last?.points.last?.coordinate
    }

    private var routePointCount: Int {
        segments.reduce(0) {
            $0 + $1.points.count
        }
    }
}
