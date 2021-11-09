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

import TestTools
import XCTest

// swiftlint:disable:next type_body_length
class FBSDKAEMReporterTests: XCTestCase {

  enum Keys {
    static let defaultCurrency = "default_currency"
    static let cutoffTime = "cutoff_time"
    static let validFrom = "valid_from"
    static let configMode = "config_mode"
    static let conversionValueRules = "conversion_value_rules"
    static let conversionValue = "conversion_value"
    static let priority = "priority"
    static let events = "events"
    static let eventName = "event_name"
    static let advertiserID = "advertiser_id"
    static let businessID = "advertiser_id"
    static let campaignID = "campaign_id"
    static let token = "token"
  }

  enum Values {
    static let purchase = "fb_mobile_purchase"
    static let donate = "Donate"
    static let defaultMode = "DEFAULT"
    static let brandMode = "BRAND"
    static let USD = "USD"
  }

  let requestProvider = TestGraphRequestFactory()
  let date = Calendar.current.date(
    byAdding: .day,
    value: -2,
    to: Date()
  )! // swiftlint:disable:this force_unwrapping
  var testInvocation = TestInvocation()
  lazy var reportFilePath = FBSDKBasicUtility.persistenceFilePath(name)
  let urlWithInvocation = URL(string: "fb123://test.com?al_applink_data=%7B%22acs_token%22%3A+%22test_token_1234567%22%2C+%22campaign_ids%22%3A+%22test_campaign_1234%22%2C+%22advertiser_id%22%3A+%22test_advertiserid_12345%22%7D")! // swiftlint:disable:this line_length force_unwrapping

  override class func setUp() {
    super.setUp()

    reset()
  }

  override func setUp() {
    super.setUp()

    removeReportFile()
    AEMReporter.configure(withRequestProvider: requestProvider)
    // Actual queue doesn't matter as long as it's not the same as the designated queue name in the class
    AEMReporter.queue = DispatchQueue(label: name, qos: .background)
    AEMReporter.isEnabled = true
    AEMReporter.reportFilePath = reportFilePath
  }

  class func reset() {
    AEMReporter.invocations = []
    AEMReporter.completionBlocks = []
    AEMReporter.isLoadingConfiguration = false
    AEMReporter.configs = [:]
    AEMReporter._clearCache()
  }

  func testEnable() {
    AEMReporter.isEnabled = false
    AEMReporter.enable()

    XCTAssertTrue(AEMReporter.isEnabled, "AEM Report should be enabled")
  }

  func testParseURL() {
    var url: URL?
    XCTAssertNil(AEMReporter.parseURL(url))

    url = URL(string: "fb123://test.com")
    XCTAssertNil(AEMReporter.parseURL(url))

    url = URL(string: "fb123://test.com?al_applink_data=%7B%22acs_token%22%3A+%22test_token_1234567%22%2C+%22campaign_ids%22%3A+%22test_campaign_1234%22%7D") // swiftlint:disable:this line_length
    var invocation = AEMReporter.parseURL(url)
    XCTAssertEqual(invocation?.acsToken, "test_token_1234567")
    XCTAssertEqual(invocation?.campaignID, "test_campaign_1234")
    XCTAssertNil(invocation?.businessID)

    invocation = AEMReporter.parseURL(urlWithInvocation)
    XCTAssertEqual(invocation?.acsToken, "test_token_1234567")
    XCTAssertEqual(invocation?.campaignID, "test_campaign_1234")
    XCTAssertEqual(invocation?.businessID, "test_advertiserid_12345")
  }

  func testLoadReportData() {
    guard let invocation = AEMReporter.parseURL(urlWithInvocation) else {
      return XCTFail("Parsing Error")
    }

    AEMReporter.invocations = [invocation]
    AEMReporter._saveReportData()
    let data = AEMReporter._loadReportData() as? [AEMInvocation]
    XCTAssertEqual(data?.count, 1)
    XCTAssertEqual(data?[0].acsToken, "test_token_1234567")
    XCTAssertEqual(data?[0].campaignID, "test_campaign_1234")
    XCTAssertEqual(data?[0].businessID, "test_advertiserid_12345")
  }

