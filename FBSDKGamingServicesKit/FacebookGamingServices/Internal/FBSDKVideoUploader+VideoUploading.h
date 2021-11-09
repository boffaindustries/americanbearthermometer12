/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import <Foundation/Foundation.h>

#import "FBSDKVideoUploader.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FBSDKVideoUploading;

@interface FBSDKVideoUploader (VideoUploading) <FBSDKVideoUploading>
@end

NS_ASSUME_NONNULL_END
