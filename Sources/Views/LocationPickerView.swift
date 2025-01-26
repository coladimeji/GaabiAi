import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var location: TaskLocation?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""
    @State private var selectedRadius: Double = 100
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText, onSubmit: {
                    Task {
                        await viewModel.searchLocations(query: searchText)
                    }
                })
                .padding()
                
                // Map
                Map(coordinateRegion: $viewModel.region, showsUserLocation: true, annotationItems: viewModel.searchResults) { result in
                    MapAnnotation(coordinate: result.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(result == viewModel.selectedResult ? .red : .blue)
                            .onTapGesture {
                                viewModel.selectedResult = result
                            }
                    }
                }
                .overlay(alignment: .center) {
                    if viewModel.isSearching {
                        ProgressView()
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
                
                // Search Results & Settings
                List {
                    if !viewModel.searchResults.isEmpty {
                        Section("Search Results") {
                            ForEach(viewModel.searchResults) { result in
                                Button {
                                    viewModel.selectedResult = result
                                    viewModel.region.center = result.coordinate
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(result.name)
                                            .font(.headline)
                                        Text(result.address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    if let selected = viewModel.selectedResult {
                        Section("Selected Location") {
                            VStack(alignment: .leading) {
                                Text(selected.name)
                                    .font(.headline)
                                Text(selected.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Geofencing Radius")
                                Slider(
                                    value: $selectedRadius,
                                    in: 50...1000,
                                    step: 50
                                ) {
                                    Text("Radius")
                                } minimumValueLabel: {
                                    Text("50m")
                                } maximumValueLabel: {
                                    Text("1km")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let selected = viewModel.selectedResult {
                            location = TaskLocation(
                                coordinate: selected.coordinate,
                                address: selected.address,
                                radius: selectedRadius
                            )
                        }
                        dismiss()
                    }
                    .disabled(viewModel.selectedResult == nil)
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSubmit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search location", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .onSubmit(onSubmit)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

class LocationPickerViewModel: ObservableObject {
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3361, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var searchResults: [LocationResult] = []
    @Published var selectedResult: LocationResult?
    @Published var isSearching = false
    
    private let searchCompleter = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()
    
    init() {
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.requestWhenInUseAuthorization()
        
        if let location = locationManager.location {
            region.center = location.coordinate
        }
    }
    
    @MainActor
    func searchLocations(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            searchResults = response.mapItems.map { item in
                LocationResult(
                    id: UUID(),
                    name: item.name ?? "",
                    address: item.address,
                    coordinate: item.placemark.coordinate
                )
            }
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }
    }
}

struct LocationResult: Identifiable, Equatable {
    let id: UUID
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: LocationResult, rhs: LocationResult) -> Bool {
        lhs.id == rhs.id
    }
}

extension MKPlacemark {
    var address: String {
        [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            postalCode,
            country
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
} 