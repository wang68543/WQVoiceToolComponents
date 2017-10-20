//
//  WQVoiceDownloaderOperation.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceDownloadOperation.h"
#import "amrFileCodec.h"
@interface WQVoiceDownloadOperation(){
    NSString *_cacheKey;
}


/** 操作选项 */
@property (assign ,nonatomic,readonly) WQVoiceOptions options;


@property (copy ,nonatomic) WQVoiceCacheCompleteBlock completeBlock;
@property (copy ,nonatomic) WQConvertVoiceBlock convertVoiceBlock;
@property (copy ,nonatomic) WQVoiceDownProgressBlock progressBlock;
@property (copy ,nonatomic) WQVoiceDownloadCompleteBlock downloadComplete;
@property (copy ,nonatomic) dispatch_block_t cancelBlock;

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run
// the task associated with this operation
@property (weak, nonatomic) NSURLSession *unownedSession;

@property (strong, atomic) NSThread *thread;
@property (strong, nonatomic) NSMutableData *voiceData;
/** 文件输出流 (直接将数据写到磁盘上解决大文件占用内存问题)*/
@property (nonatomic, strong) NSOutputStream *outputStream;

@end
@implementation WQVoiceDownloadOperation
//TODO: 必须重写start、main、isExecuting、isFinished、isAsynchronous 否则operation 无法自动释放
@synthesize executing = _executing;
@synthesize finished = _finished;

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}
- (BOOL)isAsynchronous {
    return YES;
}
-(void)setConvertVoiceOperationBlock:(WQConvertVoiceBlock)convertOperation{
    self.convertVoiceBlock = convertOperation;
}
-(instancetype)initWithRequest:(NSURLRequest *)request inSession:(NSURLSession *)session options:(WQVoiceOptions)options progress:(WQVoiceDownProgressBlock)progressBlock complete:(WQVoiceDownloadCompleteBlock)completeBlock cancelBlock:(dispatch_block_t)cancelBlock{
    if(self = [super init]){
        _request = [request copy];
        _unownedSession = session;
        _progressBlock = [progressBlock copy];
        _downloadComplete = [completeBlock copy];
        
        _cancelBlock = [cancelBlock copy];
        
        _options = options;
        /** fractionCompleted 完成的比例(0~1小数形式);
         * localizedDescription 完成百分比(百分比形式);
         * localizedAdditionalDescription 完成的大小 ;
         */
        _downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        _downloadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
        
        _executing = NO;
        _finished = NO;
        
    }
    return self;
}

-(WQVoiceCache *)voiceCache{
    if(!_voiceCache){
        _voiceCache = [WQVoiceCache sharedCache];
    }
    return _voiceCache;
}
- (void)done{
    self.finished = YES;
    self.executing = NO;
    [self reset];
}
- (void)reset{
//    [self cleanUpProgressForTask:_dataTask];
    self.cancelBlock = nil;
    self.convertVoiceBlock = nil;
    _downloadProgress = nil;

    self.voiceData = nil;
    if(self.outputStream){
        if(self.outputStream.streamStatus < NSStreamStatusClosed){
            [self.outputStream close];
        }
        self.outputStream = nil;
    }
    self.completeBlock = nil;
    _cacheKey = nil;
    _voiceCache = nil;
}

-(void)start{
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }
         _dataTask = [self.unownedSession dataTaskWithRequest:self.request];
        self.executing = YES;
        [self setupProgressForTask:_dataTask];
        
        self.thread = [NSThread currentThread];
    }
    [self.dataTask resume];
    
    if (self.dataTask) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStartNotification object:self];
//        });
    }
    else {
        if (self.downloadComplete) {
            self.downloadComplete(nil, nil , [NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Connection can't be initialized"}], YES);
        }
    }
    
}

- (void)cancel {
    @synchronized (self) {
        if (self.thread) {
            [self performSelector:@selector(cancelInternalAndStop) onThread:self.thread withObject:nil waitUntilDone:NO];
        }
        else {
            [self cancelInternal];
        }
    }
}


- (void)cancelInternalAndStop {
    if (self.isFinished) return;
    [self cancelInternal];
}

- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];
    if (self.cancelBlock) self.cancelBlock();
    
    if (self.dataTask) {
        [self.dataTask cancel];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:self];
//        });
        
        // As we cancelled the connection, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }
    
    [self reset];
}
#pragma mark -- 音频转换 
-(NSData *)convertVoiceOperationWithOrignalData:(NSData *)originalData{
    NSData *convertData = nil;
    if(originalData){
        if(_convertVoiceBlock){
            //TODO: 同步Block意思是block中代码执行完了就返回 而不需要等待其它的操作完成
            //同步block 顺序执行
            convertData =  _convertVoiceBlock(originalData);
        }else{
            switch (_convertStyle) {
                    
                case WQConvertBase64ToWav:
                    convertData = [[NSData alloc] initWithBase64EncodedData:originalData options:NSDataBase64DecodingIgnoreUnknownCharacters];
                    break;
                case WQConvertBase64AmrToWav:
                    convertData = [[NSData alloc] initWithBase64EncodedData:originalData options:NSDataBase64DecodingIgnoreUnknownCharacters];
                case WQConvertVoiceAmrToWav:
                    convertData = DecodeAMRToWAVE(originalData);
                    break;
                case WQConvertVoiceNone:
                default:
                    convertData = originalData;
                    break;
            }
        }
    }
    return convertData;
}
#pragma mark - NSProgress Tracking

