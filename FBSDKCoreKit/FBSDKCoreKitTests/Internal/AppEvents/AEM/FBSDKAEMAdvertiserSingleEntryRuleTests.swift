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

#if !os(tvOS)

class FBSDKAEMAdvertiserSingleEntryRuleTests: XCTestCase { // swiftlint:disable:this type_body_length

  enum Keys {
      static let ruleOperator = "operator"
      static let ruleParamKey = "param_key"
      static let ruleStringValue = "string_value"
      static let ruleNumberValue = "number_value"
      static let ruleArrayValue = "array_value"
  }

  func testIsMatchedWithEventParameters() {
    var rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorContains,
      paramKey: "fb_content.title",
      linguisticCondition: "hello",
      numericalCondition: nil,
      arrayCondition: nil
    )
    XCTAssertTrue(
      rule.isMatchedEventParameters(["fb_content": ["title": "helloworld"]]),
      "Should expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["fb_content": ["tt": "helloworld"]]),
      "Should not expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["fb_content": ["title": 100]]),
      "Should not expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["quantitly": ["title": "helloworld"]]),
      "Should not expect the event parameter matched with the rule"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorNotEqual)
    XCTAssertTrue(
      rule.isMatchedEventParameters(["fb_content": ["title": "helloworld"]]),
      "Should expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["fb_content": ["tt": "helloworld"]]),
      "Should not expect the event parameter matched with the rule"
    )

    rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorGreaterThan,
      paramKey: "fb_content.product1.quantity",
      linguisticCondition: nil,
      numericalCondition: NSNumber(value: 10),
      arrayCondition: nil
    )
    XCTAssertTrue(
      rule.isMatchedEventParameters(["fb_content": ["product1": ["quantity": 100]]]),
      "Should expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["fb_content": ["product1": ["quantity": 1]]]),
      "Should expect the event parameter matched with the rule"
    )
  }

  func testIsMatchedWithEventParametersForAsteriskOperator() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorContains,
      paramKey: "fb_content[*].id",
      linguisticCondition: "coffee",
      numericalCondition: nil,
      arrayCondition: nil
    )

    XCTAssertTrue(
      rule.isMatchedEventParameters(["fb_content": [["id": "shop"], ["id": "coffeeshop"]]]),
      "Should expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["fb_content": ["id": "coffeeshop"]]),
      "Should not expect the event parameter matched with the rule without expected item"
    )
    XCTAssertFalse(
      rule.isMatchedEventParameters(["fb_content": [["id": "shop"]]]),
      "Should not expect the event parameter matched with the rule without expected id"
    )
  }

  func testIsMatchedWithEventParametersAndAsterisk() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorContains,
      paramKey: "fb_content[*].title",
      linguisticCondition: "hello",
      numericalCondition: nil,
      arrayCondition: nil
    )
    XCTAssertTrue(
      rule.isMatched(
        withAsteriskParam: "fb_content[*]",
        eventParameters: ["fb_content": [["title": "hello"], ["title", "world"]]],
        paramPath: ["fb_content[*]", "title"]
      ),
      "Should expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatched(
        withAsteriskParam: "fb_content[*]",
        eventParameters: ["fb_content": [["title": "aaaa"], ["title", "world"]]],
        paramPath: ["fb_content[*]", "title"]
      ),
      "Should not expect the event parameter matched with the rule"
    )
  }

  func testIsMatchedWithAsteriskParam() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorContains,
      paramKey: "fb_content[*].title",
      linguisticCondition: "hello",
      numericalCondition: nil,
      arrayCondition: nil
    )

    XCTAssertTrue(
      rule.isMatched(
        withAsteriskParam: "fb_content[*]",
        eventParameters: ["fb_content": [["title": "hello"], ["title", "world"]]],
        paramPath: ["fb_content[*]", "title"]
      ),
      "Should expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatched(
        withAsteriskParam: "fb_content[*]",
        eventParameters: ["fb_content": [["title": "aaaa"], ["title", "world"]]],
        paramPath: ["fb_content[*]", "title"]
      ),
      "Should not expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatched(
        withAsteriskParam: "fb_content[*]",
        eventParameters: ["fb_content_aaa": [["title": "aaaa"], ["title", "world"]]],
        paramPath: ["fb_content[*]", "title"]
      ),
      "Should not expect the event parameter matched with the rule"
    )
    XCTAssertFalse(
      rule.isMatched(
        withAsteriskParam: "fb_content[*]",
        eventParameters: ["fb_content_aaa": ["title": "aaaa"]],
        paramPath: ["fb_content[*]", "title"]
      ),
      "Should not expect the event parameter matched with the rule"
    )
  }

  func testIsMatchedWithStringComparision() { // swiftlint:disable:this function_body_length
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorContains,
      paramKey: "fb_content.title",
      linguisticCondition: "hello",
      numericalCondition: nil,
      arrayCondition: nil
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: "worldhelloworld", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: "worldhellworld", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorNotContains)
    XCTAssertFalse(
      rule.isMatched(withStringValue: "worldhelloworld", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: "worldhellworld", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorStartsWith)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "helloworld", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: "worldhelloworld", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorI_Contains)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "worldHELLOworld", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: "worldhellworld", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorI_NotContains)
    XCTAssertFalse(
      rule.isMatched(withStringValue: "worldHELLOworld", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: "worldHELLworld", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorI_StartsWith)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "HELLOworld", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: "worldHELLOworld", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorEqual)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "hello", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: "hellw", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorNotEqual)
    XCTAssertFalse(
      rule.isMatched(withStringValue: "hello", numericalValue: nil),
      "Shoule not expect parameter matched with the value"
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: "hellw", numericalValue: nil),
      "Shoule expect parameter matched with the value"
    )
  }

  func testIsMatchedWithNumberComparision() { // swiftlint:disable:this function_body_length
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorLessThan,
      paramKey: "fb_content.title",
      linguisticCondition: nil,
      numericalCondition: NSNumber(value: 100),
      arrayCondition: nil
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 90)),
      "Shoule expect parameter matched with value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 100)),
      "Shoule not expect parameter matched with value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 101)),
      "Shoule not expect parameter matched with value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorLessThanOrEqual)
    XCTAssertTrue(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 99)),
      "Shoule expect parameter matched with value"
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 100)),
      "Shoule expect parameter matched with value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 100.1)),
      "Shoule not expect parameter matched with value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorGreaterThan)
    XCTAssertTrue(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 101.5)),
      "Shoule expect parameter matched with value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 100)),
      "Shoule not expect parameter matched with value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 99)),
      "Shoule not expect parameter matched with value"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorGreaterThanOrEqual)
    XCTAssertTrue(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 101.5)),
      "Shoule expect parameter matched with value"
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 100)),
      "Shoule expect parameter matched with value"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: nil, numericalValue: NSNumber(value: 99)),
      "Shoule not expect parameter matched with value"
    )
  }

  func testIsMatchedWithArrayComparision() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorIsAny,
      paramKey: "fb_content.title",
      linguisticCondition: nil,
      numericalCondition: nil,
      arrayCondition: ["Abc", "aaa", "ABC", "XXXX"]
    )
    XCTAssertTrue(
      rule.isMatched(withStringValue: "aaa", numericalValue: nil),
      "Shoule expect parameter matched with item in the array"
    )
    XCTAssertFalse(
      rule.isMatched(withStringValue: "bbb", numericalValue: nil),
      "Shoule not expect parameter matched with item in the array"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorI_IsAny)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "abc", numericalValue: nil),
      "Shoule expect parameter matched with item in the array"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorIsNotAny)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "xxxx", numericalValue: nil),
      "Shoule expect parameter matched with item in the array"
    )

    rule.setOperator(AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorI_IsNotAny)
    XCTAssertTrue(
      rule.isMatched(withStringValue: "ab", numericalValue: nil),
      "Shoule expect parameter matched with item in the array"
    )
  }

  func testIsRegexMatch() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorIsAny,
      paramKey: "fb_content.title",
      linguisticCondition: "eylea.us/support/?$|eylea.us/support/?",
      numericalCondition: nil,
      arrayCondition: nil
    )
    XCTAssertTrue(
      rule.isRegexMatch("eylea.us/support"),
      "Should expect parameter matched with regex"
    )
    XCTAssertFalse(
      rule.isRegexMatch("eylea.us.support"),
      "Should not expect parameter matched with regex"
    )
  }

  func testIsRegexMatchWithEmtpyString() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorIsAny,
      paramKey: "fb_content.title",
      linguisticCondition: "",
      numericalCondition: nil,
      arrayCondition: nil
    )
    XCTAssertFalse(
      rule.isRegexMatch("eylea.us.support"),
      "Should not expect parameter matched with regex"
    )
  }

  func testIsRegexMatchWithNullableString() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorIsAny,
      paramKey: "fb_content.title",
      linguisticCondition: nil,
      numericalCondition: nil,
      arrayCondition: nil
    )
    XCTAssertFalse(
      rule.isRegexMatch("eylea.us.support"),
      "Should not expect parameter matched with regex"
    )
  }

  func testIsAnyOf() {
    let rule = AEMAdvertiserSingleEntryRule(
      with: AEMAdvertiserRuleOperator.FBSDKAEMAdvertiserRuleOperatorIsAny,
      paramKey: "fb_content.title",
      linguisticCondition: nil,
      numericalCondition: nil,
      arrayCondition: ["abc", "AAA", "Abc"]
    )
    XCTAssertTrue(
      rule.isAny(of: ["abc", "AAA", "Abc"], stringValue: "AAA", ignoreCase: false),
      "Should expect parameter matched"
    )
    XCTAssertTrue(
      rule.isAny(of: ["abc", "AAA", "Abc"], stringValue: "aaa", ignoreCase: true),
      "Should expect parameter matched"
    )
    XCTAssertTrue(
      rule.isAny(of: ["abc", "AAA", "Abc"], stringValue: "ABC", ignoreCase: true),
      "Should expect parameter matched"
    )
    XCTAssertFalse(
      rule.isAny(of: ["abc", "AAA", "Abc"], stringValue: "aaa", ignoreCase: false),
      "Should not expect parameter matched"
    )
    XCTAssertFalse(
      rule.isAny(of: ["abc", "AAA", "Abc"], stringValue: "ab", ignoreCase: false),
      "Should not expect parameter matched"
    )
  }

  func testSecureCoding() {
    XCTAssertTrue(
      AEMAdvertiserSingleEntryRule.supportsSecureCoding,
      "AEM Advertiser Single Entry Rule should support secure coding"
    )
  }

  func testEncoding() throws {
    let coder = TestCoder()
    let entryRule = SampleAEMData.validAdvertiserSingleEntryRule
    entryRule.encode(with: coder)

    let ruleOperator = coder.encodedObject[Keys.ruleOperator] as? NSNumber
    XCTAssertEqual(
      ruleOperator?.intValue,
      entryRule.operator.rawValue,
      "Should encode the expected operator with the correct key"
    )
    XCTAssertEqual(
      coder.encodedObject[Keys.ruleParamKey] as? String,
      entryRule.paramKey,
      "Should encode the expected param_key with the correct key"
    )
    XCTAssertEqual(
      coder.encodedObject[Keys.ruleStringValue] as? String,
      entryRule.linguisticCondition,
      "Should encode the expected string_value with the correct key"
    )
    let numberValue = try XCTUnwrap(coder.encodedObject[Keys.ruleNumberValue] as? NSNumber)
    XCTAssertTrue(
      entryRule.numericalCondition?.isEqual(to: numberValue) == true,
      "Should encode the expected content with the correct key"
    )
    let arrayValue = try XCTUnwrap(coder.encodedObject[Keys.ruleArrayValue] as? NSArray)
    let expectedArrayValue = try XCTUnwrap(entryRule.arrayCondition as NSArray?)
    XCTAssertEqual(
      arrayValue,
      expectedArrayValue,
      "Should encode the expected array_value with the correct key"
    )
  }

  func testDecoding() {
    let decoder = TestCoder()
    _ = AEMAdvertiserSingleEntryRule(coder: decoder)

    XCTAssertEqual(
      decoder.decodedObject[Keys.ruleOperator] as? String,
      "decodeIntegerForKey",
      "Should decode the expected type for the operator key"
    )
    XCTAssertTrue(
      decoder.decodedObject[Keys.ruleParamKey] is NSString.Type,
      "Should decode the expected type for the param_key key"
    )
    XCTAssertTrue(
      decoder.decodedObject[Keys.ruleStringValue] is NSString.Type,
      "Should decode the expected type for the string_value key"
    )
    XCTAssertTrue(
      decoder.decodedObject[Keys.ruleNumberValue] is NSNumber.Type,
      "Should decode the expected type for the number_value key"
    )
    XCTAssertTrue(
      decoder.decodedObject[Keys.ruleArrayValue] is NSArray.Type,
      "Should decode the expected type for the array_value key"
    )
  }
}

#endif // swiftlint:disable:this file_length
