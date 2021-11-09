// Copyright (c) 2014-present, Facebook, Inc. All rights reserved.
//
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Facebook.
//
// As with any software that integrates with the Facebook platform, your use of
// this software is subject to the Facebook Developer Principles and Policies
// [http://developers.facebook.com/policy/]. This copyright notice shall be
// included in all copies or substantial portions of the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import XCTest

@available(iOS 12.2, *)
class PaymentProductRequestorTests: XCTestCase { // swiftlint:disable:this type_body_length

  var transaction = TestPaymentTransaction(state: .deferred)
  var requestFactory = TestProductsRequestFactory()
  let settings = TestSettings()
  let eventLogger = TestEventLogger()
  let store = UserDefaultsSpy()
  let loggerFactory = TestLoggerFactory()
  lazy var tempURL = URL(
    fileURLWithPath: NSTemporaryDirectory(),
    isDirectory: true
  ).appendingPathComponent(name)
  let receiptProvider = TestAppStoreReceiptProvider()
  let sampleDiscount = SKPaymentDiscount(
    identifier: "identifier",
    keyIdentifier: "key",
    nonce: UUID(),
    signature: "signature",
    timestamp: 1
  )

  lazy var requestor = PaymentProductRequestor(
    transaction: transaction,
    settings: settings,
    eventLogger: eventLogger,
    gateKeeperManager: TestGateKeeperManager.self,
    store: store,
    loggerFactory: loggerFactory,
    productsRequestFactory: requestFactory,
    appStoreReceiptProvider: receiptProvider
  )

  enum Keys {
    static let receiptData = "receipt_data"
    static let implicitlyLogged = "_implicitlyLogged"
    static let passThroughParameter = "some_parameter"
    static let originalTransactionsPersistence = "com.facebook.appevents.PaymentObserver.originalTransaction"
  }

  enum Values {
    static let appName = "foo"
    static let passThroughValue = "bar"
    static let inApp = "inapp"
    static let subscription = "subs"
    static let oneDaySubscriptionPeriod = "P1D"
    static let willSubscribeEventName = "SubscriptionInitiatedCheckout"
    static let didSubscribeEventName = "Subscribe"
    static let startTrialEventName = "StartTrial"
    static let subscriptionFailedEventName = "SubscriptionFailed"
    static let subscriptionRestoredEventName = "SubscriptionRestore"
    static let mobilePurchase = "fb_mobile_purchase"
  }

  func testResolvingProducts() {
    requestor.resolveProducts()

    XCTAssertEqual(
      requestFactory.capturedProductIdentifiers,
      Set([transaction.payment.productIdentifier]),
      "Should use the product identifier from the transaction's payment to create the products request"
    )
    XCTAssertEqual(
      requestor.productsRequest.delegate as? PaymentProductRequestor,
      requestor,
      "Should set the requestor as the products request delegate when resolving products"
    )
    XCTAssertEqual(
      requestFactory.request.startCallCount,
      1,
      "Should start the products request when resolving products"
    )
    XCTAssertTrue(
      PaymentProductRequestor.pendingRequestors.contains(requestor),
      "Should maintain a list of strong references to requestors performing requests"
    )
  }

  // MARK: - Device Receipt

  func testFetchingDeviceReceipt() throws {
    try seedReceiptData()
    receiptProvider.stubbedURL = tempURL

    let receiptData = requestor.fetchDeviceReceipt()

    XCTAssertTrue(
      receiptProvider.wasAppStoreReceiptURLRead,
      "Fetching the device receipt should request a url from the receipt provider"
    )
    XCTAssertEqual(
      receiptData,
      encodedAppName,
      "Fetching the device receipt should fetch the data at the receipt path"
    )
  }

  // MARK: - Logging implicit transaction events

  func testLoggingTransactionWithKnownEventNames() throws {
    try seedReceiptData()
    receiptProvider.stubbedURL = tempURL

    try [AppEvents.Name.purchased, AppEvents.Name.subscribe, AppEvents.Name.startTrial].forEach { eventName in
      requestor.logImplicitTransactionEvent(
        eventName.rawValue,
        valueToSum: 100,
        parameters: [Keys.passThroughParameter: Values.passThroughValue]
      )
      let expected = PaymentProductParameters(
        isImplicitlyLogged: "1",
        receiptData: encodedAppName.base64EncodedString(),
        passThroughParameter: Values.passThroughValue
      )

      XCTAssertEqual(
        try decodedEventParameters(),
        expected,
        "Should fetch and include the receipt data for events matching transaction names"
      )
      XCTAssertEqual(
        eventLogger.capturedValueToSum,
        100,
        "Should log the value to sum"
      )
    }
  }

