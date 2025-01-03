//
//  ContentView.swift
//  CountryClaude
//
//  Created by Tatiana Kornilova on 01.11.2024.
//


import SwiftUI

// Models
struct Country: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    let flag: String
    var population: Int?
    var gdp: Double?
    let iso2Code: String
}

// Exact World Bank API response format
//----- Root
struct WorldBankResponse: Decodable {
    let metadata: WorldBankMetadata
    let countries: [WorldBankCountry]
    
   init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        metadata = try container.decode(WorldBankMetadata.self)
        countries = try container.decode([WorldBankCountry].self)
    }
}

//------- Meta
struct WorldBankMetadata: Decodable {
    let page: Int
    let pages: Int
    let perPage: String
    let total: Int
    
    enum CodingKeys: String, CodingKey {
            case page
            case pages
            case perPage = "per_page"
            case total
        }
}

//------- Country
struct WorldBankCountry: Decodable {
    let id: String
    let iso2Code: String
    let name: String
    let region: Region
    let adminregion: AdminRegion
    let incomeLevel: IncomeLevel
    let lendingType: LendingType
    let capitalCity: String
    let longitude: String
    let latitude: String
    
    struct Region: Decodable {
        let id: String
        let iso2code: String
        let value: String
    }
    
    struct AdminRegion: Decodable {
        let id: String
        let iso2code: String
        let value: String
    }
    
    struct IncomeLevel: Decodable {
        let id: String
        let iso2code: String
        let value: String
    }
    
    struct LendingType: Decodable {
        let id: String
        let iso2code: String
        let value: String
    }
}
//----- Root
struct IndicatorResponse: Decodable {
    let metadata: IndicatorMetadata
    let data: [IndicatorData]
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        metadata = try container.decode(IndicatorMetadata.self)
        data = try container.decode([IndicatorData].self)
    }
}

//----- Meta
struct IndicatorMetadata: Decodable {
    let page: Int
    let pages: Int
    let per_page: Int
    let total: Int
}

//----- Indicator
struct IndicatorData: Decodable {
    let value: Double?
    let date: String
}

// Version 2 working for Swift
@MainActor
@Observable
class CountriesViewModel {
    var countriesApp: [Country] = []
    var isLoading = false
    var errorMessage: String?
    
    private let baseURL = "https://api.worldbank.org/v2"
    
    private struct CountryDetail {
           let iso2Code: String
           let population: Int?
           let gdp: Double?
    }
    
    // Main load function marked as async
   func loadCountries() async {
        isLoading = true
        errorMessage = nil
        let urlString = "\(baseURL)/country?format=json&per_page=300"
        guard let url = URL(string: urlString) else {
                errorMessage = "Invalid URL"
                isLoading = false
                return
        }
       
       let filteredCountries = await fetchCountries(url: url)
       // Update UI on main actor
       if let countries = filteredCountries {
           countriesApp = countries
           isLoading = false
           
           // Fetch and update with details
            let details = await fetchCountryDetails(for: countries)
            updateCountries(with: details)
       } else {
           print("Error: Failed to load countries")
           errorMessage = "Failed to load countries"
           isLoading = false
       }
    }
    
