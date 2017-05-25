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
//#import "WQHttpTool.h"

typedef NS_ENUM(NSInteger ,WQRecordConvertStyle) {
    WQRecordConvertNone,
    WQRecordConvertWavToAmr,
//    WQRecordConvertBase64,
};

/**
 自定义语音转换上传

 @param recordData 录制的语音
 @return 转换后的文件
 */
typedef NSData *(^WQConvertRecord)(NSData *recordData);

/**
 根据枚举类型将录音文件转换为指定的类型

 @param convertData 转换后的文件
 */
typedef void (^WQConvertRecordFinshed)(NSData *convertData);

/**
 录音完成回调

 @param voicePath 录音文件存放的路径
 @param duration 录音时长
 @return 是否需要删除录音文件
 */
typedef BOOL (^WQRecordFinshBlock)(NSString *voicePath , CGFloat duration, NSError *error);
/** 声音大小回调 */
typedef void (^WQUpdateMetersBlock)(float meterPower);
@interface WQVoiceRecordManager : NSObject
/** 对象需要自己做保存处理 */
+ (instancetype)manager;
/** 通过此方法创建的对象需要自己做保存处理 */
- (instancetype)initWithCache:(WQVoiceCache *)cache;

@property (assign ,nonatomic,readonly,getter=isRecording) BOOL recording;

/** 录音的最短时长 */
@property (assign ,nonatomic) CGFloat minRecordDuration;

@property (strong ,nonatomic) NSDictionary *recordSettings;

/** 录音过程中音量变化回调(需要在录音之前设置) */
- (void)setUpdateMetersBlock:(WQUpdateMetersBlock)updateMeters;

/** 带声音变化回调的 */
- (NSError *)recordPathExtension:(NSString *)pathExtension metersUpdate:(WQUpdateMetersBlock)metersUpdate;

- (NSError *)recordWithPathExtension:(NSString *)pathExtension;
/** 可以带后缀名 */
- (NSError *)recordWithName:(NSString *)name;

//- (NSError *)recordWithName:(NSString *)name
//             stopedCallback:(WQRecordFinshBlock)callBack;
/**这里停止直接回调之前定义好的回调*/
//- (void)stop;
- (void)stopRecord:(WQRecordFinshBlock)recordFinsh;
/** 外界主动打断录音 */
-(void)interruptRecord;
/** 用于语音转换之后上传(主要用于内部) */
- (void)setConvertRecordStyle:(WQRecordConvertStyle)style;
- (void)setConvertRecordOperation:(WQConvertRecord)convertOperation;

/** 转换录音文件格式(主要用于外部) */
- (void)addConvertRecord:(WQRecordConvertStyle)style down:(WQConvertRecordFinshed)convertFinshed;
/** 自定义转换录音文件格式(主要用于外部) */
- (void)addConvertRecordOperation:(WQConvertRecord)convertOperation down:(WQConvertRecordFinshed)convertFinshed;

/** 停止录音并发送到服务器 */
//- (void)stopAndPost:(NSString *)path
//             params:(NSDictionary *)params
//            success:(HttpSuccessBlock)success
//            failure:(HttpFailureBlock)failure;
///** 将录音完的文件发送给服务器 */
//- (void)post:(NSString *)path
//      params:(NSDictionary *)params
//     success:(HttpSuccessBlock)success
//     failure:(HttpFailureBlock)failure;

/** 根据上传服务器返回后的路径移动文件 */
- (void)moveFilePathWithURL:(NSString *)urlStr;
@end
