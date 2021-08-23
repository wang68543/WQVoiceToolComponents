//
//  WQAmrFileCodec.h
//  amrDemoForiOS
//
//  Created by Tang Xiaoping on 9/27/11.
//  Copyright 2011 test. All rights reserved.
//
#ifndef WQAmrFileCodec_h
#define WQAmrFileCodec_h
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#import <UIKit/UIKit.h>


// WAVE音频采样频率是8khz 
// 音频样本单元数 = 8000*0.02 = 160 (由采样频率决定)
// 声道数 1 : 160
//        2 : 160*2 = 320
// bps决定样本(sample)大小
// bps = 8 --> 8位 unsigned char
//       16 --> 16位 unsigned short
//int WQ_EncodeWAVEFileToAMRFile(const char* pchWAVEFilename, const char* pchAMRFileName, int nChannels, int nBitsPerSample);


// 将AMR文件解码成WAVE文件
//int WQ_DecodeAMRFileToWAVEFile(const char* pchAMRFileName, const char* pchWAVEFilename);


NSData* DecodeAMRToWAVE(NSData* data);
NSData* EncodeWAVEToAMR(NSData* data, int nChannels, int nBitsPerSample);

#endif