  func testLoadConfigs() {
    AEMReporter._addConfigs([SampleAEMData.validConfigData1])
    AEMReporter._addConfigs([SampleAEMData.validConfigData1, SampleAEMData.validConfigData2])
    let loadedConfigs: NSMutableDictionary? = AEMReporter._loadConfigs()
    XCTAssertEqual(loadedConfigs?.count, 1, "Should load the expected number of configs")

    let defaultConfigs: [AEMConfiguration]? = loadedConfigs?[Values.defaultMode] as? [AEMConfiguration]
    XCTAssertEqual(
      defaultConfigs?.count, 2, "Should load the expected number of default configs"
    )
    XCTAssertEqual(
      defaultConfigs?[0].defaultCurrency, Values.USD, "Should save the expected default_currency of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[0].cutoffTime, 1, "Should save the expected cutoff_time of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[0].validFrom, 10000, "Should save the expected valid_from of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[0].configMode, Values.defaultMode, "Should save the expected config_mode of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[0].conversionValueRules.count, 1, "Should save the expected conversion_value_rules of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[1].defaultCurrency, Values.USD, "Should save the expected default_currency of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[1].cutoffTime, 1, "Should save the expected cutoff_time of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[1].validFrom, 10001, "Should save the expected valid_from of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[1].configMode, Values.defaultMode, "Should save the expected config_mode of the config"
    )
    XCTAssertEqual(
      defaultConfigs?[1].conversionValueRules.count, 2, "Should save the expected conversion_value_rules of the config"
    )
  }

  func testClearCache() {
    AEMReporter._addConfigs([SampleAEMData.validConfigData1])
    AEMReporter._addConfigs([SampleAEMData.validConfigData1, SampleAEMData.validConfigData2])

    AEMReporter._clearCache()
    var configs = AEMReporter.configs
    var configList: [AEMConfiguration]? = configs[Values.defaultMode] as? [AEMConfiguration]
    XCTAssertEqual(configList?.count, 1, "Should have the expected number of configs")

    guard let invocation1 = AEMInvocation(
      campaignID: "test_campaign_1234",
      acsToken: "test_token_1234567",
      acsSharedSecret: "test_shared_secret",
      acsConfigID: "test_config_id_123",
      businessID: nil
    ), let invocation2 = AEMInvocation(
      campaignID: "test_campaign_1234",
      acsToken: "test_token_1234567",
      acsSharedSecret: "test_shared_secret",
      acsConfigID: "test_config_id_123",
      businessID: nil
    )
    else { return XCTFail("Unwrapping Error") }
    invocation1.setConfigID(10000)
    invocation2.setConfigID(10001)
    guard let date = Calendar.current.date(byAdding: .day, value: -2, to: Date())
    else { return XCTFail("Date Creation Error") }
    invocation2.setConversionTimestamp(date)
    AEMReporter.invocations = [invocation1, invocation2]
    AEMReporter._addConfigs(
      [SampleAEMData.validConfigData1, SampleAEMData.validConfigData2, SampleAEMData.validConfigData3]
    )
    AEMReporter._clearCache()
    guard let invocations = AEMReporter.invocations as? [AEMInvocation] else {
      return XCTFail("Should have invocations")
    }
    XCTAssertEqual(invocations.count, 1, "Should clear the expired invocation")
    XCTAssertEqual(invocations[0].configID, 10000, "Should keep the expected invocation")
    configs = AEMReporter.configs
    configList = configs[Values.defaultMode] as? [AEMConfiguration]
    XCTAssertEqual(configList?.count, 2, "Should have the expected number of configs")
    XCTAssertEqual(configList?[0].validFrom, 10000, "Should keep the expected config")
    XCTAssertEqual(configList?[1].validFrom, 20000, "Should keep the expected config")
  }

