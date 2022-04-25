//
//  Map+Coordinator.swift
//  Map
//
//  Created by Paul Kraft on 23.04.22.
//

import MapKit
import SwiftUI

#if !os(watchOS)

extension Map {

    // MARK: Nested Types

    public class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: Stored Properties

        private var view: Map?

        private var annotationContentByObject = [ObjectIdentifier: MapAnnotation]()
        private var annotationContentByID = [AnnotationItems.Element.ID: MapAnnotation]()

        private var overlayContentByObject = [ObjectIdentifier: MapOverlay]()
        private var overlayContentByID = [OverlayItems.Element.ID: MapOverlay]()

        private var registeredAnnotationTypes = Set<ObjectIdentifier>()
        private var regionIsChanging = false

        // MARK: Initialization

        override init() {}

        // MARK: Methods

        func update(_ mapView: MKMapView, from newView: Map, context: Context) {
            defer { view = newView }
            let animation = context.transaction.animation
            updateAnnotations(on: mapView, from: view, to: newView)
            updateInteractionModes(on: mapView, from: view, to: newView)
            updateOverlays(on: mapView, from: view, to: newView)
            updatePointOfInterestFilter(on: mapView, from: view, to: newView)
            updateRegion(on: mapView, from: view, to: newView, animated: animation != nil)
            updateType(on: mapView, from: view, to: newView)
            updateUserTracking(on: mapView, from: view, to: newView)
        }

        // MARK: Helpers

        private func registerAnnotationViewIfNeeded(on mapView: MKMapView, for content: MapAnnotation) {
            let contentType = type(of: content)
            let contentTypeKey = ObjectIdentifier(contentType)
            if !registeredAnnotationTypes.contains(contentTypeKey) {
                registeredAnnotationTypes.insert(contentTypeKey)
                contentType.register(on: mapView)
            }
        }

        private func updateAnnotations(on mapView: MKMapView, from previousView: Map?, to newView: Map) {
            let changes: CollectionDifference<AnnotationItems.Element>
            if let previousView = previousView {
                changes = newView.annotationItems.difference(from: previousView.annotationItems) { $0.id == $1.id }
            } else {
                changes = newView.annotationItems.difference(from: []) { $0.id == $1.id }
            }

            for change in changes {
                switch change {
                case let .insert(_, item, _):
                    guard !annotationContentByID.keys.contains(item.id) else {
                        assertionFailure("Duplicate annotation item id \(item.id) of \(item) found.")
                        continue
                    }
                    let content = newView.annotationContent(item)
                    let objectKey = ObjectIdentifier(content.annotation)
                    guard !annotationContentByObject.keys.contains(objectKey) else {
                        assertionFailure("Duplicate annotation for content \(content) found!")
                        continue
                    }
                    annotationContentByID[item.id] = content
                    annotationContentByObject[objectKey] = content
                    registerAnnotationViewIfNeeded(on: mapView, for: content)
                    mapView.addAnnotation(content.annotation)
                case let .remove(_, item, _):
                    guard let content = annotationContentByID[item.id] else {
                        assertionFailure("Missing annotation content for item \(item) encountered.")
                        continue
                    }
                    mapView.removeAnnotation(content.annotation)
                    annotationContentByObject.removeValue(forKey: ObjectIdentifier(content.annotation))
                    annotationContentByID.removeValue(forKey: item.id)
                }
            }
        }

        private func updateInteractionModes(on mapView: MKMapView, from previousView: Map?, to newView: Map) {
            guard previousView?.interactionModes != newView.interactionModes else {
                return
            }

            mapView.isScrollEnabled = newView.interactionModes.contains(.pan)
            mapView.isZoomEnabled = newView.interactionModes.contains(.zoom)
            #if !os(tvOS)
            mapView.isRotateEnabled = newView.interactionModes.contains(.rotate)
            #endif
        }

