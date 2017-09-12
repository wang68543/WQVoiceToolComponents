//
//  WQVoiceRecorder.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceRecordManager.h"
#import <AVFoundation/AVFoundation.h>
#import "amrFileCodec.h"
#import "lame.h"

#import "WQVoicePlayManager.h"

@interface WQVoiceRecordManager()
@property (strong ,nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic, strong) AVAudioRecorder *recorder;

@property (copy ,nonatomic) NSString *recordKey;
/**语音格式转换*/
@property (assign ,nonatomic) WQRecordConvertStyle convertStyle;
@property (copy ,nonatomic) WQConvertRecord converRecordBlock;
@property (copy ,nonatomic) WQRecordFinshBlock stopCallback;
/**监测说话声音大小*/
@property (nonatomic, strong) CADisplayLink *timer;
/**声音大小回调*/
@property (copy ,nonatomic) WQUpdateMetersBlock metersBlock;
@end
@implementation WQVoiceRecordManager

+(instancetype)manager{
    //TODO: 这里如果使用静态变量 当前对象就不会释放一直存在
//    static WQVoiceRecordManager *_instance;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        _instance = [[self alloc] initWithCache:[WQVoiceCache sharedCache]];
//    });
//    return _instance;
    return [[self alloc] initWithCache:[WQVoiceCache sharedCache]];
}
-(instancetype)initWithCache:(WQVoiceCache *)cache{
    if(self = [super init]){
        _voiceCache = cache;
        _minRecordDuration = 2.0;
        _recordSettings = [self defaultRecordSetting];
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 2;
        _convertStyle = WQRecordConvertNone;
    }
    return self;
}

