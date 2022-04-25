# Map

MapKit's SwiftUI implementation of `Map` (UIKit: MKMapView) is very limited. This library can be used as a drop-in solution (i.e. it features a very similar, but more powerful and customizable interface) to the existing `Map` and gives you so much more features and control:

## Features

- Create annotations from a list of `MKAnnotation`. You may have existing code that still has a few MKAnnotations lying around - now you can put them to good use without requiring to restructure your codebase unnecessarily. You can even use your existing `MKAnnotationView` implementations!
- Overlay support: Add your own custom overlays - featuring a backwards-compatible `MKOverlay`/`MKOverlayRenderer` interface and a more modern solution using `Identifiable` items - similar to Apple's `annotationItems` API.
- Change your map's type (`MKMapType`), user tracking mode (`MKUserTrackingMode`), interaction modes (including rotation) and point of interest filter (`MKPointOfInterestFilter`).

## Supported Platforms

- iOS 13+
- macOS 10.15+
- tvOS 13+
- watchOS 6+

Keep in mind that not all features are equally available on all platforms (based on what MapKit provides) and therefore might not be available here either. However, if you can use them using UIKit, there is a very high change that it is available here as well - if not: Let me/us know by creating an issue!

## Usage on iOS, macOS and tvOS

Very similar to MapKit's SwiftUI wrapper, you simply create a `Map` view inside the body of your view. You can define a region or mapRect, the map type (MKMapType), a pointOfInterestFilter (MKPointOfInterestFilter), interactions Modes (with values: .none, .pan, .zoon, .rotate and .all - which can be combined as you wish) and showsUserLocation.

```swift
import Map
import SwiftUI

struct MyMapView: View {

    let locations: [Location]
    let directions: MKDirections.Response
    
    @State private var region = MKCoordinateRegion()
    @State private var userTrackingMode = UserTrackingMode.follow

    var body: some View {
        Map(
          coordinateRegion: $region,
          type: .satelliteFlyover,
          pointOfInterestFilter: .excludingAll,
          interactionModes: [.pan, .rotate],
          showsUserLocation: true,
          userTrackingMode: $userTrackingMode,
          annotationItems: locations,
          annotationContent: { location in
              ViewMapAnnotation(coordinate: location.coordinate) {
                  Color.red
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
              }
          },
          overlays: directions.routes.map { $0.polyline },
          overlayContent: { overlay in
              RendererMapOverlay(overlay: overlay) { _, overlay in
                  if let polyline = overlay as? MKPolyline else {
                      let isFirstRoute = overlay === directions.routes.first?.overlay
                      let renderer = MKPolylineRenderer(polyline: polyline)
                      renderer.lineWidth = 6
                      renderer.strokeColor = isFirstRoute ? .systemBlue : .systemGray
                      return renderer
                  } else {
                      assertionFailure("Unknown overlay type found.")
                      return MKOverlayRenderer(overlay: overlay)
                  }
              }
          }
        )
        .onAppear {
            region = // ...
        }
    }

}
```

### Annotations: The modern approach

You can use a collection of items conforming to `Identifiable` and a closure that maps an item to its visual representation (available types: `MapPin`, `MapMarker` and `ViewMapAnnotation` for custom annotations from any SwiftUI `View`).

```swift
Map(
    coordinateRegion: $region,
    annotationItems: items,
    annotationContent: { item in
        if <first condition> {
            ViewMapAnnotation(coordinate: location.coordinate) {
                Color.red
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
             }
         else if <second condition> {
             MapMarker(coordinate: item.coordinate, tint: .red) // tint is `UIColor`, `NSColor` or `Color`
         } else {
             MapPin(coordinate: item.coordinate, tint: .blue) // tint is `UIColor`, `NSColor` or `Color`
         }
     }
)
```

### Annotations: The old-fashioned approach

Moving an existing code base over to SwiftUI is hard, especially when you want to keep methods, types and properties that you have previously built. This library, therefore, allows the use of `MKAnnotation` instead of being forced to the new `Identifiable` style. In the additional closure, you can use one of the options mentioned in the modern-approach. Alternatively, we also have an option to use your own `MKAnnotationView` implementations. Simply create a struct conforming to the following protocol and you are good to go.

```swift
public protocol MapAnnotation {

    static func register(on mapView: MKMapView)
    
    var annotation: MKAnnotation { get }

    func dequeue(from mapView: MKMapView) -> MKAnnotationView?
    
}
```

Note: Please make sure not to create the value of the property `annotation` dynamically. You can either use an existing object or create the object in your type's initializer. Simply put: Do not make `annotation` a computed property!

### Overlays: The modern approach

Similarly to how annotations are handled, you can also use a collection of `Identifiable` and a closure mapping it to specific overlay types. These overlay types currently contain `MapCircle`, `MapMultiPolygon`, `MapMultiPolyline`, `MapPolygon` and `MapPolyline` and this list can easily be extended by creating a type conforming to the following protocol:

```swift
public protocol MapOverlay {

    var overlay: MKOverlay { get }
    
    func renderer(for mapView: MKMapView) -> MKOverlayRenderer
    
}
```

Note: Please make sure not to create the value of the property `overlay` dynamically. You can either use an existing object or create the object in your type's initializer. Simply put: Do not make `overlay` a computed property!

### Overlays: The old-fashioned approach

Especially when working with `MKDirections` or when more customization to the `MKOverlayRenderer` is necessary, you can also provide an array of `MKOverlay` objects and use your own `MKOverlayRenderer`.

For this, we provide `RendererMapOverlay`:

```swift
Map(
    coordinateRegion: $region,
    overlays: directions.routes.map { $0.polyline },
    overlayContent: { overlay in
        RendererMapOverlay(overlay: overlay) { mapView, overlay in
            guard let polyline = overlay as? MKPolyline else {
                assertionFailure("Unknown overlay type encountered.")
                return MKMapOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 4
            renderer.strokeColor = .red
            return renderer
        }
    }
)
```

## Usage on watchOS

Since MapKit is very limited on watchOS, there is a separate (also similary limited) wrapper in this library. If you are only targeting watchOS, it might not make sense to use this library as the underlying feature set is already very limited (e.g. no overlay support, only a few kinds of possible annotations, etc).

We do include a drop-in interface though for projects that target multiple platforms and share code extensively across these platforms.

```swift
Map(
    coordinateRegion: $region,
    showsUserLocation: true,
    userTrackingMode: $userTrackingMode,
    annotationItems: annotationItems,
    annotationContent: { item in
        if <first condition> {
            ImageAnnotation(coordinate: item.coordinate, image: UIImage(...), centerOffset: CGPoint(x: 0, y: -2) 
        } else if <second condition> {
            MapPin(coordinate: item.coordinate, color: .red) // color can only be red, green or purple
        }
    }
)
```

## Author

Paul Kraft

## License

Map is available under the MIT license. See the LICENSE file for more info.