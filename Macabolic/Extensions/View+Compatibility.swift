import SwiftUI

extension View {
    @ViewBuilder
    func macabolicFormStyle() -> some View {
        if #available(macOS 13.0, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }
}
