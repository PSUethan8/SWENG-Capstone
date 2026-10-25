//
//  RouteMapView.swift
//  GridLine
//
//  Created by Kenton & Ethan.
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteMapView: View {

    let segments: [RouteSegment]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {

        Map(position: $position) {

            ForEach(segments) { segment in

                if segment.coordinates.count >= 2 {

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

            if routeSampleCount > 1,
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
        segments.first?.samples.first?.coordinate
    }

    private var endCoordinate: CLLocationCoordinate2D? {
        segments.last?.samples.last?.coordinate
    }

    private var routeSampleCount: Int {
        segments.reduce(0) {
            $0 + $1.samples.count
        }
    }
}