        private func updateOverlays(on mapView: MKMapView, from previousView: Map?, to newView: Map) {
            let changes: CollectionDifference<OverlayItems.Element>
            if let previousView = previousView {
                changes = newView.overlayItems.difference(from: previousView.overlayItems) { $0.id == $1.id }
            } else {
                changes = newView.overlayItems.difference(from: []) { $0.id == $1.id }
            }

            for change in changes {
                switch change {
                case let .insert(index, item, _):
                    guard !overlayContentByID.keys.contains(item.id) else {
                        assertionFailure("Duplicate overlay item id \(item.id) of \(item) found.")
                        continue
                    }
                    let content = newView.overlayContent(item)
                    let objectKey = ObjectIdentifier(content.overlay)
                    guard !overlayContentByObject.keys.contains(objectKey) else {
                        assertionFailure("Duplicate overlay for content \(content) found!")
                        continue
                    }
                    overlayContentByObject[objectKey] = content
                    overlayContentByID[item.id] = content
                    mapView.insertOverlay(content.overlay, at: index)
                case let .remove(_, item, _):
                    guard let content = overlayContentByID[item.id] else {
                        assertionFailure("Missing overlay content for item \(item) encountered.")
                        continue
                    }
                    overlayContentByObject.removeValue(forKey: ObjectIdentifier(content.overlay))
                    overlayContentByID.removeValue(forKey: item.id)
                    mapView.removeOverlay(content.overlay)
                }
            }
        }

        private func updatePointOfInterestFilter(on mapView: MKMapView, from previousView: Map?, to newView: Map) {
            if previousView?.pointOfInterestFilter != newView.pointOfInterestFilter {
                mapView.pointOfInterestFilter = newView.pointOfInterestFilter
            }
        }

        private func updateRegion(on mapView: MKMapView, from previousView: Map?, to newView: Map, animated: Bool) {
            guard !regionIsChanging else {
                return
            }

            if newView.usesRegion {
                let newRegion = mapView.regionThatFits(newView.coordinateRegion)
                mapView.setRegion(newRegion, animated: animated)
            } else {
                let newRect = mapView.mapRectThatFits(newView.mapRect)
                mapView.setVisibleMapRect(newRect, animated: animated)
            }
        }

        private func updateType(on mapView: MKMapView, from previousView: Map?, to newView: Map) {
            if previousView?.mapType != newView.mapType {
                mapView.mapType = newView.mapType
            }
        }

        private func updateUserTracking(on mapView: MKMapView, from previousView: Map?, to newView: Map) {
            if previousView?.showsUserLocation != newView.showsUserLocation {
                mapView.showsUserLocation = newView.showsUserLocation
            }
            if #available(macOS 11, *) {
                let newTrackingMode = newView.userTrackingMode.actualValue
                if newView.usesUserTrackingMode, mapView.userTrackingMode != newTrackingMode {
                    mapView.userTrackingMode = newTrackingMode
                }
            }
        }

        // MARK: MKMapViewDelegate

        public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            view?.coordinateRegion = mapView.region
            view?.mapRect = mapView.visibleMapRect
        }

        @available(macOS 11, *)
        public func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            guard let view = view, view.usesUserTrackingMode else {
                return
            }
            switch mode {
            case .none:
                view.userTrackingMode = .none
            case .follow:
                view.userTrackingMode = .follow
            case .followWithHeading:
                #if os(macOS) || os(tvOS)
                view.userTrackingMode = .follow
                #else
                view.userTrackingMode = .followWithHeading
                #endif
            @unknown default:
                assertionFailure("Encountered unknown user tracking mode")
            }
        }

        public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            regionIsChanging = true
        }

        public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            regionIsChanging = false
        }

        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let content = overlayContentByObject[ObjectIdentifier(overlay)] else {
                assertionFailure("Somehow an unknown overlay appeared.")
                return MKOverlayRenderer(overlay: overlay)
            }
            return content.renderer(for: mapView)
        }

        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let content = annotationContentByObject[ObjectIdentifier(annotation)] else {
                assertionFailure("Somehow an unknown annotation appeared.")
                return nil
            }
            return content.dequeue(from: mapView)
        }

    }

    // MARK: Methods

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

}

#endif