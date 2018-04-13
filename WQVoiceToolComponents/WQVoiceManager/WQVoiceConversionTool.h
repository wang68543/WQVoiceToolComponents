//
//  WQVoiceConversionManager.h
//  WQVoiceToolDemo
//
//  Created by hejinyin on 2017/10/23.
//  Copyright © 2017年 WQMapKit. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger,WQConvertVoiceStyle) {
    WQConvertVoiceNone,
    WQConvertAmrToWav,
    WQConvertWavToAmr,
    WQConvertWavToBase64Amr,
    WQConvertBase64AmrToWav,
    WQConvertCafToMP3,
};

//
//typedef NS_ENUM(NSInteger ,WQRecordConvertStyle) {
//    WQRecordConvertNone,
//    WQRecordConvertWavToAmr,
//    /** caf转mp3 在录制的时候必须为双声道不然转出来的声音效果很差*/
//    WQRecordConvertCafToMP3,//caf格式转为mp3
//    //    WQRecordConvertBase64,
//};


/**
 转换完成

 @param error 转换是否出错
 @param conversionMedia 转换后的音频本地路径或者文件
 */
typedef void (^WQVoiceConversionCompeletion) (NSError *error , id conversionMedia);

/**
 自定义语音转换上传 (必须同步不能异步)
 
 @param voiceMedia 音频文件可能是本地路径或者是NSData
 @return 转换后的文件
 */
typedef NSData *(^WQConvertVoiceBlock)(id voiceMedia);


@interface WQVoiceConversionTool : NSObject
+(instancetype)manager;

/** 录音的参数(用于MP3转换) */
@property (strong  ,nonatomic) NSDictionary *recordSetting;
/**
 音频转换

 @param style 转换风格
 @param fromVoice 源音频路径或NSData
 @param targetPath 转换后文件存储的根路径 (为空就不存储到本地)
 @param compeletion 转换完成回调 (子线程回调的)
 */
- (void)voiceConversion:(WQConvertVoiceStyle)style
                   from:(id)fromVoice
             targetPath:(NSString *)targetPath
            compeletion:(WQVoiceConversionCompeletion)compeletion;

/**
  同步转换

 @param fromVoice 源音频路径或NSData
 @param style 转换风格
 @param targetPath 转换后文件存储的根路径 (为空就不存储到本地)
 @return 转换完成的数据
 */
- (NSData *)sync_conversion:(id)fromVoice
             conversionStyle:(WQConvertVoiceStyle)style
                  targetPath:(NSString *)targetPath;
//
///**
// 音频转换
// 
// @param convertVoice 自定义转换操作
// @param fromVoice 源音频路径或NSData
// @param targetPath 转换后文件存储的根路径 (为空就不存储到本地)
// @param compeletion 转换完成回调 (子线程回调的)
// */
//- (void)voiceConversionOperation:(WQConvertVoiceBlock)convertVoice
//                            from:(id)fromVoice
//                      targetPath:(NSString *)targetPath
//                     compeletion:(WQVoiceConversionCompeletion)compeletion;


@end