- (void)setupProgressForTask:(NSURLSessionTask *)task {
    __weak __typeof__(task) weakTask = task;
 
    self.downloadProgress.totalUnitCount = task.countOfBytesExpectedToReceive;
    [self.downloadProgress setCancellable:YES];
    [self.downloadProgress setCancellationHandler:^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask cancel];
    }];
    [self.downloadProgress setPausable:YES];
    [self.downloadProgress setPausingHandler:^{
        __typeof__(weakTask) strongTask = weakTask;
        [strongTask suspend];
    }];
    
 
    if (@available(iOS 9.0, *)) {
        [self.downloadProgress setResumingHandler:^{
            __typeof__(weakTask) strongTask = weakTask;
            [strongTask resume];
        }];
    }
    [task addObserver:self
           forKeyPath:NSStringFromSelector(@selector(countOfBytesReceived))
              options:NSKeyValueObservingOptionNew
              context:NULL];
    [task addObserver:self
           forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))
              options:NSKeyValueObservingOptionNew
              context:NULL];
      // 注册一个监听器  KVO  progress属性更改会调用
    [self.downloadProgress addObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               options:NSKeyValueObservingOptionNew
                               context:NULL];
}

- (void)cleanUpProgressForTask:(NSURLSessionTask *)task {
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesReceived))];
    [task removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))];
    [self.downloadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([object isKindOfClass:[NSURLSessionTask class]] || [object isKindOfClass:[NSURLSessionDownloadTask class]]) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesReceived))]) {
            self.downloadProgress.completedUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))]) {
            self.downloadProgress.totalUnitCount = [change[NSKeyValueChangeNewKey] longLongValue];
        }
    }
    else if ([object isEqual:self.downloadProgress]) {
        if (self.progressBlock) {
            self.progressBlock(object);
        }
    }
   
}


#pragma mark - NSURLSessionDataDelegate


