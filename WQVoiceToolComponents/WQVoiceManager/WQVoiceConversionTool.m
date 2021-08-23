//
//  WQVoiceConversionManager.m
//  WQVoiceToolDemo
//
//  Created by hejinyin on 2017/10/23.
//  Copyright © 2017年 WQMapKit. All rights reserved.
//

#import "WQVoiceConversionTool.h"
#import "WQAmrFileCodec.h"
#import "lame.h"
#import <AVFoundation/AVFoundation.h>
@interface WQVoiceConversionTool()
@property (strong ,nonatomic) NSOperationQueue *operationQueue;
@end

@implementation WQVoiceConversionTool
+(instancetype)manager{
    return [[self alloc] init];
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 5;
    }
    return self;
}
-(NSOperation *)addBlockOperation:(dispatch_block_t)block{
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:block];
    [self.operationQueue addOperation:operation];
    return operation;
}
//MARK: =========== 一步转换 ===========
-(void)voiceConversion:(WQConvertVoiceStyle)style from:(id)fromVoice targetPath:(NSString *)targetPath compeletion:(WQVoiceConversionCompeletion)compeletion{
    __block NSData *convertData = nil;
        dispatch_block_t block = ^{
            convertData = [self _conversion:fromVoice style:style targetPath:targetPath];
        };
        NSOperation *operatio = [self addBlockOperation:block];
        [operatio setCompletionBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                compeletion ?compeletion(nil,convertData):nil;
            });
    
        }];
}
//MARK: =========== 同步转换 ===========
-(NSData *)sync_conversion:(id)fromVoice conversionStyle:(WQConvertVoiceStyle)style targetPath:(NSString *)targetPath{
    id conversionMedia = [self _conversion:fromVoice style:style targetPath:targetPath];
    NSData *convertData ;
    if ([conversionMedia isKindOfClass:[NSData class]]) {
        convertData = conversionMedia;
    }else{
        convertData = [NSData dataWithContentsOfFile:targetPath];
    }
    return  convertData;
}
//MARK: =========== 私有方法 ===========

- (id)_conversion:(id)fromVoice style:(WQConvertVoiceStyle)style targetPath:(NSString *)targetPath{
    id conversionMedia;
    NSData *data ;
    if ([fromVoice isKindOfClass:[NSData class]]) {
        data = fromVoice;
    }else{
        data = [NSData dataWithContentsOfFile:fromVoice];
    }
    
    if (data) {
        switch (style) {
            case WQConvertWavToAmr:
                conversionMedia = EncodeWAVEToAMR(data,1,16);
                break;
            case WQConvertAmrToWav:
                conversionMedia = DecodeAMRToWAVE(data);
                break;
            case WQConvertWavToBase64Amr:
                data = EncodeWAVEToAMR(data,1,16);
                conversionMedia = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
                break;
            case WQConvertBase64AmrToWav:
                data = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
                conversionMedia = DecodeAMRToWAVE(data);
                break;
            case WQConvertCafToMP3:{
                NSString *voicePath;
                if ([fromVoice isKindOfClass:[NSData class]]) {
                    voicePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"temp_%.0f.wav",[NSDate date].timeIntervalSince1970]];
                    [data writeToFile:voicePath atomically:YES];
                    
                }else{
                    voicePath = fromVoice;
                }
                conversionMedia = [self cafToMP3:voicePath targetPath:targetPath];
            }
                break;
            case WQConvertVoiceNone:
            default:
                conversionMedia = data;
                
                break;
        }
        if (style != WQConvertCafToMP3) {
            [self _saveMedia:conversionMedia localPath:targetPath];
        }
    }
    return conversionMedia;
}

- (void)_saveMedia:(NSData *)mediaData localPath:(NSString *)path{
    if (mediaData && path) {
        [mediaData writeToFile:path atomically:YES];
    }
}