  func testHandleURL() {
    guard let url = URL(string: "fb123://test.com?al_applink_data=%7B%22acs_token%22%3A+%22test_token_1234567%22%2C+%22campaign_ids%22%3A+%22test_campaign_1234%22%7D") // swiftlint:disable:this line_length
    else { return XCTFail("Unwrapping Error") }
    AEMReporter.handle(url)
    let invocations = AEMReporter.invocations
    XCTAssertTrue(
      invocations.count > 0, // swiftlint:disable:this empty_count
      "Handling a url that contains invocations should set the invocations on the reporter"
    )
  }

  func testIsConfigRefreshTimestampValid() {
    AEMReporter.timestamp = Date()
    XCTAssertTrue(
      AEMReporter._isConfigRefreshTimestampValid(),
      "Timestamp should be valid"
    )

    guard let date = Calendar.current.date(byAdding: .day, value: -2, to: Date())
    else { return XCTFail("Date Creation Error") }
    AEMReporter.timestamp = date
    XCTAssertFalse(
      AEMReporter._isConfigRefreshTimestampValid(),
      "Timestamp should not be valid"
    )
  }

  func testShouldRefreshWithoutBusinessID1() {
    AEMReporter.invocations = [SampleAEMData.invocationWithoutAdvertiserID]
    AEMReporter.timestamp = Date()
    AEMReporter.configs = [
      Values.defaultMode: [SampleAEMConfigurations.createConfigWithoutBusinessID()]
    ]

    XCTAssertFalse(
      AEMReporter._shouldRefresh(),
      "Should not refresh config if timestamp is not expired and there is no business ID"
    )
  }

  func testShouldRefreshWithoutBusinessID2() {
    AEMReporter.invocations = [SampleAEMData.invocationWithoutAdvertiserID]
    guard let date = Calendar.current.date(byAdding: .day, value: -2, to: Date())
    else { return XCTFail("Date Creation Error") }
    AEMReporter.timestamp = date
    AEMReporter.configs = [
      Values.defaultMode: [SampleAEMConfigurations.createConfigWithoutBusinessID()]
    ]

    XCTAssertTrue(
      AEMReporter._shouldRefresh(),
      "Should not refresh config if timestamp is expired"
    )
  }

  func testShouldRefreshWithoutBusinessID3() {
    AEMReporter.invocations = [SampleAEMData.invocationWithoutAdvertiserID]
    guard let date = Calendar.current.date(byAdding: .day, value: -2, to: Date())
    else { return XCTFail("Date Creation Error") }
    AEMReporter.timestamp = date
    AEMReporter.configs = [:]

    XCTAssertTrue(
      AEMReporter._shouldRefresh(),
      "Should not refresh config if configs is empty"
    )
  }

  func testShouldRefreshWithBusinessID() {
    AEMReporter.invocations = [
      SampleAEMData.invocationWithoutAdvertiserID,
      SampleAEMData.invocationWithAdvertiserID1
    ]
    AEMReporter.timestamp = Date()
    AEMReporter.configs = [
      Values.defaultMode: [SampleAEMConfigurations.createConfigWithoutBusinessID()]
    ]

    XCTAssertTrue(
      AEMReporter._shouldRefresh(),
      "Should not refresh config if there exists an invocation with business ID"
    )
  }

  func testSendAggregationRequest() {
    AEMReporter.invocations = []
    AEMReporter._sendAggregationRequest()
    XCTAssertNil(
      self.requestProvider.capturedGraphPath,
      "GraphRequest should be created because of there is no invocation"
    )

    guard let invocation = AEMReporter.parseURL(urlWithInvocation) else { return XCTFail("Parsing Error") }
    invocation.isAggregated = false
    AEMReporter.invocations = [invocation]
    AEMReporter._sendAggregationRequest()
    XCTAssertTrue(
      self.requestProvider.capturedGraphPath?.hasSuffix("aem_conversions") == true,
      "GraphRequst should created because of there is non-aggregated invocation"
    )
  }

