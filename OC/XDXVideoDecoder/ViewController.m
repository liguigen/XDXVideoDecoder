//
//  ViewController.m
//  XDXVideoDecoder
//
//  Created by 小东邪 on 2019/6/2.
//  Copyright © 2019 小东邪. All rights reserved.
//

#import "ViewController.h"
#import "XDXAVParseHandler.h"
#import "XDXPreviewView.h"
#import "XDXVideoDecoder.h"
#import "XDXFFmpegVideoDecoder.h"
#import "XDXSortFrameHandler.h"

// FFmpeg Header File
#ifdef __cplusplus
extern "C" {
#endif
    
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avutil.h"
#include "libswscale/swscale.h"
#include "libswresample/swresample.h"
#include "libavutil/opt.h"
    
#ifdef __cplusplus
};
#endif

@interface ViewController ()<XDXVideoDecoderDelegate,XDXFFmpegVideoDecoderDelegate, XDXSortFrameHandlerDelegate>

@property (strong, nonatomic) XDXPreviewView  *previewView;
@property (weak, nonatomic) IBOutlet UIButton *startBtn;
@property (nonatomic, assign) BOOL isH265File;
@property (nonatomic, assign) int direction;
@property (nonatomic, assign) CGPoint initialPosition;
@property (strong, nonatomic) XDXSortFrameHandler *sortHandler;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    //[self setUpSwipe];
    
    self.direction = 0;
    self.isH265File = YES;
    self.sortHandler = [[XDXSortFrameHandler alloc] init];
    self.sortHandler.delegate = self;
}

- (void)setupUI {
    self.previewView = [[XDXPreviewView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.previewView];
    self.view.userInteractionEnabled = YES;
    //[self.view bringSubviewToFront:self.startBtn];
}
/*
- (void)setUpSwipe{
    UISwipeGestureRecognizer *swipeR = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(actionSwipe:)];
    swipeR.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeR];
    
    UISwipeGestureRecognizer *swipeL = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(actionSwipe:)];
    swipeL.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeL];
}

- (void)actionSwipe:(UISwipeGestureRecognizer *)swipe {
    //NSLog(@"state:%ld", (long)swipe.state);
    if (swipe.direction == UISwipeGestureRecognizerDirectionLeft) {
        NSLog(@"left.......");
        self.direction = UISwipeGestureRecognizerDirectionLeft;
    } else {
        NSLog(@"right.......");
        self.direction = UISwipeGestureRecognizerDirectionRight;
    }
    //NSLog(@"state:%ld", (long)swipe.state);
    if (swipe.state == UIGestureRecognizerStateEnded) {
        self.direction = 0;
    }
    //NSLog(@"direction:%d", self.direction);
}*/

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch = [touches anyObject];
    self.initialPosition = [touch locationInView:self.view];
    NSLog(@"touch begin");

 }

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
     UITouch *touch = [touches anyObject];
     CGPoint movingPoint = [touch locationInView:self.view];
     CGFloat moveAmt = movingPoint.x - self.initialPosition.x;
     if (moveAmt > 0) {
         self.direction = 1;
     } else if (moveAmt < 0) {
         self.direction = 2;
     }
    NSLog(@"moveamt:%f", moveAmt);
    // NSLog(@"touch moved");
  }

 -(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
     self.direction = 0;
     NSLog(@"touch end");
  }

 -(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
     NSLog(@"touch cancel");
  }

- (IBAction)startParseDidClicked:(id)sender {
    BOOL isUseFFmpeg = NO;
    if (isUseFFmpeg) {
        [self startDecodeByFFmpegWithIsH265Data:self.isH265File];
    }else {
        [self startDecodeByVTSessionWithIsH265Data:self.isH265File];
    }
    
}

- (void)startDecodeByVTSessionWithIsH265Data:(BOOL)isH265 {
    NSString *path = [[NSBundle mainBundle] pathForResource:isH265 ? @"testh265" : @"testh264"  ofType:@"MOV"];
    XDXAVParseHandler *parseHandler = [[XDXAVParseHandler alloc] initWithPath:path];
    XDXVideoDecoder *decoder = [[XDXVideoDecoder alloc] init];
    decoder.delegate = self;
    [parseHandler startParseWithCompletionHandler:^(BOOL isVideoFrame, BOOL isFinish, struct XDXParseVideoDataInfo *videoInfo, struct XDXParseAudioDataInfo *audioInfo) {
        if (isFinish) {
            [decoder stopDecoder];
            return;
        }
        
        if (isVideoFrame) {
            [decoder startDecodeVideoData:videoInfo];
        }
    }];
}

- (void)startDecodeByFFmpegWithIsH265Data:(BOOL)isH265 {
    NSString *path = [[NSBundle mainBundle] pathForResource:isH265 ? @"testh265" : @"testh264" ofType:@"MOV"];
    XDXAVParseHandler *parseHandler = [[XDXAVParseHandler alloc] initWithPath:path];
    XDXFFmpegVideoDecoder *decoder = [[XDXFFmpegVideoDecoder alloc] initWithFormatContext:[parseHandler getFormatContext] videoStreamIndex:[parseHandler getVideoStreamIndex]];
    decoder.delegate = self;
    [parseHandler startParseGetAVPackeWithCompletionHandler:^(BOOL isVideoFrame, BOOL isFinish, AVPacket packet) {
        if (isFinish) {
            [decoder stopDecoder];
            return;
        }
        
        if (isVideoFrame) {
            [decoder startDecodeVideoDataWithAVPacket:packet];
        }
    }];
}

#pragma mark - Decode Callback
- (void)getVideoDecodeDataCallback:(CMSampleBufferRef)sampleBuffer isFirstFrame:(BOOL)isFirstFrame {
    if (self.isH265File) {
        // Note : the first frame not need to sort.
        // Control the decoded frame to display
        static Float64 lastTimestamp = 0;
        if (isFirstFrame) {
            lastTimestamp = [self getCurrentTimestamp] * 1000;
            //NSLog(@"%s:%d lastTimestamp:%f", __FUNCTION__, __LINE__, lastTimestamp);
        } else {
            Float64 currentTimestamp = [self getCurrentTimestamp] * 1000;
            //NSLog(@"%s:%d currentTimestamp:%f", __FUNCTION__, __LINE__, currentTimestamp);
            while ((currentTimestamp - lastTimestamp) < 40) {
                usleep(1000);
                currentTimestamp = [self getCurrentTimestamp] * 1000;
                //NSLog(@"%s:%d currentTimestamp:%f", __FUNCTION__, __LINE__, currentTimestamp);
            }
            lastTimestamp = [self getCurrentTimestamp] * 1000;
            //NSLog(@"%s:%d lastTimestamp:%f", __FUNCTION__, __LINE__, lastTimestamp);
        }
        CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(sampleBuffer);
        [self.previewView displayPixelBuffer:pix direction:self.direction];
    }else {
        CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(sampleBuffer);
        [self.previewView displayPixelBuffer:pix direction:self.direction];
    }
}

-(void)getDecodeVideoDataByFFmpeg:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self.previewView displayPixelBuffer:pix direction:self.direction];
}


#pragma mark - Sort Callback
- (void)getSortedVideoNode:(CMSampleBufferRef)sampleBuffer {
    int64_t pts = (int64_t)(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000);
    static int64_t lastpts = 0;
    NSLog(@"Test marigin - %lld",pts - lastpts);
    lastpts = pts;
    
    [self.previewView displayPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) direction:self.direction];
}

#pragma mark - Other
- (Float64)getCurrentTimestamp {
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    return CMTimeGetSeconds(hostTime);
}
@end
