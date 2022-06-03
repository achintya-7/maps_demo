// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:maps_demo/map_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? _googleMapController;
  static const LatLng _center = LatLng(28.61992743538245, 77.20905101733563);

  List<AutocompletePrediction> predictions = [];
  final _startingLocationController = TextEditingController();
  final _endingLocationController = TextEditingController();
  DetailsResult? startPosition;
  DetailsResult? endPosition;
  late GooglePlace googlePlace;
  Timer? debounce;
  late FocusNode startFocusNode;
  late FocusNode endFocusNode;

  Marker? _origin;
  Marker? _destination;
  List<Marker> markers = [];
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  Polyline? polyline;
  List<Polyline> polylineValues = [];

  @override
  void initState() {
    super.initState();
    googlePlace = GooglePlace(dotenv.env['API_key']!);
    startFocusNode = FocusNode();
    endFocusNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();
    startFocusNode.dispose();
    endFocusNode.dispose();
    _googleMapController!.dispose();
  }

  autoComplete(String value) async {
    var result = await googlePlace.autocomplete.get(value);
    if (result != null && result.predictions != null) {
      setState(() {
        predictions = result.predictions!;
      });
    }
  }

  _addPolyLine() {
    PolylineId id = const PolylineId('poly');
    polyline = Polyline(
        polylineId: id,
        color: Colors.purple,
        points: polylineCoordinates,
        width: 3);
    polylines[id] = polyline!;
    setState(() {});
  }

  getPolyLine() async {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      dotenv.env['API_key']!,
      PointLatLng(startPosition!.geometry!.location!.lat!,
          startPosition!.geometry!.location!.lng!),
      PointLatLng(endPosition!.geometry!.location!.lat!,
          endPosition!.geometry!.location!.lng!),
    );
    if (result.points.isNotEmpty) {
      for (var points in result.points) {
        polylineCoordinates.add(LatLng(points.latitude, points.longitude));
      }
      _addPolyLine();
    }
  }

  drawPolyLine(DetailsResult start, DetailsResult end) async {
    polylines.clear();
    markers.clear();
    polylineCoordinates.clear();
    polylineValues.clear();

    _origin = Marker(
        markerId: const MarkerId('Origin'),
        infoWindow: const InfoWindow(title: 'Origin'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        position: LatLng(
            start.geometry!.location!.lat!, start.geometry!.location!.lng!));
    markers.add(_origin!);

    _destination = Marker(
        markerId: const MarkerId('Destination'),
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position:
            LatLng(end.geometry!.location!.lat!, end.geometry!.location!.lng!));
    markers.add(_destination!);

    await getPolyLine();

    _googleMapController!.moveCamera(CameraUpdate.newLatLngBounds(
        MapUtils.boundsFromLatLngList(
            markers.map((loc) => loc.position).toList()),
        1));

    polylineValues = List<Polyline>.of(polylines.values);

    setState(() {
      print('Length : ' + polylineValues[0].toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maps Demo'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _controllerGoogleMap.complete(controller);
              _googleMapController = controller;
            },
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 11.0,
            ),
            markers: {
              if (_origin != null) _origin!,
              if (_destination != null) _destination!
            },
            polylines: {if (polylineValues.isNotEmpty) polylineValues[0]},
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                  child: TextField(
                    focusNode: startFocusNode,
                    controller: _startingLocationController,
                    decoration: InputDecoration(
                        suffixIcon: _startingLocationController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    predictions = [];
                                    _startingLocationController.clear();
                                  });
                                },
                                icon: const Icon(Icons.clear_outlined))
                            : null,
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(CupertinoIcons.location_solid),
                        hintText: 'Starting Location'),
                    onChanged: (value) {
                      if (debounce?.isActive ?? false) debounce!.cancel();
                      debounce = Timer(const Duration(microseconds: 1000), () {
                        if (value.isNotEmpty) {
                          autoComplete(value);
                        } else {
                          //clear the search
                          setState(() {
                            predictions = [];
                            startPosition = null;
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                  child: TextField(
                    focusNode: endFocusNode,
                    controller: _endingLocationController,
                    decoration: InputDecoration(
                        suffixIcon: _endingLocationController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    predictions = [];
                                    _endingLocationController.clear();
                                  });
                                },
                                icon: const Icon(Icons.clear_outlined))
                            : null,
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(CupertinoIcons.location_solid),
                        hintText: 'Ending Location'),
                    onChanged: (value) {
                      if (debounce?.isActive ?? false) debounce!.cancel();
                      debounce = Timer(const Duration(microseconds: 1000), () {
                        if (value.isNotEmpty) {
                          autoComplete(value);
                        } else {
                          //clear the search
                          setState(() {
                            predictions = [];
                            endPosition = null;
                          });
                        }
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: predictions.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ElevatedButton(
                          onPressed: () async {
                            final placeId = predictions[index].placeId!;
                            final details =
                                await googlePlace.details.get(placeId);

                            if (details != null &&
                                details.result != null &&
                                mounted) {
                              if (startFocusNode.hasFocus) {
                                setState(() {
                                  startPosition = details.result;
                                  _startingLocationController.text =
                                      details.result!.name!.toString();
                                  predictions = [];
                                });
                              } else {
                                setState(() {
                                  endPosition = details.result;
                                  _endingLocationController.text =
                                      details.result!.name!.toString();
                                  predictions = [];
                                });
                              }
                              FocusManager.instance.primaryFocus?.unfocus();
                            }
                          },
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.pin_drop),
                            ),
                            isThreeLine: false,
                            title: Text(
                              predictions[index].description.toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                  onPressed: () {
                    if (startPosition != null && endPosition != null) {
                      drawPolyLine(startPosition!, endPosition!);
                    }
                  },
                  child: const Text("Search")),
            ),
          )
        ],
      ),
    );
  }
}
