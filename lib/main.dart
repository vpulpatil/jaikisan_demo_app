import 'dart:async';
import 'dart:collection';

import 'package:area/area.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_polyutil/google_map_polyutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as Locn;
import 'package:location_permissions/location_permissions.dart';

void main() {
  runApp(MyMapApp());
}

class FirstRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Splash Screen'),
      ),
      body: Center(
        child: RaisedButton(
          child: Text('Open route'),
          onPressed: () {
            // Navigate to second route when tapped.
          },
        ),
      ),
    );
  }
}

class MyMapApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyMapApp> {
  GoogleMapController mapController;
  Completer<GoogleMapController> _controller = Completer();

  var zoomLevel = 13.0;
  final Map<PolygonId, Polygon> polygon = HashMap<PolygonId, Polygon>();
  final Set<Marker> markers = HashSet<Marker>();
  final List<LatLng> polyLatLng = List<LatLng>();
  Polygon currentPolygon;
  String currentPolygonAreaText = "No Polygon selected";
  var locationEnabled = false;
  var showPolygonInfo = false;
  final polygonFillColor = Color.fromARGB(23, 00, 00, 00);
  final selectedPolygonFillColor = Color.fromARGB(200, 17, 186, 52);

  @override
  void initState() {
    super.initState();
    checkLocationPermission();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _controller.complete(controller);
  }

  void checkLocationPermission() async {
    //Checking if user has given Location Permission or not
    PermissionStatus checkStatus = await LocationPermissions()
        .checkPermissionStatus(
            level: LocationPermissionLevel.locationWhenInUse);

    if (checkStatus == PermissionStatus.denied) {
      //Permission is denied, therefore request for permission
      PermissionStatus permission =
          await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.denied) {
        //Location Runtime permission is denied or denied forever, then don't do anything
        return;
      }
    }

    //Now check if the gps is on or not
    var location = Locn.Location();
    bool _gpsEnabled = await location.serviceEnabled();
    if (!_gpsEnabled) {
      //GPS is not enabled
      _gpsEnabled = await location.requestService();
      if (!_gpsEnabled) {
        //GPS is not enabled by user, therefore get user's last known locations
        Position lastKnownPosition = await Geolocator().getLastKnownPosition(
          desiredAccuracy: LocationAccuracy.high,
          locationPermissionLevel: GeolocationPermission.locationWhenInUse,
        );
        setLocationEnabledAction(
            lastKnownPosition.latitude, lastKnownPosition.longitude);
        return;
      }
    }
    Position position = await Geolocator().getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      locationPermissionLevel: GeolocationPermission.locationWhenInUse,
    );
    setLocationEnabledAction(position.latitude, position.longitude);

  }

  void setLocationEnabledAction(double latitude, double longitude) async {
    setState(() {
      locationEnabled = true;
    });
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        new CameraPosition(target: LatLng(latitude, longitude), zoom: 17.0)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Maps Sample App'),
          backgroundColor: Colors.green[700],
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            // otherwise the logo will be tiny
            GoogleMap(
              onMapCreated: _onMapCreated,
              myLocationEnabled: locationEnabled,
              myLocationButtonEnabled: locationEnabled,
              initialCameraPosition: CameraPosition(
                target: LatLng(12.970314, 77.591789), //this is default location
                zoom: 13.0,
              ),
              markers: markers,
              polygons: Set<Polygon>.of(polygon.values),
              onTap: googleMapTapped,
            ),
            Visibility(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RaisedButton(
                      onPressed: resetButtonClicked,
                      child: Text("Reset Polygon")),
                  Text(
                    currentPolygonAreaText,
                    style: TextStyle(
                        backgroundColor: Colors.black, color: Colors.white),
                  ),
                ],
              ),
              visible: showPolygonInfo,
            ),
          ],
        ),
      ),
    );
  }

  void googleMapTapped(LatLng tappedLatLng) async {
    print("googleMap tapped");
    for (Polygon singlePg in polygon.values) {
      bool isLocationInsidePolygon = await GoogleMapPolyUtil.containsLocation(
          point: tappedLatLng, polygon: singlePg.points);
      if (isLocationInsidePolygon) {
        print("This is a Part of Polygon");
        polygonTapped(singlePg);
        return;
      }
    }
    polyLatLng.add(tappedLatLng);
    setState(() {
      markers.add(Marker(
        markerId: MarkerId(tappedLatLng.hashCode.toString()),
        position: tappedLatLng,
        draggable: false,
        consumeTapEvents: true,
        onTap: onMarkerTapped,
      ));
      showPolygonInfo = false;
    });
  }

  polygonTapped(Polygon selectedPolygon) {
    print("polygon tapped");

    currentPolygon = selectedPolygon;

    //calculating
    var polygonArea = getAreaOfPolygon(selectedPolygon);

    print("The world area is: $polygonArea m²");

    setState(() {
      highlightCurrentPolygon();
      currentPolygonAreaText =
          "Area of the current polygon is: $polygonArea m²";
      showPolygonInfo = true;
    });
  }

  void highlightCurrentPolygon() {
    Map<PolygonId, Polygon> newPolygonList = HashMap<PolygonId, Polygon>();
    for (Polygon eachPolygon in polygon.values) {
      if (eachPolygon.polygonId == currentPolygon.polygonId) {
        //This needs to be highlighted
        newPolygonList[eachPolygon.polygonId] =
            (eachPolygon.copyWith(fillColorParam: selectedPolygonFillColor));
      } else {
        newPolygonList[eachPolygon.polygonId] =
            (eachPolygon.copyWith(fillColorParam: polygonFillColor));
      }
    }
    polygon.clear();
    polygon.addAll(newPolygonList);
  }

  num getAreaOfPolygon(Polygon polygon) {
    var polygonLatLng = polygon.points;
    var polygonGis = [];
    for (LatLng latLng in polygonLatLng) {
      polygonGis.add([latLng.longitude, latLng.latitude]);
    }
    var world = {
      'type': 'Polygon',
      'coordinates': [polygonGis]
    };
    return area(world);
  }

  void onMarkerTapped() {
    if (polyLatLng.length > 2) {
      setState(() {
        PolygonId pId =
            PolygonId(polyLatLng.toList(growable: false).hashCode.toString());
        polygon[pId] = Polygon(
            polygonId: pId,
            points: polyLatLng.toList(growable: false),
            fillColor: polygonFillColor,
            strokeWidth: 3,
            strokeColor: Colors.black);
        markers.clear();
      });
      polyLatLng.clear();
    }
  }

  void resetButtonClicked() {
    setState(() {
      //Below implementation is done because
      //removing currentPolygon from the existing polygon list was not working
      Map<PolygonId, Polygon> newPolygonMap = HashMap<PolygonId, Polygon>();
      for (Polygon eachPolygon in polygon.values) {
        if (eachPolygon.polygonId != currentPolygon.polygonId) {
          newPolygonMap[eachPolygon.polygonId] = eachPolygon;
        }
      }
      polygon.clear();
      polygon.addAll(newPolygonMap);
      currentPolygon = null;
      showPolygonInfo = false;
    });
  }
}
