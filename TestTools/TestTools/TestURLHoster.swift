/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import FBSDKCoreKit

public final class TestURLHoster: URLHosting {
  public var capturedHost: String?
  public var capturedHostPrefix: String?
  public var capturedPath: String?
  public var capturedQueryParameters: [String: Any]?
  public var stubbedURL: URL

  public init(url: URL) {
    stubbedURL = url
  }

  public func appURL(
    withHost host: String,
    path: String,
    queryParameters: [String: Any],
    error errorRef: NSErrorPointer
  ) -> URL {
    capturedHost = host
    capturedPath = path
    capturedQueryParameters = queryParameters
    return stubbedURL
  }

  public func facebookURL(
    withHostPrefix hostPrefix: String,
    path: String,
    queryParameters: [String: Any],
    error errorRef: NSErrorPointer
  ) -> URL {
    capturedHostPrefix = hostPrefix
    capturedPath = path
    capturedQueryParameters = queryParameters
    return stubbedURL
  }
}
