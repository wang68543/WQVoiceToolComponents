//
//  WQVoiceDownloader.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  单例全局唯一

#import <Foundation/Foundation.h>
#import "WQVoiceCache.h"

typedef NS_ENUM(NSInteger,WQConvertVoiceStyle) {
    WQConvertVoiceNone,
    WQConvertVoiceAmrToWav,
    WQConvertBase64ToWav,
    WQConvertBase64AmrToWav,
};

typedef void (^WQVoiceDowonFinshBlock)(NSData *voiceData,WQVoiceCacheType cacheType,NSString *urlStr,NSError *error);
/**
 音频格式转换(可能下载的格式iOS无法播放所以需要转换)
 
 @param downData 下载下来的原始数据
 @return 转换后的数据
 */
typedef NSData * (^WQConvertVoiceBlock)(NSData *downData);

@interface WQVoiceDownloader : NSObject
+ (instancetype)sharedVoiceDownloader;


@property (assign ,nonatomic) NSInteger maxConcurrentDownloads;

/**自定义初始化*/
- (void)downloadVoiceWithURL:(NSURL *)url
                   completed:(WQVoiceDowonFinshBlock)compeletedBlock;

- (void)setConvertVoiceStyle:(WQConvertVoiceStyle)style;
/**下载完成之后转换语音再播放*/
- (void)setConvertWithBlock:(WQConvertVoiceBlock)block;


- (void)cancelAllOperations;
@end
