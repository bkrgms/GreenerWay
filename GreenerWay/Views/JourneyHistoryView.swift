import SwiftUI
import Charts

struct JourneyHistoryView: View {
    @StateObject private var vm = JourneyViewModel()
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Carbon Footprint History")
                    .font(.title2).bold()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Weekly").font(.caption).foregroundColor(.gray)
                        Text("\(Int(vm.weeklyTotal)) kg")
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Monthly").font(.caption).foregroundColor(.gray)
                        Text("\(Int(vm.monthlyTotal)) kg")
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Total").font(.caption).foregroundColor(.gray)
                        Text("\(Int(vm.allTimeTotal)) kg")
                    }
                }
            }
            .padding()
            
            Chart {
                ForEach(vm.journeys) { j in
                    BarMark(
                        x: .value("Day", j.date, unit: .day),
                        y: .value("Emission", j.emissionKg)
                    )
                }
            }
            .frame(height: 220)
            .padding(.horizontal)
            
            Spacer()
        }
        .navigationTitle("History")
        .task { await vm.loadJourneys() }
    }
}

