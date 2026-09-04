import SwiftUI

extension View {
    @ViewBuilder
    func ifLet<Value>(_ value: Value?, transform: (Self, Value) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}