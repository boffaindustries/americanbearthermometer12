/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "TargetConditionals.h"

#if !TARGET_OS_TV

 #import <Foundation/Foundation.h>

 #import "FBAEMConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AEMInvocation)
@interface FBAEMInvocation : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly, copy) NSString *campaignID;

@property (nonatomic, readonly, copy) NSString *ACSToken;

@property (nullable, nonatomic, readonly, copy) NSString *ACSSharedSecret;

@property (nullable, nonatomic, readonly, copy) NSString *ACSConfigID;

@property (nullable, nonatomic, readonly, copy) NSString *businessID;

@property (nonatomic, readonly, assign) BOOL isTestMode;

@property (nonatomic, readonly, assign) BOOL hasSKAN;

@property (nonatomic, readonly, copy) NSDate *timestamp;

@property (nonatomic, readonly, copy) NSString *configMode;

/** The unique identifier of the config, it's the same as config's validFrom */
@property (nonatomic, readonly, assign) NSInteger configID;

@property (nonatomic, readonly) NSMutableSet<NSString *> *recordedEvents;

@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, id> *> *recordedValues;

@property (nonatomic, readonly, assign) NSInteger conversionValue;

@property (nonatomic, readonly, assign) NSInteger priority;

@property (nullable, nonatomic, readonly) NSDate *conversionTimestamp;

@property (nonatomic, assign) BOOL isAggregated;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (nullable instancetype)invocationWithAppLinkData:(nullable NSDictionary<id, id> *)applinkData;

- (BOOL)attributeEvent:(NSString *)event
              currency:(nullable NSString *)currency
                 value:(nullable NSNumber *)value
            parameters:(nullable NSDictionary<NSString *, id> *)parameters
               configs:(nullable NSDictionary<NSString *, NSArray<FBAEMConfiguration *> *> *)configs;

- (BOOL)updateConversionValueWithConfigs:(nullable NSDictionary<NSString *, NSArray<FBAEMConfiguration *> *> *)configs;

- (BOOL)isOutOfWindowWithConfigs:(nullable NSDictionary<NSString *, NSArray<FBAEMConfiguration *> *> *)configs;

- (nullable NSString *)getHMAC:(NSInteger)delay;

@end

NS_ASSUME_NONNULL_END

#endif
