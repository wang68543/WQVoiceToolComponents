//
//  WQVoiceRecorder.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "WQVoiceCache.h"
#import "WQVoiceConversionTool.h"
/**
 录音完成回调

 @param voicePath 录音文件存放的路径
 @param duration 录音时长
 */
typedef void (^WQRecordFinshBlock)(NSString *voicePath , CGFloat duration, NSError *error);

/**
 录音并按照之前的设定进行转换

 @param voicePath 录音原始路径
 @param conversionMedia 转换之后的路径或者NSData
 @param duration 录音时长
 @param error 错误信息
 */
typedef void (^WQStopFinshConvert) (NSString *voicePath, id conversionMedia,CGFloat duration ,NSError *error);
/** 声音大小回调 */
typedef void (^WQUpdateMetersBlock)(float meterPower);
@interface WQVoiceRecordManager : NSObject
/** 对象需要自己做保存处理 */
+ (instancetype)manager;
/** 通过此方法创建的对象需要自己做保存处理 */
- (instancetype)initWithCache:(WQVoiceCache *)cache;

@property (strong ,nonatomic,readonly) WQVoiceCache *voiceCache;

@property (assign ,nonatomic,readonly,getter=isRecording) BOOL recording;

@property (strong  ,nonatomic,readonly) WQVoiceConversionTool *conversionTool;

/** 含默认录音设置 */
@property (strong ,nonatomic) NSDictionary *recordSettings;

/** 指定录音路径 */
- (NSError *)recordWithPath:(NSString *)recordPath;
/**
 录音

 @param recordPath 录音存放路径
 @param recordSettings 录音设置
 @param metersUpdate 录音音量变化
 @return 录音是否成功
 */
- (NSError *)record:(NSString *)recordPath
     recordSettings:(NSDictionary *)recordSettings
       metersUpdate:(WQUpdateMetersBlock)metersUpdate;
/** 取消当前录音并删除录音文件 */
- (void)cancelRecord;
/** 这里不带转换功能 */
- (void)stopRecord:(WQRecordFinshBlock)recordFinsh;

/** 停止录音并根据WQRecordConvertStyle 或者 WQConvertRecord进行转换 */
- (void)stopRecordToConversion:(WQConvertVoiceStyle)style compeletion:(WQStopFinshConvert)compeletion;

@end
