//
//  WQVoiceDownloaderOperation.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WQVoiceDownloader.h"

static NSString * _Nonnull const WQVoiceDownFinshedNotification = @"WQVoiceDownFinshedNotification";
@interface WQVoiceDownloadOperation : NSOperation
@property (copy ,nonatomic,readonly,nonnull) NSURL *url;

- (nullable instancetype)initWithURL:(nonnull NSURL *)url convertStyle:(WQConvertVoiceStyle)style convertBlock:(nullable WQConvertVoiceBlock)block compelete:(nullable WQVoiceDowonFinshBlock)downBlock;
@end
