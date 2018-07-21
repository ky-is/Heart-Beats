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
		if !UserDefaults.standard.purchased {
			restore()
		}
	}

	func request(_ request: SKRequest, didFailWithError error: Error) {
		print("Unable to retrieve products", error.localizedDescription)
	}

}

extension IAP: SKPaymentTransactionObserver {

	private func finishTransaction(_ transaction: SKPaymentTransaction, success: Bool) {
		SKPaymentQueue.default().finishTransaction(transaction)
		if success {
			UserDefaults.standard.set(9001, forKey: "U")
			IAP.unlocked = true
			UserDefaults.standard.purchased = true
		}
		purchaseCallback?(success)
		purchaseCallback = nil
	}

	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			let title: String, message: String
			switch transaction.transactionState {
			case .purchased:
				title = "Purchase complete!"
				message = ""
				finishTransaction(transaction, success: true)
			case .failed:
				if let error = transaction.error as NSError?, error.code == SKError.paymentCancelled.rawValue {
					continue
				}
				title = "Unable to purchase"
				message = transaction.error?.localizedDescription ?? ""
				finishTransaction(transaction, success: false)
			case .restored:
				title = "Purchase restored!"
				message = ""
				finishTransaction(transaction, success: true)
			case .purchasing:
				continue
			case .deferred:
				continue
			}
			purchaseCallback = nil
			UIApplication.shared.keyWindow?.rootViewController?.alert(title, message: message, cancel: "OK")
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		UIApplication.shared.keyWindow?.rootViewController?.alert("Unable to restore purchases", message: error.localizedDescription, cancel: "OK")
	}

}
