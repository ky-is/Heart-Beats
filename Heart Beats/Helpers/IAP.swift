//
//  Store.swift
//  Heart Beats
//
//  Created by Kyle Coburn on 7/20/18.
//  Copyright © 2018 Kyle Coburn. All rights reserved.
//

import Foundation

import StoreKit

final class IAP: NSObject {

	static let shared = IAP()

	static var unlocked = UserDefaults.standard.integer(forKey: "U") == 9001

	private var productsRequest: SKProductsRequest?
	private var product: SKProduct?

	private var purchaseCallback: ((Bool) -> ())?

	override init() {
		super.init()

		SKPaymentQueue.default().add(self)

		if !IAP.unlocked {
			requestProducts()
		}
	}

	func start() {}

	func requestProducts() {
		productsRequest?.cancel()

		let request = SKProductsRequest(productIdentifiers: [ "is.ky.HeartBeats.Unlocked" ])
		productsRequest = request
		request.delegate = self
		request.start()
	}

	func purchase(from controller: UIViewController, callback: ((Bool) -> ())? = nil) {
		guard SKPaymentQueue.canMakePayments() else {
			return controller.alert("Purchases Unavailable", message: "Please authorize your device to make in-app purchases and try again, thanks!", cancel: "OK")
		}
		guard let product = product else {
			return controller.alert("Purchases Unavailable", message: "Unable to load purchases. Please check your connection and try again", cancel: "OK")
		}
		purchaseCallback = callback
		let payment = SKPayment(product: product)
		SKPaymentQueue.default().add(payment)
	}

	func restore(callback: ((Bool) -> ())? = nil) {
		purchaseCallback = callback
		SKPaymentQueue.default().restoreCompletedTransactions()
	}

}

extension IAP: SKProductsRequestDelegate {

	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		for responseProduct in response.products {
			product = responseProduct
		}
		if !IAP.unlocked && Zephyr.shared.userDefaults.purchased {
			restore()
		}
	}

	func request(_ request: SKRequest, didFailWithError error: Error) {
		print("Unable to retrieve products", error.localizedDescription)
	}

}

extension IAP: SKPaymentTransactionObserver {

	private func mainController() -> UIViewController {
		return UIApplication.shared.keyWindow!.rootViewController!
	}

	private func validate(_ transaction: SKPaymentTransaction) {
		guard let receiptURL = Bundle.main.appStoreReceiptURL else {
			return mainController().alert("Receipt not available", message: "Please try your purchase again.", cancel: "OK")
		}
		guard let receipt = try? Data(contentsOf: receiptURL) else {
			return mainController().alert("Invalid receipt", message: "Please try your purchase again.", cancel: "OK")
		}
		let receiptString = receipt.base64EncodedString()

		var request = URLRequest(url: URL(string: "https://ky.is/scripts/validate_ios.php")!)
		request.httpMethod = "POST"
		request.httpBody = receiptString.data(using: .ascii)
		let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
			DispatchQueue.main.async {
				guard error == nil else {
					return self.mainController().alert("Validation error", message: error!.localizedDescription, cancel: "OK")
				}
				guard let body = String(data: data!, encoding: .utf8) else {
					return self.mainController().alert("Invalid server response", message: "Please try again later.", cancel: "OK")
				}
				guard body == "0" else {
					return self.mainController().alert("Invalid receipt", message: "\(body). Please try again later.", cancel: "OK")
				}
				UserDefaults.standard.set(9001, forKey: "U")
				IAP.unlocked = true
				Zephyr.shared.userDefaults.purchased = true
				self.finish(transaction, success: true)
			}
		}
		task.resume()
	}

	private func finish(_ transaction: SKPaymentTransaction, success: Bool) {
		SKPaymentQueue.default().finishTransaction(transaction)
		purchaseCallback?(success)
		purchaseCallback = nil
	}

	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			switch transaction.transactionState {
			case .purchased:
				validate(transaction)
			case .failed:
				if let error = transaction.error as NSError?, error.code == SKError.paymentCancelled.rawValue {
					continue
				}
				finish(transaction, success: false)
				mainController().alert("Unable to purchase", message: transaction.error?.localizedDescription ?? "", cancel: "OK")
			case .restored:
				validate(transaction)
			case .purchasing:
				continue
			case .deferred:
				continue
			}
			purchaseCallback = nil
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		UIApplication.shared.keyWindow?.rootViewController?.alert("Unable to restore purchases", message: error.localizedDescription, cancel: "OK")
	}

}
