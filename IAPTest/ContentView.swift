import SwiftUI
import StoreKit

struct ContentView: View {
    @ObservedObject var helper = StoreKitHelper.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IAP SK1 Sandbox Test").font(.title2).bold()
            Group {
                Text("State: \(helper.state)")
                Text("Product: \(helper.productLine)")
                Text("Receipt bytes: \(helper.receiptLen)")
            }.font(.caption.monospaced()).foregroundColor(.secondary)
            HStack {
                Button("Fetch Product") { helper.fetchProduct() }
                    .buttonStyle(.borderedProminent)
                Button("Buy") { helper.buy() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!helper.canBuy)
                Button("Refresh Receipt") { helper.refreshReceipt() }
                    .buttonStyle(.bordered)
            }
            Button("Direct Buy (skip Fetch)") { helper.directBuy() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            Button("Copy Base64 Receipt") { UIPasteboard.general.string = helper.receiptB64 }
                .buttonStyle(.bordered)
                .disabled(helper.receiptB64.isEmpty)
            Divider()
            Text("Receipt (base64) — long press to share").font(.caption).bold()
            ScrollView {
                Text(helper.receiptB64.isEmpty ? "(empty)" : helper.receiptB64)
                    .font(.system(size: 9, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }.frame(maxHeight: .infinity)
        }
        .padding()
    }
}