/**
 当发送的请求, 第一次接受到响应的时候调用,
 
 @param completionHandler 系统传递给我们的一个回调代码块, 我们可以通过这个代码块, 来告诉系统,如何处理, 接下来的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    
//    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//    self.downloadProgress.totalUnitCount = [httpResponse.allHeaderFields[@"Content-Length"] longLongValue];
//    if (httpResponse.allHeaderFields[@"Content-Range"]) {
//        NSString *rangeStr = httpResponse.allHeaderFields[@"Content-Range"] ;
//        self.downloadProgress.totalUnitCount = [[[rangeStr componentsSeparatedByString:@"/"] lastObject] longLongValue];
//        
//    }

    
    
    // 判断, 本地的缓存大小 与 文件的总大小
    // 缓存大小 == 文件的总大小 下载完成 -> 移动到下载完成的文件夹
//    if (_tmpFileSize == _expectedSize) {
//        NSLog(@"文件已经下载完成, 移动数据");
//        // 移动临时缓存的文件 -> 下载完成的路径
//        [XMGDownLoaderFileTool moveFile:self.tmpFilePath toPath:self.cacheFilePath];
//        self.state = XMGDownLoaderStateSuccess;
//        // 取消请求
//        completionHandler(NSURLSessionResponseCancel);
//        return;
//    }
    
//    if (_tmpFileSize > _totalFileSize) {
//        
//        NSLog(@"缓存有问题, 删除缓存, 重新下载");
//        // 删除缓存
//        [XMGDownLoaderFileTool removeFileAtPath:self.tmpFilePath];
//        
//        // 取消请求
//        completionHandler(NSURLSessionResponseCancel);
//        
//        // 重新发送请求  0
//        [self downLoadWithURL:response.URL offset:0];
//        return;
//        
//    }
    
    // 继续接收数据,什么都不要处理
    if (![response respondsToSelector:@selector(statusCode)] || ([((NSHTTPURLResponse *)response) statusCode] < 400 && [((NSHTTPURLResponse *)response) statusCode] != 304)) {
        NSInteger expected = response.expectedContentLength > 0 ? (NSInteger)response.expectedContentLength : 0;
       
        if(self.options&WQVoiceDownloadCacheInStream){
            _cacheKey = [self.voiceCache cacheKeyForURL:[self.request.URL absoluteString]];
            //开启输出流
           self.outputStream = [NSOutputStream outputStreamToFileAtPath:[[WQVoiceCache voiceCacheTempPath] stringByAppendingPathComponent:_cacheKey] append:YES];
             [self.outputStream open];
        }else{
            self.voiceData = [[NSMutableData alloc] initWithCapacity:expected];
        }
    }
    else {
        NSUInteger code = [((NSHTTPURLResponse *)response) statusCode];
        
        //This is the case when server returns '304 Not Modified'. It means that remote image is not changed.
        //In case of 304 we need just cancel the operation and return cached image from the cache.
        if (code == 304) {
            [self cancelInternal];
        } else {
            [self.dataTask cancel];
        }
   
        if (self.downloadComplete) {
            self.downloadComplete(nil, nil , [NSError errorWithDomain:NSURLErrorDomain code:[((NSHTTPURLResponse *)response) statusCode] userInfo:nil], YES);
        }
        [self done];
    }
    
    if (completionHandler) {
        completionHandler(NSURLSessionResponseAllow);
    }

}

// 接收数据的时候调用
// 100M
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    // 进度 = 当前下载的大小 / 总大小
//    NSLog(@"===%@",self.downloadProgress);
//    _tmpFileSize += data.length;
    if(self.outputStream){
      [self.outputStream write:data.bytes maxLength:data.length];
    }else{
        [self.voiceData appendData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    
    //    [self.outputStream close];
    //    self.outputStream = nil;
    //
    //    if (error == nil) {
    //        NSLog(@"下载完毕, 成功");
    //        // 移动数据  temp - > cache
    //        [XMGDownLoaderFileTool moveFile:self.tmpFilePath toPath:self.cacheFilePath];
    //        self.state = XMGDownLoaderStateSuccess;
    //        if (self.downLoadSuccess) {
    //            self.downLoadSuccess(self.cacheFilePath);
    //        }
    //    }else {
    //        NSLog(@"有错误---");
    //        //        error.code
    //        //        error.localizedDescription;
    //        self.state = XMGDownLoaderStateFailed;
    //        if (self.downLoadError) {
    //            self.downLoadError();
    //        }
    //    }
    
    
    @synchronized(self) {
        self.thread = nil;
        [self cleanUpProgressForTask:self.dataTask];
        _dataTask = nil;
    }
    if(self.downloadComplete){
        if(error){
           self.downloadComplete(nil,nil, error, YES);
        }else{
            if (self.voiceData) {
                @synchronized (self) {
                    if (self.isCancelled) {
                        self.finished = YES;
                        [self reset];
                        return;
                    }
                }
                    
                NSData *convertData = [self convertVoiceOperationWithOrignalData:self.voiceData];
                if(!convertData){
                    self.downloadComplete(nil,nil, [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Voice Convert failed"}], YES);
                }else{
                   NSString *voicePath = [self storeVoice];
                    self.downloadComplete(convertData, voicePath,nil, YES);
                }
                self.voiceData = nil;
            } else if(self.outputStream){
              [self.outputStream close];
               NSString *voicePath = [self storeVoice];
                self.outputStream = nil;
                self.downloadComplete(nil, voicePath,nil, YES);
            }else{
                 self.downloadComplete(nil,nil, [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Voice data is nil"}], YES);
            }
        }
    }
    self.completionBlock = nil;
    
    [self done];

}
//MARK: 缓存文件(返回存储路径)
- (NSString *)storeVoice{
    NSString *voicePath;
    if((self.options & WQVoiceDownloadCacheInStream) || (self.options & WQVoiceDownloadCacheInData)){
        if(!_cacheKey){
           _cacheKey = [self.voiceCache cacheKeyForURL:[self.request.URL absoluteString]];
        }
        voicePath = [self.voiceCache defaultCachePathForKey:_cacheKey];
        if(self.outputStream){
            [WQVoiceCache moveFile:[[WQVoiceCache voiceCacheTempPath] stringByAppendingPathComponent:_cacheKey] toPath:voicePath];
        }else{
             [self.voiceCache storeVoice:self.voiceData forKey:_cacheKey];
        }
    }
    return voicePath;
   
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
 // If this method is called, it means the response wasn't read from cache
    NSCachedURLResponse *cachedResponse = proposedResponse;
    
    if (self.request.cachePolicy == NSURLRequestReloadIgnoringLocalCacheData) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}
// 只要访问的是HTTPS的路径就会调用
// 该方法的作用就是处理服务器返回的证书, 需要在该方法中告诉系统是否需要安装服务器返回的证书
// NSURLAuthenticationChallenge : 授权质问
//+ 受保护空间
//+ 服务器返回的证书类型
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    //AFNetworking中的处理方式
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    //判断服务器返回的证书是否是服务器信任的
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        /*disposition：如何处理证书
         NSURLSessionAuthChallengePerformDefaultHandling:默认方式处理
         NSURLSessionAuthChallengeUseCredential：使用指定的证书    NSURLSessionAuthChallengeCancelAuthenticationChallenge：取消请求
         */
        if (credential) {
            disposition = NSURLSessionAuthChallengeUseCredential;
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
    } else {
        disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
    }
    //安装证书
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}
-(void)dealloc{
//    NSLog(@"线程销毁了");
}

@end