-(void)addJobToQueue:(void (^)(void))block{
    [self.operationQueue addOperationWithBlock:block];
}
-(NSOperation *)addBlockOperation:(dispatch_block_t)block{
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:block];
    [self.operationQueue addOperation:operation];
    return operation;
}
-(BOOL)isRecording{
    return self.recorder&& self.recorder.isRecording;
}
/**默认的录音设置*/
- (NSDictionary*)defaultRecordSetting{
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: 8000.0],AVSampleRateKey, //采样率
                                   [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
                                   [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,//采样位数 默认 16
                                   [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,//通道的数目
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,//大端还是小端 是内存的组织方式
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,//采样信号是整数还是浮点数
                                   //                                   [NSNumber numberWithInt: AVAudioQualityMedium],AVEncoderAudioQualityKey,//音频编码质量
                                   nil];
    return recordSetting;
}
-(NSError *)recordPathExtension:(NSString *)pathExtension metersUpdate:(WQUpdateMetersBlock)metersUpdate{
    self.metersBlock = metersUpdate;
    return [self recordWithPathExtension:pathExtension];
}
-(NSString *)defaultRecordName{
    NSString *recordName = [UIDevice currentDevice].identifierForVendor.UUIDString;
    recordName = [recordName stringByReplacingOccurrencesOfString:@"-" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, recordName.length-1)];
    recordName = [NSString stringWithFormat:@"%@%lf",recordName,[[NSDate date] timeIntervalSince1970]];
  return  [recordName stringByReplacingOccurrencesOfString:@"." withString:@""];
}
-(NSError *)recordWithPathExtension:(NSString *)pathExtension{
  return  [self recordWithName:[[self defaultRecordName] stringByAppendingPathExtension:pathExtension]];
}
-(NSError *)recordWithName:(NSString *)name{
    NSError *error;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if(error){
        return error;
    }
    NSString *key = [_voiceCache cacheKeyForURL:name];
    _recordKey = key;
    NSString *path = [_voiceCache defaultCachePathForKey:key];
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path] settings:_recordSettings error:&error];
    if(error || ![self.recorder prepareToRecord]){
        if(!error){
            error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"开启录音失败"}];
        }
        return error;
    }
    // 开启分贝测量功能
    if(_metersBlock){
        self.recorder.meteringEnabled = YES;
        [self addUpdateMetersTimer];
    }
    [self.recorder record];
    
    return nil;
    
}
- (void)addUpdateMetersTimer{
    self.timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateRecordMeters)];
    [self.timer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)removeUpdateMetersTimer{
    if(self.timer){
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)updateRecordMeters{
    if(self.isRecording){
        [self.recorder updateMeters];
        // 如果分贝不超过-20 几乎为静音 peakPowerForChannel:音量的最大值
        double power = [self.recorder averagePowerForChannel:0];
//        double power = pow(10, [self.recorder averagePowerForChannel:0]*0.05);//使得power的取值范围是0~1
        _metersBlock?_metersBlock(power):nil;
    }else{
        [self removeUpdateMetersTimer];
    }
    
}
//MARK: =========== 录音文件读取 ===========
-(NSString *)voiceRecordPath{
    if(!_recordKey|| _recordKey.length <= 0 ){
        return nil;
    }
    return [_voiceCache defaultCachePathForKey:_recordKey];
}
-(NSData *)getRecordData{
    return [NSData dataWithContentsOfFile:[self voiceRecordPath]];
}
-(void)setConvertRecordStyle:(WQRecordConvertStyle)style{
    _convertStyle = style;
    _converRecordBlock = nil;
}
-(void)setConvertRecordOperation:(WQConvertRecord)convertOperation{
    _converRecordBlock = [convertOperation copy];
}
- (void)setUpdateMetersBlock:(WQUpdateMetersBlock)updateMeter{
    _metersBlock = [updateMeter copy];
}

//MARK: =========== 音频转换 ===========

//提供几种基本的语音类型转换
-(void)addConvertRecord:(WQRecordConvertStyle)style down:(WQConvertRecordFinshed)convertFinshed{
     __block NSData *convertData = nil;
   NSData *data = [self getRecordData];
    dispatch_block_t block = ^{
        if (data) {
            switch (style) {
                case WQRecordConvertWavToAmr:
                {
                    convertData = EncodeWAVEToAMR(data,1,16);
                }
                    break;
                case WQRecordConvertCafToMP3:
                {
                    NSString *mp3FilePath = [self cafToMP3:[self voiceRecordPath]];
                    convertData = [NSData dataWithContentsOfFile:mp3FilePath];
                }
                    break;
                case WQRecordConvertNone:
                default:
                    convertData = data;
                    break;
            }
        }
    
    };
    NSOperation *operatio = [self addBlockOperation:block];
    [operatio setCompletionBlock:^{
        convertFinshed?convertFinshed(data,convertData):nil;
    }];
}

//block回调自定义类型转换
- (void)addConvertRecordOperation:(WQConvertRecord)convertOperation down:(WQConvertRecordFinshed)convertFinshed{
    NSData *data = [self getRecordData];
    if (!data){
        convertFinshed?convertFinshed(nil,nil):nil;
        return;
    }
     __block NSData *convertData;
    NSOperation *operatio = [self addBlockOperation:^{
       convertData = convertOperation(data);
    }];
    [operatio setCompletionBlock:^{
        convertFinshed?convertFinshed(data,convertData):nil;
    }];
}

- (void)cancelRecord{
    [self removeUpdateMetersTimer];
    if(self.isRecording){
        [self.recorder stop];
        [self.recorder deleteRecording];
    }
}

-(void)stopRecord:(WQRecordFinshBlock)recordFinsh{
    [self removeUpdateMetersTimer];
    BOOL deleteRecord = NO;
    if(self.isRecording){
        CGFloat duration = self.recorder.currentTime;
        [self.recorder stop];
        if(duration < _minRecordDuration){
            [self.recorder deleteRecording];
            if(recordFinsh){
                recordFinsh(nil,duration,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"录音时间太短"}]);
            }
        }else{
            NSString *recordPath = [self.recorder.url absoluteString];
            if(recordFinsh){
                deleteRecord = recordFinsh(recordPath,duration,nil);
                if(deleteRecord){
                    [self.recorder deleteRecording];
                }
            }
        }
    }else{
        if(recordFinsh){
            recordFinsh(nil,0.0,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"当前没有录音"}]);
        }
    }
    self.recorder = nil;
}
-(void)stopFinshConvertRecord:(WQStopFinshConvert)stopAndConvert{
    __weak typeof(self) weakSelf = self;
    [self stopRecord:^BOOL(NSString *voicePath, CGFloat duration, NSError *error) {
        if(stopAndConvert){
            if(weakSelf.convertStyle != WQRecordConvertNone){
                [weakSelf addConvertRecord:weakSelf.convertStyle down:^(NSData *originData, NSData *conversionData) {
                    stopAndConvert(voicePath,originData,conversionData,duration,error);
                }];
            }else if(weakSelf.converRecordBlock){
                [weakSelf addConvertRecordOperation:weakSelf.converRecordBlock down:^(NSData *originData, NSData *conversionData) {
                    stopAndConvert(voicePath,originData,conversionData,duration,error);
                }];
            }else{
                NSData *originData = [self getRecordData];
               stopAndConvert(voicePath,originData,nil,duration,error);
            }
            
        }
        return NO;
    }];
}
//-(void)post:(NSString *)path params:(NSDictionary *)params success:(HttpSuccessBlock)success failure:(HttpFailureBlock)failure{
//    __weak typeof(self) weakSelf = self;
//    if(self.converRecordBlock){
//        [self addConvertRecordOperation:self.converRecordBlock down:^(NSData *convertData) {
//             [weakSelf uploadAudioData:convertData path:path params:params success:success failure:failure];
//        }];
//    }else{
//        if(self.convertStyle == WQRecordConvertNone){
//            [self uploadAudioData:[self getRecordData] path:path params:params success:success failure:failure];
//        }else{
//            [self addConvertRecord:self.convertStyle down:^(NSData *convertData) {
//                [weakSelf uploadAudioData:convertData path:path params:params success:success failure:failure];
//            }];
//        }
//    }
//    
//}
//-(void)uploadAudioData:(NSData *)data path:(NSString *)path params:(NSDictionary *)params success:(HttpSuccessBlock)success failure:(HttpFailureBlock)failure{
//    if(!data){
//        failure?failure(nil,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"文件不存在"}]):nil;
//        return;
//    }
//    [WQHttpTool postAudioData:data path:path params:params progress:NULL success:success failure:failure];
//}
-(void)moveFilePathWithURL:(NSString *)urlStr{
    dispatch_block_t block = ^{
        NSString *targetKey = [_voiceCache cacheKeyForURL:urlStr];
        [[NSFileManager defaultManager] moveItemAtPath:[_voiceCache defaultCachePathForKey:_recordKey] toPath:[_voiceCache defaultCachePathForKey:targetKey] error:nil];
    };
    [self addJobToQueue:block];
}

-(void)dealloc{
    if(self.recorder.isRecording){
        [self.recorder stop];
        [self.recorder deleteRecording];
    }
    NSLog(@"===录音工具销毁了");
}

//MARK: =========== 格式转换(mp3转换) ===========

//转换为 mp3 格式的重要代码
- (NSString *)cafToMP3:(NSString *)cafFilePath{
    
    //这里必须要使用本地路径 如果使用absoluteString 前面带带有file://  fopen打开失败
//    NSString *cafFilePath = self.recorder.url.path;
    NSString *mp3FilePath = [NSString stringWithFormat:@"%@.mp3",cafFilePath.stringByDeletingPathExtension];
    
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
    int sampleRate = [[_recordSettings objectForKey:AVSampleRateKey] intValue];
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