//- (void)voiceConversionOperation:(WQConvertVoiceBlock)convertVoice
//                            from:(id)fromVoice
//                      targetPath:(NSString *)targetPath
//                     compeletion:(WQVoiceConversionCompeletion)compeletion{
//    __block NSData *convertData = nil;
//    dispatch_block_t block = ^{
//        
//        NSData *convertData;
//        NSData *data ;
//        if ([fromVoice isKindOfClass:[NSData class]]) {
//            data = fromVoice;
//        }else{
//            data = [NSData dataWithContentsOfFile:fromVoice];
//        }
//        if (data && convertVoice) {
//            convertData = convertVoice(data);
//        }
//    };
//    NSOperation *operatio = [self addBlockOperation:block];
//    [operatio setCompletionBlock:^{
//        dispatch_async(dispatch_get_main_queue(), ^{
//            compeletion ?compeletion(nil,convertData):nil;
//        });
//        
//    }];
//}


//MARK: =========== 格式转换(mp3转换) ===========
/**
 * mp3转码对应的效果较好的参数配置
 *   NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
 [NSNumber numberWithFloat: 15000],AVSampleRateKey, //采样率
 [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
 [NSNumber numberWithInt: 2], AVNumberOfChannelsKey,//通道
 [NSNumber numberWithInt: AVAudioQualityMedium],AVEncoderAudioQualityKey,//音频编码质量
 nil];
 
 *转码工具参数
 lame_t lame = lame_init();
 lame_set_VBR(lame, vbr_default);
 lame_set_num_channels(lame,2);//默认为2双通道
 lame_set_in_samplerate(lame, 15000);//11025.0 采样率要一样的
 lame_set_brate(lame,16);
 lame_set_mode(lame,3);
 lame_set_quality(lame,5); // 2=high 5 = medium 7=low 音质
 lame_init_params(lame);
 
 */
//转换为 mp3 格式的重要代码

- (NSString *)cafToMP3:(NSString *)cafFilePath targetPath:(NSString *)targetPath{
    NSAssert(_recordSetting != nil, @"转MP3的时候录音参数不能为空");
    //这里必须要使用本地路径 如果使用absoluteString 前面带带有file://  fopen打开失败
    //    NSString *cafFilePath = self.recorder.url.path;
    NSString *mp3FilePath;
    if (!targetPath) {
        mp3FilePath = [NSString stringWithFormat:@"%@.mp3",cafFilePath.stringByDeletingPathExtension];
    }else{
        mp3FilePath = targetPath;
    }
    
    
    //开始转换
    
    int read, write;
    //转换的源文件位置
    FILE *pcm = fopen([cafFilePath cStringUsingEncoding:1], "rb");
    //转换后保存的位置
    FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:1], "wb");
    
    if (!mp3 || !pcm) {
        return nil;
    }
    
    const int PCM_SIZE = 8192;
    const int MP3_SIZE = 8192;
    short int pcm_buffer[PCM_SIZE*2];
    unsigned char mp3_buffer[MP3_SIZE];
    int sampleRate = [[_recordSetting objectForKey:AVSampleRateKey] intValue];
    //创建这个工具类
    lame_t lame = lame_init();
    lame_set_in_samplerate(lame, sampleRate);
    lame_set_VBR(lame, vbr_default);
    lame_init_params(lame);
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
    //doWhile 循环
    do {
        read = fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
        if (read == 0){
            //这里面的代码会在最后调用 只会调用一次
            write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            //NSLog(@"read0%d",write);
        }
        else{
            //这个 write 是写入文件的长度 在此区域内会一直调用此内中的代码 一直再压缩 mp3文件的大小,直到不满足条件才退出
            write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            //写入文件  前面第一个参数是要写入的块 然后是写入数据的长度 声道 保存地址
            fwrite(mp3_buffer, write, 1, mp3);
            //NSLog(@"read%d",write);
        }
    } while (read != 0);
#pragma clang diagnostic pop
    lame_close(lame);
    fclose(mp3);
    fclose(pcm);
    
    return mp3FilePath;
}


@end
