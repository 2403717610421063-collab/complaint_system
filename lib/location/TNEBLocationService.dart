import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart'; // Standard Position comes from here
import 'package:turf/turf.dart' as turf;

class TNEBLocationService {

  /// Find the TNEB boundary for a point, restricted to **Coimbatore Urban**.
  ///
  /// This does **not** modify the underlying GeoJSON file – it just filters
  /// the in‑memory feature collection at runtime.
  ///
  /// Current rule (per your requirement "Urban division only"):
  ///   - Only features whose `division_name`/`division_n` resolves to `URBAN`
  ///     are considered.
  Map<String, dynamic>? findBoundary(
    double lat,
    double lng,
    String geoJsonString,
  ) {
    final Map<String, dynamic> data = json.decode(geoJsonString);
    final featureCollection = turf.FeatureCollection.fromJson(data);

    final userPosition = turf.Position(lng, lat);

    for (final feature in featureCollection.features) {
      final properties = feature.properties ?? <String, dynamic>{};

      // Only work with features that belong to the URBAN division
      // (e.g. PEELAMEDU TOWN, RS PURAM, etc.).
      final divisionName =
          (properties['division_name'] ?? properties['division_n'] ?? '')
              .toString()
              .trim()
              .toUpperCase();

      if (divisionName != 'URBAN') {
        continue;
      }

      final geom = feature.geometry;
      if (geom == null) continue;

      if (turf.booleanPointInPolygon(userPosition, geom)) {
        return properties;
      }
    }
    return null;
  }

  /// Convenience: locate the current device in the Urban TNEB map and
  /// return the raw GeoJSON properties for that Urban polygon.
  Future<Map<String, dynamic>?> checkMySection() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final geoData = await rootBundle.loadString('assets/TNEB_Master_Data.json');

      return findBoundary(
        position.latitude,
        position.longitude,
        geoData,
      );
    } catch (e) {
      print("Error finding boundary: $e");
      return null;
    }
  }

  /// Map a GeoJSON properties map to the AE / AEE / EE hierarchy
  /// using the following convention:
  ///  - Section → AE
  ///  - Subdivision → AEE
  ///  - Division → EE
  ///
  /// Returns `null` if the required fields are missing.
  Map<String, String>? extractHierarchy(Map<String, dynamic>? properties) {
    if (properties == null) return null;

    final section = (properties['section_name'] ?? properties['section_na'] ?? '')
        .toString()
        .trim();
    final subdivision =
        (properties['subdivision_name'] ?? properties['subdivisio'] ?? '')
            .toString()
            .trim();
    final division =
        (properties['division_name'] ?? properties['division_n'] ?? '')
            .toString()
            .trim();
    final section_id =
    (properties['section_id'] ?? properties['section_co'] ?? '')
        .toString()
        .trim();

    if (section.isEmpty && subdivision.isEmpty && division.isEmpty) {
      return null;
    }

    return <String, String>{
      'section_id':section_id,
      'aeSection': section,
      'aeeSubdivision': subdivision,
      'eeDivision': division,
      'aeCode': (properties['ssmaecode'] ?? '').toString().trim(),
      'office_lat':properties['office_lat'],
      'office_lon':properties['office_lon']
    };
  }

  /// One‑shot helper: get AE/AEE/EE hierarchy for the **current** location.
  Future<Map<String, String>?> getCurrentHierarchy() async {
    final props = await checkMySection();
    return extractHierarchy(props);
  }

  /// One‑shot helper: get AE/AEE/EE hierarchy for an arbitrary point
  /// (latitude, longitude) using the Urban‑only filter.
  Future<Map<String, String>?> getHierarchyForPoint(
    double latitude,
    double longitude,
  ) async {
    try {
      final geoData = await rootBundle.loadString('assets/TNEB_Master_Data.json');
      final props = findBoundary(latitude, longitude, geoData);
      return extractHierarchy(props);
    } catch (e) {
      print('Error computing hierarchy for point: $e');
      return null;
    }
  }
}