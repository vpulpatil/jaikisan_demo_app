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

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
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
    PermissionStatus checkStatus = await LocationPermissions()
        .checkPermissionStatus(
            level: LocationPermissionLevel.locationWhenInUse);

    if (checkStatus == PermissionStatus.granted) {
      //Location Permission is granted

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
    } else {
      //Location Permission is not granted
      PermissionStatus permission =
          await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) {
        //Location Runtime permission is granted
        bool isLocationEnabled = await Geolocator().isLocationServiceEnabled();
        if (isLocationEnabled) {
          //GPS is enabled on device
          print("gps is enabled");
          Position position = await Geolocator().getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            locationPermissionLevel: GeolocationPermission.locationWhenInUse,
          );
          setLocationEnabledAction(position.latitude, position.longitude);
        } else {
          //GPS is not enabled on the device
          print("gps is not enabled");
        }
      }
    }
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

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
