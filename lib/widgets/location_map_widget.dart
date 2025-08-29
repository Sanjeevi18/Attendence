import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final double height;
  final bool showOpenInMapsButton;

  const LocationMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.height = 200.0,
    this.showOpenInMapsButton = true,
  });

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  GoogleMapController? _mapController;
  late LatLng _currentLocation;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentLocation = LatLng(widget.latitude, widget.longitude);
    _createMarker();
  }

  void _createMarker() {
    _markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Your Location',
          snippet: widget.address ?? 'Current position',
        ),
      ),
    };
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Animate to current location after map is created
    Future.delayed(const Duration(milliseconds: 500), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 16.0),
      );
    });
  }

  Future<void> _openInGoogleMaps() async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 16.0,
              ),
              markers: _markers,
              mapType: MapType.normal,
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              buildingsEnabled: true,
              trafficEnabled: false,
            ),
            if (widget.showOpenInMapsButton)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _openInGoogleMaps,
                    icon: const Icon(
                      Icons.open_in_new,
                      color: Colors.blue,
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            if (widget.address != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.address!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Fallback widget for when Google Maps is not available or location is null
class LocationMapFallback extends StatelessWidget {
  final String? address;
  final double height;
  final VoidCallback? onRefresh;

  const LocationMapFallback({
    super.key,
    this.address,
    this.height = 200.0,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Location not available',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (address != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                address!,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (onRefresh != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