  func testCompletingAggregationRequestWithError() {

    guard let invocation = AEMReporter.parseURL(urlWithInvocation) else { return XCTFail("Parsing Error") }
    invocation.isAggregated = false
    AEMReporter.invocations = [invocation]
    AEMReporter._sendAggregationRequest()

    requestProvider.capturedRequests.first?.capturedCompletionHandler?(nil, nil, SampleError())
    XCTAssertFalse(
      invocation.isAggregated,
      "Completing with an error should not mark the invocation as aggregated"
    )
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: reportFilePath),
      "Completing with an error should not write the report to the expected file path"
    )
  }

  func testCompletingAggregationRequestWithoutError() {

    guard let invocation = AEMReporter.parseURL(urlWithInvocation) else { return XCTFail("Parsing Error") }
    invocation.isAggregated = false
    AEMReporter.invocations = [invocation]
    AEMReporter._sendAggregationRequest()

    requestProvider.capturedRequests.first?.capturedCompletionHandler?(nil, nil, nil)
    XCTAssertTrue(
      invocation.isAggregated,
      "Completing with no error should mark the invocation as aggregated"
    )
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: reportFilePath),
      "Completing with no error should write the report to the expected file path"
    )
  }

  func testRecordAndUpdateEvents() {
    AEMReporter.timestamp = Date()
    guard let invocation = AEMInvocation(
      campaignID: "test_campaign_1234",
      acsToken: "test_token_1234567",
      acsSharedSecret: "test_shared_secret",
      acsConfigID: "test_config_id_123",
      businessID: nil
    )
    else { return XCTFail("Unwrapping Error") }
    guard let config = AEMConfiguration(json: SampleAEMData.validConfigData3)
    else { return XCTFail("Unwrapping Error") }

    AEMReporter.configs = [Values.defaultMode: [config]]
    AEMReporter.invocations = [invocation]
    AEMReporter.recordAndUpdate(event: Values.purchase, currency: Values.USD, value: 100, parameters: nil)
    // Invocation should be attributed and updated while request should be sent
    XCTAssertTrue(
      self.requestProvider.capturedGraphPath?.hasSuffix("aem_conversions") == true,
      "Should create a request to update the conversions for a valid event"
    )
    XCTAssertFalse(
      invocation.isAggregated,
      "Should not mark the invocation as aggregated if it is recorded and sent"
    )
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: self.reportFilePath),
      "Should save uploaded events to disk"
    )
    XCTAssertEqual(
      requestProvider.capturedRequests.first?.startCallCount,
      1,
      "Should start the graph request to update the conversions"
    )
  }

  func testRecordAndUpdateEventsWithAEMDisabled() {
    AEMReporter.isEnabled = false
    AEMReporter.timestamp = date

    AEMReporter.recordAndUpdate(event: Values.purchase, currency: Values.USD, value: 100, parameters: nil)
    XCTAssertNil(
      requestProvider.capturedGraphPath,
      "Should not create a request to fetch the config if AEM is disabled"
    )
  }

  func testRecordAndUpdateEventsWithEmptyEvent() {
    AEMReporter.timestamp = self.date

    AEMReporter.recordAndUpdate(event: "", currency: Values.USD, value: 100, parameters: nil)

    XCTAssertNil(
      requestProvider.capturedGraphPath,
      "Should not create a request to fetch the config if the event being recorded is empty"
    )
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: self.reportFilePath),
      "Should not save an empty event to disk"
    )
  }

  func testRecordAndUpdateEventsWithEmptyConfigs() {
    AEMReporter.timestamp = date
    AEMReporter.invocations = [testInvocation]

    AEMReporter.recordAndUpdate(event: Values.purchase, currency: Values.USD, value: 100, parameters: nil)
    guard testInvocation.attributionCallCount == 0,
          testInvocation.updateConversionCallCount == 0 else {
      return XCTFail("Should update attribute and conversions")
    }
  }

  func testLoadConfigurationWithBlock() {
    guard let config = AEMConfiguration(json: SampleAEMData.validConfigData3)
    else { return XCTFail("Unwrapping Error") }
    var blockCall = 0
    AEMReporter.timestamp = Date()
    AEMReporter.configs = [Values.defaultMode: [config]]

    AEMReporter._loadConfiguration { _ in
      blockCall += 1
    }
    XCTAssertEqual(
      blockCall,
      1,
      "Should call the completion when loading the configuration"
    )
  }

  func testLoadConfigurationWithoutBlock() {
    AEMReporter.timestamp = date

    AEMReporter.isLoadingConfiguration = false
    AEMReporter._loadConfiguration(block: nil)
    guard let path = self.requestProvider.capturedGraphPath,
          path.hasSuffix("aem_conversion_configs")
    else {
      return XCTFail("Should not require a completion block to load a configuration")
    }
  }

  func testGetConfigRequestParameterWithoutAdvertiserIDs() {
    AEMReporter.invocations = NSMutableArray(array: [SampleAEMData.invocationWithoutAdvertiserID])

    XCTAssertEqual(
      AEMReporter._requestParameters() as NSDictionary,
      ["advertiser_ids": "[]"],
      "Should not have unexpected advertiserIDs in config request params"
    )
  }

  func testGetConfigRequestParameterWithAdvertiserIDs() {
    AEMReporter.invocations =
        NSMutableArray(array: [SampleAEMData.invocationWithAdvertiserID1, SampleAEMData.invocationWithoutAdvertiserID])

    XCTAssertEqual(
      AEMReporter._requestParameters() as NSDictionary,
      ["advertiser_ids": "[\"\(SampleAEMData.invocationWithAdvertiserID1.businessID!)\"]"], // swiftlint:disable:this force_unwrapping line_length
      "Should have expected advertiserIDs in config request params"
    )

    AEMReporter.invocations =
        NSMutableArray(array: [SampleAEMData.invocationWithAdvertiserID1, SampleAEMData.invocationWithAdvertiserID2, SampleAEMData.invocationWithoutAdvertiserID]) // swiftlint:disable:this line_length

    XCTAssertEqual(
      AEMReporter._requestParameters() as NSDictionary,
      ["advertiser_ids": "[\"\(SampleAEMData.invocationWithAdvertiserID1.businessID!)\",\"\(SampleAEMData.invocationWithAdvertiserID2.businessID!)\"]"], // swiftlint:disable:this force_unwrapping line_length
      "Should have expected advertiserIDs in config request params"
    )
  }

  func testGetAggregationRequestParameterWithoutAdvertiserID() {
    let params: [String: Any] =
      AEMReporter._aggregationRequestParameters(SampleAEMData.invocationWithoutAdvertiserID)

    XCTAssertEqual(
      params[Keys.campaignID] as? String,
      SampleAEMData.invocationWithoutAdvertiserID.campaignID,
      "Should have expected campaign_id in aggregation request params"
    )
    XCTAssertEqual(
      params[Keys.token] as? String,
      SampleAEMData.invocationWithoutAdvertiserID.acsToken,
      "Should have expected ACS token in aggregation request params"
    )
    XCTAssertNil(
      params[Keys.businessID],
      "Should not have unexpected advertiser_id in aggregation request params"
    )
  }

  func testGetAggregationRequestParameterWithAdvertiserID() {
    let params: [String: Any] =
      AEMReporter._aggregationRequestParameters(SampleAEMData.invocationWithAdvertiserID1)

    XCTAssertEqual(
      params[Keys.campaignID] as? String,
      SampleAEMData.invocationWithAdvertiserID1.campaignID,
      "Should have expected campaign_id in aggregation request params"
    )
    XCTAssertEqual(
      params[Keys.token] as? String,
      SampleAEMData.invocationWithAdvertiserID1.acsToken,
      "Should have expected ACS token in aggregation request params"
    )
    XCTAssertNotNil(
      params[Keys.businessID],
      "Should have expected advertiser_id in aggregation request params"
    )
  }

  func testAttributedInvocationWithoutParameters() {
    let invocations = [
      SampleAEMData.invocationWithoutAdvertiserID,
      SampleAEMData.invocationWithAdvertiserID1,
      SampleAEMData.invocationWithAdvertiserID2
    ]
    let configs = [
      Values.defaultMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithoutBusinessID()]),
      Values.brandMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithBusinessID()])
    ]

    let attributedInvocation = AEMReporter._attributedInvocation(
      invocations,
      event: Values.purchase,
      currency: nil,
      value: nil,
      parameters: nil,
      configs: configs
    )
    XCTAssertNotNil(
      attributedInvocation,
      "Should have invocation attributed"
    )
    XCTAssertNil(
      attributedInvocation?.businessID,
      "The attributed invocation should not have advertiser ID"
    )
  }

  func testAttributedInvocationWithParameters() {
    let invocations = [
      SampleAEMData.invocationWithoutAdvertiserID,
      SampleAEMData.invocationWithAdvertiserID1,
      SampleAEMData.invocationWithAdvertiserID2
    ]
    let configs = [
      Values.defaultMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithoutBusinessID()]),
      Values.brandMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithBusinessID()])
    ]

    let attributedInvocation = AEMReporter._attributedInvocation(
      invocations,
      event: "test",
      currency: nil,
      value: nil,
      parameters: ["values": "abcdefg"],
      configs: configs
    )
    XCTAssertNil(
      attributedInvocation,
      "Should not have invocation attributed"
    )
  }

  func testAttributedInvocationWithUnmatchedParameters() {
    let invocations = [
      SampleAEMData.invocationWithoutAdvertiserID,
      SampleAEMData.invocationWithAdvertiserID1,
      SampleAEMData.invocationWithAdvertiserID2
    ]
    let configs = [
      Values.defaultMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithoutBusinessID()]),
      Values.brandMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithBusinessID()])
    ]

    let attributedInvocation = AEMReporter._attributedInvocation(
      invocations,
      event: Values.purchase,
      currency: nil,
      value: nil,
      parameters: ["value": "abcdefg"],
      configs: configs
    )
    XCTAssertNotNil(
      attributedInvocation,
      "Should have invocation attributed"
    )
    XCTAssertEqual(
      attributedInvocation?.businessID,
      SampleAEMData.invocationWithAdvertiserID1.businessID,
      "The attributed invocation should have advertiser ID"
    )
  }

  func testAttributedInvocationWithMultipleGeneralInvocations() {
    let invocation1 = SampleAEMInvocations.createGeneralInvocation1()
    let invocation2 = SampleAEMInvocations.createGeneralInvocation2()
    let invocations = [invocation1, invocation2]
    let configs = [
      Values.defaultMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithoutBusinessID()]),
      Values.brandMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithBusinessID()])
    ]

    let attributedInvocation = AEMReporter._attributedInvocation(
      invocations,
      event: Values.purchase,
      currency: nil,
      value: nil,
      parameters: nil,
      configs: configs
    )
    XCTAssertEqual(
      attributedInvocation?.campaignID,
      invocation2.campaignID,
      "Should attribute the event to the latest general invocation"
    )
  }

  func testAttributedInvocationWithUnmatchedEvent() {
    let invocation1 = SampleAEMInvocations.createGeneralInvocation1()
    let invocation2 = SampleAEMInvocations.createGeneralInvocation2()
    let invocations = [invocation1, invocation2]
    let configs = [
      Values.defaultMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithoutBusinessID()]),
      Values.brandMode: NSMutableArray(array: [SampleAEMConfigurations.createConfigWithBusinessID()])
    ]

    let attributedInvocation = AEMReporter._attributedInvocation(
      invocations,
      event: "test",
      currency: nil,
      value: nil,
      parameters: nil,
      configs: configs
    )
    XCTAssertNil(
      attributedInvocation,
      "Should not attribute the event with incorrect event"
    )
  }

  // MARK: - Helpers

  func removeReportFile() {
    do {
      try FileManager.default.removeItem(at: URL(fileURLWithPath: reportFilePath))
    } catch _ as NSError { }
  }
} // swiftlint:disable:this file_length