    // Helper method for fetching countries
    private nonisolated func fetchCountries(url: URL) async ->  [Country]? {
        do {
            // Use structured concurrency with async/await
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(WorldBankResponse.self, from: data)
            
            let filteredCountries = response.countries
                .filter { $0.region.value != "Aggregates" }
                .map { countryData in
                    Country(
                        name: countryData.name,
                        category: countryData.region.value,
                        flag: flagEmoji(from: countryData.iso2Code),
                        population: nil,
                        gdp: nil,
                        iso2Code: countryData.iso2Code
                    )
                }
            return filteredCountries
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper method for fetching additional data
    // Now returns collected data instead of updating state directly
    private nonisolated func fetchCountryDetails(for countries: [Country]) async -> [CountryDetail] {
           await withTaskGroup(of: CountryDetail?.self) { group in
               for country in countries {
                   let iso2Code = country.iso2Code
                    group.addTask {
                        let (population, gdp ) = await (self.fetchPopulation(for: iso2Code), self.fetchGDP(for: iso2Code))
                           return CountryDetail(
                               iso2Code: iso2Code,
                               population: population,
                               gdp: gdp
                           )
                   }
               }
               
               // Collect results
               var details: [CountryDetail] = []
               for await detail in group {
                   if let detail = detail {
                       details.append(detail)
                   }
               }
               return details
           }
       }
 
       private func updateCountries(with details: [CountryDetail]) {
           for detail in details {
               if let index = countriesApp.firstIndex(where: { $0.iso2Code == detail.iso2Code }) {
                   countriesApp[index].population = detail.population
                   countriesApp[index].gdp = detail.gdp
               }
           }
       }
   
    // Updated to return population as an optional integer
    private nonisolated func fetchPopulation(for  iso2Code: String) async -> Int? {
        let indicator = "SP.POP.TOTL"
        let urlString = "\(baseURL)/country/\(iso2Code)/indicator/\(indicator)?format=json&per_page=1&date=2023"
       
        guard let url = URL(string: urlString) else {
            print("Invalid URL for population data")
            return  nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(IndicatorResponse.self, from: data)
           let fetchPopulation = response.data.first?.value.flatMap { Int($0) }
           return fetchPopulation
        } catch {
            print("Failed to fetch population for \(iso2Code): \(error)")
            return nil
        }
    }
    
    // Updated to return GDP as an optional double
    private nonisolated func fetchGDP(for  iso2Code: String) async -> Double? {
        let indicator = "NY.GDP.MKTP.CD"
        let urlString = "\(baseURL)/country/\(iso2Code)/indicator/\(indicator)?format=json&per_page=1&date=2022"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL for GDP data")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(IndicatorResponse.self, from: data)
            
         //   return response.data.first?.value
            let fetchedGDP = response.data.first?.value
            return fetchedGDP
        } catch {
            print("Failed to fetch GDP for \(iso2Code): \(error)")
            return nil
        }
    }
    
    private nonisolated func flagEmoji(from iso2Code: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in iso2Code.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                flag.append(String(flagScalar))
            }
        }
        return flag.isEmpty ? "🏳️" : flag
    }
    
    var categories: [String] {
        Array(Set(countriesApp.map { $0.category })).sorted()
     }
     
     func countries(in category: String) -> [Country] {
         countriesApp.filter { $0.category == category }
     }
}


struct ContentView: View {
    @State private var viewModel = CountriesViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading countries...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(message: errorMessage, retryAction: {
                        Task {
                            await viewModel.loadCountries()
                        }
                    })
                } else {
                    CountryListView(viewModel: viewModel)
                }
            }
            .navigationTitle("World Countries")
        }
        .task{
           await viewModel.loadCountries()
        }
    }
}

// Rest of the view code remains the same...
struct CountryListView: View {
  var viewModel: CountriesViewModel
    
    var body: some View {
       List {
            ForEach(viewModel.categories, id: \.self) { category in
                Section(header: Text(category)) {
                    ForEach(viewModel.countries(in: category)) { country in
                        NavigationLink(destination: CountryDetailView(country: country)) {
                            CountryRowView(country: country)
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadCountries()
        }
    }
}

struct CountryRowView: View {
    let country: Country
    
    var body: some View {
        HStack {
            Text(country.flag)
                .font(.title2)
            Text(country.name)
                .font(.body)
            Text(country.iso2Code)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

struct CountryDetailView: View {
    let country: Country
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
               Text(country.flag)
                   .font(.system(size: 100))
                
                Text(country.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 15) {
                    DetailRow(title: "Region", value: country.category)
                    
                   if let population = country.population {
                        DetailRow(
                            title: "Population",
                            value: formatNumber(population)
                        )
                    }
                    
                   if let gdp = country.gdp {
                        DetailRow(
                            title: "GDP (USD)",
                            value: formatCurrency(gdp)
                        )
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .padding()
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    private func formatCurrency(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Error")
                .font(.title)
                .foregroundColor(.red)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Retry", action: retryAction)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}
// Views remain the same as in the previous version
// (ContentView, CountryListView, CountryRowView, CountryDetailView, DetailRow, ErrorView)
#Preview {
    ContentView()
}