  func testLoggingTransactionWithUnknownEventNames() throws {
    try seedReceiptData()
    receiptProvider.stubbedURL = tempURL

    try ["foo", "bar", "baz"].forEach { eventName in
      requestor.logImplicitTransactionEvent(
        eventName,
        valueToSum: 100,
        parameters: [Keys.passThroughParameter: Values.passThroughValue]
      )

      let expected = PaymentProductParameters(
        isImplicitlyLogged: "1",
        passThroughParameter: Values.passThroughValue
      )

      XCTAssertEqual(
        try decodedEventParameters(),
        expected,
        "Should not fetch and include the receipt data for events that do not match transaction names"
      )
      XCTAssertEqual(
        eventLogger.capturedValueToSum,
        100,
        "Should log the value to sum"
      )
    }
  }

  func testLoggingImplicitTransactionFlushes() {
    requestor.logImplicitTransactionEvent("foo", valueToSum: 100, parameters: [:])

    XCTAssertEqual(
      eventLogger.flushCallCount,
      1,
      "Should flush events once per logging attempt"
    )
    XCTAssertEqual(
      eventLogger.capturedFlushReason,
      AppEventsUtility.FlushReason.eagerlyFlushingEvent.rawValue,
      "Should capture the flush reason"
    )
  }

  func testLoggingWithExplicitFlushBehavior() {
    eventLogger.flushBehavior = .explicitOnly
    requestor.logImplicitTransactionEvent("foo", valueToSum: 100, parameters: [:])

    XCTAssertEqual(
      eventLogger.flushCallCount,
      0,
      "Should not flush events immediately when the behavior is explicit flushing only"
    )
  }

  // MARK: - Subscriptions

  func testIsSubscriptionWithValidSubscription() {
    XCTAssertTrue(
      requestor.isSubscription(SampleProducts.createValidSubscription()),
      "A product with a non zero subscription period should be considered a subscription"
    )
  }

  func testIsSubscriptionWithNonSubscription() {
    XCTAssertFalse(
      requestor.isSubscription(SampleProducts.createValid()),
      "A product without a subscription period should not be considered a subscription"
    )
  }

  func testIsSubscriptionWithInvalidSubscription() {
    XCTAssertFalse(
      requestor.isSubscription(SampleProducts.createInvalidSubscription()),
      "A product with an empty subscription period should be considered a subscription"
    )
  }

  // MARK: - Event Parameters

