//
//  WQVoiceDownloaderOperation.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceDownloadOperation.h"
#import "amrFileCodec.h"
@interface WQVoiceDownloadOperation()
@property (copy ,nonatomic) WQVoiceDowonFinshBlock downFinshBlock;
@property (copy ,nonatomic) WQConvertVoiceBlock converVoiceBlock;
@property (assign ,nonatomic) WQConvertVoiceStyle style;
@end
@implementation WQVoiceDownloadOperation
-(instancetype)initWithURL:(NSURL *)url convertStyle:(WQConvertVoiceStyle)style convertBlock:(WQConvertVoiceBlock)block compelete:(WQVoiceDowonFinshBlock)downBlock{
    if(self = [super init]){
        _style = style;
        _converVoiceBlock = [block copy];
        _downFinshBlock = [downBlock copy];
        _url = url;
    }
    return self;
}
-(void)main{
    @autoreleasepool {
        
        do {
//            if(!_url){
//                [self postDownFinshedNotification];
//                 _downFinshBlock ? _downFinshBlock(nil,WQVoiceCacheTypeNone,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"路径为空"}],YES):nil;
//                break;
//            }
            if(self.isCancelled)return;
            NSData *data;
//            if(self.style == WQConvertBase64ToWav){
//                data = [NSData ]
//            }else{
                data = [NSData dataWithContentsOfURL:_url];
//            }
            
            if(!data){
                [self postDownFinshedNotification];
                _downFinshBlock ? _downFinshBlock(nil,WQVoiceCacheTypeNone,[_url absoluteString],[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"文件下载失败"}]):nil;
                break;
            }
            if(self.isCancelled)return;
            NSData *convertData = nil;
            if(data){
                if(_converVoiceBlock){
                    //TODO: 同步Block意思是block中代码执行完了就返回 而不需要等待其它的操作完成
                    //同步block 顺序执行
                    convertData =  _converVoiceBlock(data);
                }else{
                    switch (_style) {
                       
                        case WQConvertBase64ToWav:
                            convertData = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
                            break;
                        case WQConvertBase64AmrToWav:
                            data = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
                        case WQConvertVoiceAmrToWav:
                            convertData = DecodeAMRToWAVE(data);
                            break;
                        case WQConvertVoiceNone:
                        default:
                            convertData = data;
                            break;
                    }
                }
            }
           
            [self postDownFinshedNotification];
            _downFinshBlock? _downFinshBlock(convertData,WQVoiceCacheTypeNone,[_url absoluteString],nil):nil;
        } while (NO);
     
        
    }
}

-(void)postDownFinshedNotification{
    [[NSNotificationCenter defaultCenter] postNotificationName:WQVoiceDownFinshedNotification object:self];
}
@end
