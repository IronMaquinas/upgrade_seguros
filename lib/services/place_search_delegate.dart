import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

class PlaceSearchDelegate extends SearchDelegate<Place?> {
  final FlutterGooglePlacesSdk places;

  PlaceSearchDelegate(this.places);

  @override
  String get searchFieldLabel => "Digite um endereço";

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          )
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<FindAutocompletePredictionsResponse>(
      future: places.findAutocompletePredictions(
        query,
        countries: ['br'],
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.predictions.isEmpty) {
          return const Center(child: Text("Nenhum resultado"));
        }

        final predictions = snapshot.data!.predictions;

        return ListView.builder(
          itemCount: predictions.length,
          itemBuilder: (context, index) {
            final p = predictions[index];
            return ListTile(
              title: Text(p.fullText),
              onTap: () async {
                try {
                  final details = await places.fetchPlace(
                    p.placeId,
                    fields: [
                      PlaceField.Address,
                      PlaceField.Name,
                      PlaceField.Location, // CORRETO
                    ],
                  );

                  final place = details.place;
                  /*
                  if (place != null) {
                    debugPrint("📍 Place selecionado: ${place.address ?? place.name}");
                    final location = place.LatLng;
                    if (location != null) {
                      debugPrint(
                        "🌐 Lat: ${location.lat}, Lng: ${location.lng}"
                      );
                    }
                  }
*/
                  close(context, place);
                } catch (e) {
                  debugPrint("❌ Erro ao buscar detalhes do place: $e");
                  close(context, null);
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text("Digite para buscar..."));
    return buildResults(context);
  }
}