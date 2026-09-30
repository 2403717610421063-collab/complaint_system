import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:complaint_system/location/TNEBLocationService.dart';
class TNEBBoundaryTestPage extends StatefulWidget {
  const TNEBBoundaryTestPage({super.key});

  @override
  _TNEBBoundaryTestPageState createState() => _TNEBBoundaryTestPageState();
}

class _TNEBBoundaryTestPageState extends State<TNEBBoundaryTestPage> {
  String _status = "Press the button to find your section";
  Map<String, dynamic>? _resultData;
  bool _isLoading = false;

  Future<void> _handleLocationCheck() async {
    setState(() {
      _isLoading = true;
      _status = "Fetching location...";
    });

    try {
      // 1. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 2. Get Position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      setState(() => _status = "Scanning TNEB Boundaries...");

      // 3. Load File
      String geoData = await rootBundle.loadString('assets/TNEB_Master_Data.json');

      // 4. Run your Service
      final result = TNEBLocationService().findBoundary(
        position.latitude,
        position.longitude,
        geoData,
      );

      setState(() {
        _isLoading = false;
        if (result != null) {
          _resultData = result;
          _status = "Match Found!";
        } else {
          _resultData = null;
          _status = "Location is outside mapped TNEB areas.";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("TNEB Boundary Finder")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.location_on, size: 50, color: Colors.blue),
            SizedBox(height: 20),
            Text(_status, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

            if (_isLoading) ...[
              SizedBox(height: 20),
              Center(child: CircularProgressIndicator()),
            ],

            if (_resultData != null) ...[
              SizedBox(height: 20),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      _infoRow("Section", _resultData!['section_na']),
                      _infoRow("Code", _resultData!['ssmaecode']),
                      _infoRow("Subdiv", _resultData!['subdivisio']),
                      _infoRow("Circle", _resultData!['circle_nam']),
                    ],
                  ),
                ),
              ),
            ],

            Spacer(),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleLocationCheck,
              icon: Icon(Icons.my_location),
              label: Text("Find My Section"),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label:", style: TextStyle(fontWeight: FontWeight.w600)),
          Text("${value ?? 'N/A'}"),
        ],
      ),
    );
  }
}