import SwiftUI

struct ContentView: View {
    @State private var temperature = 67
    var body: some View {
        VStack (spacing: 20){
            Text("ThermalShift")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Intel Mac")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text("\(temperature)°C")
                .font(.system(size: 64, weight: .bold))
            
            Text("CPU Temperature")
                .foregroundStyle(.secondary)
            
            Button("Simulate Temperature") {
                            temperature += 1
                        }
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
}