  func testParametersForPurchasedTransactionWithoutProduct() throws {
    let transaction = TestPaymentTransaction(
      identifier: name,
      state: .purchased,
      date: .distantPast,
      payment: TestPayment(productIdentifier: name, quantity: 5)
    )

    let rawParameters = requestor.getEventParameters(of: nil, with: transaction)
    let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
    let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

    let expectedParameters = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.inApp,
      numberOfItems: 5,
      transactionDate: "0001-12-31 16:07:02-075258"
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testParametersForRestoredTransactionWithoutProduct() throws {
    let transaction = TestPaymentTransaction(
      identifier: name,
      state: .restored,
      date: .distantPast,
      payment: TestPayment(productIdentifier: name, quantity: 5)
    )

    let rawParameters = requestor.getEventParameters(of: nil, with: transaction)
    let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
    let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

    let expectedParameters = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.inApp,
      numberOfItems: 5,
      transactionDate: "0001-12-31 16:07:02-075258"
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testParametersForOtherTransactionsWithoutProduct() throws {
    try [SKPaymentTransactionState.deferred, .failed, .purchasing].forEach { state in
      let transaction = TestPaymentTransaction(
        identifier: name,
        state: state,
        date: .distantPast,
        payment: TestPayment(productIdentifier: name, quantity: 5)
      )

      let rawParameters = requestor.getEventParameters(of: nil, with: transaction)
      let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
      let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

      let expectedParameters = PaymentProductParameters(
        contentID: transaction.payment.productIdentifier,
        productType: Values.inApp,
        numberOfItems: 5,
        transactionDate: ""
      )

      XCTAssertEqual(parameters, expectedParameters)
    }
  }

  func testParametersForPurchasedTransactionWithProduct() throws {
    let transaction = TestPaymentTransaction(
      identifier: name,
      state: .purchased,
      date: .distantPast,
      payment: TestPayment(productIdentifier: name, quantity: 5)
    )

    let rawParameters = requestor.getEventParameters(
      of: SampleProducts.createValid(),
      with: transaction
    )
    let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
    let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

    let expectedParameters = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.inApp,
      numberOfItems: 5,
      transactionDate: "0001-12-31 16:07:02-075258",
      transactionID: name,
      currency: "USD",
      productTitle: TestProduct.title,
      description: TestProduct.productDescription
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testParametersForTransactionWithProduct() throws {
    let transaction = TestPaymentTransaction(
      identifier: name,
      state: .deferred,
      date: .distantPast,
      payment: TestPayment(productIdentifier: name, quantity: 5)
    )

    let rawParameters = requestor.getEventParameters(
      of: SampleProducts.createValid(),
      with: transaction
    )
    let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
    let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

    let expectedParameters = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.inApp,
      numberOfItems: 5,
      transactionDate: "",
      currency: "USD",
      productTitle: TestProduct.title,
      description: TestProduct.productDescription
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testParametersForTransactionWithSubscriptionProduct() throws {
    let transaction = TestPaymentTransaction(
      identifier: name,
      state: .deferred,
      date: .distantPast,
      payment: TestPayment(productIdentifier: name, quantity: 5)
    )

    let rawParameters = requestor.getEventParameters(
      of: SampleProducts.createValidSubscription(),
      with: transaction
    )
    let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
    let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

    let expectedParameters = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.subscription,
      numberOfItems: 5,
      transactionDate: "",
      currency: "USD",
      productTitle: TestProduct.title,
      description: TestProduct.productDescription,
      subscriptionPeriod: Values.oneDaySubscriptionPeriod,
      isStartTrial: "0"
    )

    XCTAssertEqual(parameters, expectedParameters)
  }

  func testParametersForTransactionWithDiscountedSubscriptionProducts() throws {
    let transaction = TestPaymentTransaction(
      identifier: name,
      state: .deferred,
      date: .distantPast,
      payment: TestPayment(productIdentifier: name, quantity: 5)
    )

    try [SKProductDiscount.PaymentMode.freeTrial, .payAsYouGo, .payUpFront].forEach { discountMode in
      let discount = createDiscount(mode: discountMode)
      let rawParameters = requestor.getEventParameters(
        of: SampleProducts.createSubscription(discount: discount),
        with: transaction
      )
      let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
      let parameters = try JSONDecoder().decode(PaymentProductParameters.self, from: data)

      let expectedParameters = PaymentProductParameters(
        contentID: transaction.payment.productIdentifier,
        productType: Values.subscription,
        numberOfItems: 5,
        transactionDate: "",
        currency: "USD",
        productTitle: TestProduct.title,
        description: TestProduct.productDescription,
        subscriptionPeriod: Values.oneDaySubscriptionPeriod,
        isStartTrial: discountMode == .freeTrial ? "1" : "0",
        isFreeTrial: discountMode == .freeTrial ? "1" : "0",
        trialPeriod: "P5D",
        trialPrice: 100
      )
      XCTAssertEqual(parameters, expectedParameters)
    }
  }

  // MARK: - Subscription Event Logging

  // MARK: Purchasing

  func testLoggingPurchasingSubscription() {
    let originalTransaction = TestPaymentTransaction(identifier: "foo", state: .purchased)
    let transaction = TestPaymentTransaction(
      state: .purchasing,
      originalTransaction: originalTransaction
    )
    requestor.logImplicitSubscribeTransaction(transaction, of: nil)

    let expected = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.inApp,
      numberOfItems: 0,
      transactionDate: "",
      isImplicitlyLogged: "1"
    )
    XCTAssertEqual(
      try decodedEventParameters(),
      expected,
      "Should log the expected parameters"
    )
    XCTAssertEqual(
      eventLogger.capturedEventName,
      Values.willSubscribeEventName,
      "Should log the expected name"
    )
    XCTAssertNil(
      store.capturedSetObjectKey,
      "Should not remove the original transaction from the persisted transaction ids when the state is purchasing"
    )
  }

  // MARK: Purchased

  func testLoggingLoggedPurchasedSubscription() {
    let identifier = "foo"
    let originalTransaction = TestPaymentTransaction(identifier: identifier, state: .purchased)
    let transaction = TestPaymentTransaction(
      state: .purchased,
      originalTransaction: originalTransaction
    )
    // Sets it to be previously logged
    requestor.appendOriginalTransactionID(identifier)

    requestor.logImplicitSubscribeTransaction(transaction, of: nil)

    XCTAssertNil(
      eventLogger.capturedEventName,
      "Should not log a previously logged purchased subscription"
    )
    XCTAssertFalse(
      store.capturedValues.compactMap { $0.value as? String }
        .filter { $0.contains(identifier) }
        .isEmpty,
      "Should not clear the persisted identifier of the previously logged purchase"
    )
  }

  func testLoggingUnloggedPurchasedSubscription() {
    let identifier = "foo"
    let originalTransaction = TestPaymentTransaction(identifier: identifier, state: .purchased)
    let transaction = TestPaymentTransaction(
      state: .purchased,
      originalTransaction: originalTransaction
    )
    requestor.logImplicitSubscribeTransaction(transaction, of: nil)

    XCTAssertEqual(
      eventLogger.capturedEventName,
      Values.didSubscribeEventName,
      "Should log a previously unlogged purchased subscription"
    )
    XCTAssertFalse(
      store.capturedValues.compactMap { $0.value as? String }
        .filter { $0.contains(identifier) }
        .isEmpty,
      "Should persist the identifier of the purchase"
    )
  }

  func testLoggingPurchasedTrialSubscription() {
    let identifier = "foo"
    let originalTransaction = TestPaymentTransaction(identifier: identifier, state: .purchased)
    let discountedPayment = TestPayment(
      productIdentifier: "bar",
      discount: sampleDiscount
    )
    let transaction = TestPaymentTransaction(
      state: .purchased,
      payment: discountedPayment,
      originalTransaction: originalTransaction
    )
    let product = SampleProducts.createSubscription(discount: createDiscount(mode: .freeTrial))

    // Set it to be previously logged so we can check that it was cleared
    requestor.appendOriginalTransactionID(identifier)

    requestor.logImplicitSubscribeTransaction(transaction, of: product)

    XCTAssertEqual(
      eventLogger.capturedEventName,
      Values.startTrialEventName,
      "Should log whether a purchase marks the start of a trial"
    )
    // Clears original transaction ID
    XCTAssertEqual(
      store.capturedSetObjectKey,
      Keys.originalTransactionsPersistence,
      "Should override the existing transaction ids"
    )
    XCTAssertFalse(
      store.capturedValues.contains {
        return $0.value as? String == identifier
      },
      "Logging a trial start should clear the original transaction"
    )
  }

  // MARK: Failed, Restored, Deferred

  func testLoggingSubscriptions() {
    let testData: [(paymentState: SKPaymentTransactionState, eventName: String?, message: String)] = [
      (
        .failed,
        Values.subscriptionFailedEventName,
        "Should log the expected event name for a subscription failure"
      ),
      (
        .restored,
        Values.subscriptionRestoredEventName,
        "Should log the expected event name for a subscription restoration"
      ),
      (
        .deferred,
        nil,
        "Should not log an event for a subscription deferral"
      )
    ]

    testData.forEach {
      eventLogger.capturedEventName = nil
      let transaction = TestPaymentTransaction(
        state: $0.paymentState
      )
      requestor.logImplicitSubscribeTransaction(transaction, of: nil)

      XCTAssertEqual(
        eventLogger.capturedEventName,
        $0.eventName,
        $0.message
      )
    }
  }

  // MARK: - Request Delegate Methods

  func testReceivingProductRequestResponseWithoutProductsOrProductIdentifiers() {
    // use a non-deferred state so we can observe implicit logging
    requestor.transaction = TestPaymentTransaction(state: .purchased)

    let response = TestProductsResponse(
      products: [],
      invalidProductIdentifiers: []
    )
    requestor.productsRequest(SKProductsRequest(), didReceive: response)

    XCTAssertEqual(
      loggerFactory.capturedLoggingBehavior,
      LoggingBehavior.appEvents,
      "Should request a logger with the expected logging behavior"
    )
    XCTAssertEqual(
      loggerFactory.logger.capturedContents,
      "FBSDKPaymentObserver: Expect to resolve one product per request",
      """
      Should provide a useful message when receiving a product request
      response without products or product identifiers
      """
    )
    XCTAssertEqual(
      eventLogger.capturedEventName,
      Values.mobilePurchase,
      "bar"
    )
  }

  func testReceivingProductRequestResponseWithoutMultipleProducts() throws {
    // use a transaction with a non-deferred state so we can observe implicit logging
    transaction = TestPaymentTransaction(state: .purchased)

    let response = TestProductsResponse(
      products: [
        SampleProducts.createValid(),
        SampleProducts.createValidSubscription()
      ],
      invalidProductIdentifiers: []
    )

    requestor.productsRequest(SKProductsRequest(), didReceive: response)

    XCTAssertEqual(
      loggerFactory.logger.capturedContents,
      "FBSDKPaymentObserver: Expect to resolve one product per request",
      """
      Should provide a useful message when receiving a product request
      response with multiple products
      """
    )

    let parameters = try decodedEventParameters()
    let expectedParameters = PaymentProductParameters(
      contentID: transaction.payment.productIdentifier,
      productType: Values.inApp,
      numberOfItems: 0,
      transactionDate: "",
      currency: "USD",
      productTitle: TestProduct.title,
      description: TestProduct.productDescription,
      isImplicitlyLogged: "1"
    )
    XCTAssertEqual(parameters, expectedParameters)
  }

  func testDidFinishRequest() {
    // use a transaction with a non-deferred state so we can observe implicit logging
    transaction = TestPaymentTransaction(state: .purchased)

    // ensure there's a requestor to remove
    requestor.resolveProducts()
    XCTAssertTrue(PaymentProductRequestor.pendingRequestors.contains(requestor))

    requestor.requestDidFinish(SKRequest())

    XCTAssertFalse(
      PaymentProductRequestor.pendingRequestors.contains(requestor),
      "Finishing any request should remove the pending requestors"
    )
    XCTAssertNil(
      eventLogger.capturedEventName,
      "Should not log an event when the request finishes"
    )
  }

  func testDidFailRequest() {
    // use a transaction with a non-deferred state so we can observe implicit logging
    transaction = TestPaymentTransaction(state: .purchased)

    // ensure there's a requestor to remove
    requestor.resolveProducts()
    XCTAssertTrue(PaymentProductRequestor.pendingRequestors.contains(requestor))

    requestor.request(SKRequest(), didFailWithError: SampleError())

    XCTAssertFalse(
      PaymentProductRequestor.pendingRequestors.contains(requestor),
      "Failing any request should remove the pending requestors"
    )
    XCTAssertEqual(
      eventLogger.capturedEventName,
      Values.mobilePurchase,
      "Should log an event when the request fails. This seems like it might be a bug."
    )
  }

  // MARK: - Helpers

  func createDiscount(mode: SKProductDiscount.PaymentMode) -> TestProductDiscount {
    TestProductDiscount(
     paymentMode: mode,
     price: 100.0,
     subscriptionPeriod: TestProductSubscriptionPeriod(numberOfUnits: 5)
   )
  }

  var encodedAppName: Data {
    return Values.appName.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
  }

  func seedReceiptData() throws {
    try encodedAppName.write(to: tempURL)
  }

  func decodedEventParameters() throws -> PaymentProductParameters {
    guard let rawParameters = eventLogger.capturedParameters as? [String: Any] else {
      throw MissingEventParametersError()
    }
    let data = try JSONSerialization.data(withJSONObject: rawParameters, options: [])
    return try JSONDecoder().decode(PaymentProductParameters.self, from: data)
  }

  struct MissingEventParametersError: Error {}
} // swiftlint:disable:this file_length
