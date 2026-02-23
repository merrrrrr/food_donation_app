import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _lastSelectedLocation = const LatLng(3.1390, 101.6869); // Default: KL
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    if (widget.initialLocation != null) {
      _lastSelectedLocation = widget.initialLocation!;
      setState(() => _isLoading = false);
    } else {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        setState(() {
          _lastSelectedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      } catch (e) {
        // Fallback to default if current location fails
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _lastSelectedLocation = position.target;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: () => Navigator.of(context).pop(_lastSelectedLocation),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!_isLoading)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _lastSelectedLocation,
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onCameraMove: _onCameraMove,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Crosshair / Marker in Center
          if (!_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 35),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ),

          // Action Buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'myLocation',
                  onPressed: () async {
                    try {
                      final pos = await Geolocator.getCurrentPosition();
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(pos.latitude, pos.longitude),
                        ),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not get current location'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Icon(Icons.my_location_rounded),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Confirm This Location'),
                    onPressed: () =>
                        Navigator.of(context).pop(_lastSelectedLocation),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
