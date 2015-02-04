//
//  PPWCameraViewController.m
//  PPWCamera
//
//  Created by Paul on 2014-10-20.
//  Copyright (c) 2014 Appnovation. All rights reserved.
//

#import "PPWCamera.h"
#import "PPWCameraViewController.h"
#import "MBProgressHUD.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <AVFoundation/AVFoundation.h>

#define SECRET_KEY @"password"
#define CAMERA_ASPECT 1.3333333f //default camera aspect ratio 4:3

#define FLASH_ICON_AUTO @"\ue000"
#define FLASH_ICON_ON @"\ue001"
#define FLASH_ICON_OFF @"\ue003"

#define FLASH_NAME_AUTO @"auto"
#define FLASH_NAME_TORCH @"torch"
#define FLASH_NAME_ON @"on"
#define FLASH_NAME_OFF @"off"

// This assigns a CGColor to a borderColor.
@interface CALayer(XibConfiguration)
@property(nonatomic, assign) UIColor* borderUIColor;
@end
@implementation CALayer(XibConfiguration)
-(void)setBorderUIColor:(UIColor*)color {
    self.borderColor = color.CGColor;
}
-(UIColor*)borderUIColor{
    return [UIColor colorWithCGColor:self.borderColor];
}
@end

//holder for carousel data
@interface TagItem : NSObject
@property(nonatomic,assign) int count; //item selected in carousel
@property(strong,nonatomic) NSArray* value; //list of carousel items
@property(strong,nonatomic) NSString* btn_id; //id from carousel button
@end
@implementation TagItem
@end

//flash data types
typedef NS_ENUM(NSInteger, FlashDataType) {
    kFlashDataTypeAuto,
    kFlashDataTypeTorch,
    kFlashDataTypeOn,
    kFlashDataTypeOff,
    kFlashDataTypeCount
};

//holder and methods for flash data
@interface FlashData : NSObject
-(FlashDataType)getNextType;
-(void)setTypeByName:(NSString*)name;
-(void)setType:(FlashDataType)type;
-(void)updateButton:(UIButton*)b picker:(UIImagePickerController*)p;
@property(nonatomic,assign) FlashDataType type;
@property(strong,nonatomic) UIColor* color;
@property(strong,nonatomic) NSString* icon;
@property(nonatomic,assign) UIImagePickerControllerCameraFlashMode mode;
@property(strong,nonatomic) NSString* name;
@end
@implementation FlashData
-(FlashDataType)getNextType {
    return (FlashDataType)(_type+1 >= kFlashDataTypeCount ? 0 : _type+1);
}
-(void)setTypeByName:(NSString *)name {
    if ([name compare:FLASH_NAME_TORCH options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [self setType:kFlashDataTypeTorch];
    }
    else if ([name compare:FLASH_NAME_ON options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [self setType:kFlashDataTypeOn];
    }
    else if ([name compare:FLASH_NAME_OFF options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [self setType:kFlashDataTypeOff];
    }
    else {
        [self setType:kFlashDataTypeAuto];
    }
}
-(void)setType:(FlashDataType)type {
    switch (type) {
        case kFlashDataTypeAuto:
            _color = [UIColor whiteColor];
            _icon = FLASH_ICON_AUTO;
            _mode = UIImagePickerControllerCameraFlashModeAuto;
            _name = FLASH_NAME_AUTO;
            break;
        case kFlashDataTypeTorch:
            _color = [UIColor greenColor];
            _icon = FLASH_ICON_ON;
            _mode = UIImagePickerControllerCameraFlashModeOff;
            _name = FLASH_NAME_TORCH;
            break;
        case kFlashDataTypeOn:
            _color = [UIColor yellowColor];
            _icon = FLASH_ICON_ON;
            _mode = UIImagePickerControllerCameraFlashModeOn;
            _name = FLASH_NAME_ON;
            break;
        case kFlashDataTypeOff:
            _color = [UIColor darkGrayColor];
            _icon = FLASH_ICON_OFF;
            _mode = UIImagePickerControllerCameraFlashModeOff;
            _name = FLASH_NAME_OFF;
            break;
        default:
            break;
    }
    _type = type;
}
-(void)updateButton:(UIButton *)b picker:(UIImagePickerController*)p {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    if (kFlashDataTypeTorch == _type && [device isTorchModeSupported:AVCaptureTorchModeOn]) {
        [device setTorchMode:AVCaptureTorchModeOn];
        [device setFlashMode:AVCaptureFlashModeOn];
    }
    else {
        [device setTorchMode:AVCaptureTorchModeOff];
        [device setFlashMode:AVCaptureFlashModeOff];
    }
    [device unlockForConfiguration];
    p.cameraFlashMode = _mode;
    b.tag = _mode;
    b.layer.borderUIColor = _color;
    [b setTitleColor:_color forState:UIControlStateNormal];
    [b setTitle:_icon forState:UIControlStateNormal];
}
@end

@interface PPWCameraViewController () {
    int mPhotoWidth;
    int mPhotoHeight;
    float mPreviewWidth;
    float mPreviewHeight;
    NSString* mEncodingType;
    int mQuality;
    NSString* mFlashType;
    int mThumbnail;
    BOOL mBackNotify;
    NSMutableArray* mDataOutput;
}
@property (strong, nonatomic) UIView *preview;
@property (strong, nonatomic) IBOutlet UIButton *flashBtn;
@property (strong, nonatomic) IBOutlet UIButton *takePictureBtn;
@property (strong, nonatomic) FlashData* flashBtnData;
@property (strong, nonatomic) IBOutlet UIButton *thumbnailBtn;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UIButton *imageViewBtn;
@end

@implementation PPWCameraViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (![UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]) {
        return nil; //no camera available
    }
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.picker = [[UIImagePickerController alloc] init];
        self.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        self.picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
        self.picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        self.picker.showsCameraControls = NO;
        self.picker.allowsEditing = NO;
        self.picker.delegate = self;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            switch ([[UIDevice currentDevice] orientation])
            {
                case UIDeviceOrientationPortrait:
                case UIDeviceOrientationPortraitUpsideDown:
                    self.picker.view.transform = CGAffineTransformMakeRotation(-M_PI/2);
                    break;
                default:
                    break;
            }
        }
        else {
            self.picker.view.transform = CGAffineTransformMakeRotation(-M_PI/2);
        }
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _flashBtn.hidden = ![UIImagePickerController isFlashAvailableForCameraDevice:UIImagePickerControllerCameraDeviceRear];
}

-(void)viewDidLoad {
    [super viewDidLoad];

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    float screenWidth = screenBounds.size.height > screenBounds.size.width ? screenBounds.size.height : screenBounds.size.width;
    float screenHeight = screenBounds.size.height <= screenBounds.size.width ? screenBounds.size.height : screenBounds.size.width;;
    float screenRatio = screenWidth / screenHeight;
    float previewRatio = mPreviewWidth / mPreviewHeight;
    
    float width = previewRatio*screenHeight;
    float height = screenHeight;
    if (previewRatio > screenRatio) {
        width = screenWidth;
        height = screenWidth / previewRatio;
    }
    
    //create preview
    self.preview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [self.preview setContentMode:UIViewContentModeScaleAspectFill];
    [self.preview setClipsToBounds:YES];
    [self.view insertSubview:self.preview atIndex:0];
    
    width = CAMERA_ASPECT*screenHeight;
    height = screenHeight;
    if (previewRatio > screenRatio) {
        width = screenWidth;
        height = screenWidth / CAMERA_ASPECT;
    }
    
    //add camera view
    [self addChildViewController:self.picker];
    [self.preview addSubview:self.picker.view];
    [self.picker didMoveToParentViewController:self];
    CGRect r = self.picker.view.frame;
    r.origin = CGPointMake(0,0);
    r.size = CGSizeMake(width, height);
    self.picker.view.frame = r;
    
    self.preview.center = CGPointMake(screenWidth / 2, screenHeight / 2);
    self.picker.view.center = CGPointMake(self.preview.bounds.size.width / 2, self.preview.bounds.size.height / 2);
    
    //set flash type
    _flashBtn.hidden = ![UIImagePickerController isFlashAvailableForCameraDevice:UIImagePickerControllerCameraDeviceRear];
    _flashBtnData = [[FlashData alloc] init];
    [_flashBtnData setTypeByName:mFlashType];
    if (!_flashBtn.hidden) {
        [_flashBtnData updateButton:_flashBtn picker:_picker];
    }
}

-(void)dealloc
{
    if (self.picker) {
        [self.picker willMoveToParentViewController:nil];
        [self.picker.view removeFromSuperview];
        [self.picker removeFromParentViewController];
        [self.picker didMoveToParentViewController:nil];
    }
}

- (void)setOptions:(NSDictionary*)options {
    mPhotoWidth = 640;
    mPhotoHeight = 480;
    mPreviewWidth = 640;
    mPreviewHeight = 480;
    mEncodingType = @"jpg";
    mQuality = 100;
    mFlashType = FLASH_NAME_AUTO;
    mThumbnail = 25;
    mBackNotify = NO;
    mDataOutput = [[NSMutableArray alloc] init];
    
    //scroll through overlay options
    if (!options || options.count <= 0)
        return;

    if (options[@"targetWidth"])
        mPhotoWidth = [options[@"targetWidth"] intValue];
    if (options[@"targetHeight"])
        mPhotoHeight = [options[@"targetHeight"] intValue];
    if (options[@"previewWidth"])
        mPreviewWidth = [options[@"previewWidth"] intValue];
    if (options[@"previewHeight"])
        mPreviewHeight = [options[@"previewHeight"] intValue];
    if (options[@"encodingType"])
        mEncodingType = options[@"encodingType"];
    if (options[@"quality"])
        mQuality = [options[@"quality"] intValue];
    if (options[@"flashType"])
        mFlashType = options[@"flashType"];
    if (options[@"thumbnail"])
        mThumbnail = [options[@"thumbnail"] intValue];
    if (options[@"backNotify"])
        mBackNotify = [options[@"backNotify"] boolValue];
    
    NSArray* overlay = options[@"overlay"];
    if (!overlay)
        return;

    for(int i=0; i<[overlay count]; ++i) {
        NSDictionary* item = overlay[i];
        NSString* type = item[@"type"];
        if (!type)
            continue;
        
        UIView* view = nil;
        
        //setup text
        if ([type rangeOfString:@"text"].length>0) {
            NSString* value = item[@"value"];
            UILabel* label = [[UILabel alloc] init];
            [label setText:value];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [label setTextColor:[UIColor whiteColor]];
            [label setShadowColor:[UIColor blackColor]];
            if (item[@"size"])
                [label setFont:[UIFont systemFontOfSize:[item[@"size"] intValue]]];
            [self.view addSubview:label];
            view = label;
        }
        //setup carousel
        else if ([type rangeOfString:@"carousel"].length>0) {
            NSArray* value = item[@"value"];
            TagItem* t = [[TagItem alloc] init];
            t.value = value;
            t.btn_id = item[@"id"];
            t.count = 0;
            NSString* initial = item[@"initial"];
            for(int i=0; i<[value count]; ++i) {
                if (initial && [initial compare:value[i] options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                    t.count = i;
                }
            }
            NSString* title = @"error";
            if (value && [value count] > 0) {
                title = value[t.count];
            }
            else
                return; //exit if no labels provided
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            button.tag = [mDataOutput count];
            [mDataOutput addObject:t];
            
            [button addTarget:self action:@selector(carouselBtnPressed:) forControlEvents:UIControlEventTouchUpInside];
            [button setTitle:title forState:UIControlStateNormal];
            if (item[@"size"])
                [button.titleLabel setFont:[UIFont systemFontOfSize:[item[@"size"] intValue]]];
            [button sizeToFit];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button setTitleShadowColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
            button.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.25f];
            [self.view addSubview:button];
            view = button;
        }
        else
            continue;

        //setup layout
        NSLayoutFormatOptions layoutFormatV = NSLayoutFormatAlignAllCenterX;
        NSString* visualFormatV = nil;
        NSLayoutFormatOptions layoutFormatH = NSLayoutFormatAlignAllCenterY;
        NSString* visualFormatH = nil;
        NSString* position = item[@"position"];
        if (position) {
            if ([position rangeOfString:@"top"].length>0) {
                layoutFormatH = NSLayoutFormatAlignAllTop;
                if (item[@"top"])
                    visualFormatV = [NSString stringWithFormat:@"V:|-%@-[view]",item[@"top"]];
                else
                    visualFormatV = @"V:|-0-[view]";
            }
            else if ([position rangeOfString:@"bottom"].length>0) {
                layoutFormatH = NSLayoutFormatAlignAllBottom;
                if (item[@"bottom"])
                    visualFormatV = [NSString stringWithFormat:@"V:[view]-%@-|",item[@"bottom"]];
                else
                    visualFormatV = @"V:[view]-0-|";
            }
            else if ([position hasPrefix:@"center"]) {
                
            }
            if ([position rangeOfString:@"left"].length>0) {
                layoutFormatV = NSLayoutFormatAlignAllLeft;
                if (item[@"left"])
                    visualFormatH = [NSString stringWithFormat:@"H:|-%@-[view]",item[@"left"]];
                else
                    visualFormatV = @"V:|-0-[view]";
            }
            else if ([position rangeOfString:@"right"].length>0) {
                layoutFormatV = NSLayoutFormatAlignAllRight;
                if (item[@"right"])
                    visualFormatH = [NSString stringWithFormat:@"H:[view]-%@-|",item[@"right"]];
                else
                    visualFormatV = @"V:[view]-0-|";
            }
            else if ([position hasSuffix:@"center"]) {
                
            }
        }

        if ([[NSLayoutConstraint class] respondsToSelector:@selector(activateConstraints:)]) {
            if (visualFormatV) {
                [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:visualFormatV
                                                                                                options:layoutFormatH
                                                                                                metrics:nil
                                                                                                  views:@{@"view":view}]];
            }
            else {
                [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[super]-(<=1)-[view]"
                                                                                                options:NSLayoutFormatAlignAllCenterY
                                                                                                metrics:nil
                                                                                                  views:@{@"super":self.view,@"view":view}]];
            }
            if (visualFormatH) {
                [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:visualFormatH
                                                                                                options:layoutFormatV
                                                                                                metrics:nil
                                                                                                  views:@{@"view":view}]];
            }
            else {
                [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[super]-(<=1)-[view]"
                                                                                                options:NSLayoutFormatAlignAllCenterX
                                                                                                metrics:nil
                                                                                                  views:@{@"super":self.view,@"view":view}]];
            }
        }
        else {
            //add position and margin
            if (visualFormatV) {
                [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:visualFormatV
                                                                                  options:layoutFormatH
                                                                                  metrics:nil
                                                                                    views:@{@"view":view}]];
            }
            else {
                [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[super]-(<=1)-[view]"
                                                                                  options:NSLayoutFormatAlignAllCenterY
                                                                                  metrics:nil
                                                                                    views:@{@"super":self.view,@"view":view}]];
            }
            if (visualFormatH) {
                [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:visualFormatH
                                                                                  options:layoutFormatV
                                                                                  metrics:nil
                                                                                    views:@{@"view":view}]];
            }
            else {
                [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[super]-(<=1)-[view]"
                                                                                  options:NSLayoutFormatAlignAllCenterX
                                                                                  metrics:nil
                                                                                    views:@{@"super":self.view,@"view":view}]];
            }
        }
    }
}

#pragma mark - Orientation and status bar

- (BOOL)prefersStatusBarHidden {
    return YES;
}
-(BOOL)shouldAutorotate {
    return NO;
}
- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscapeRight;
}
-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeRight;
}

#pragma mark UIButton delegates

-(void)carouselBtnPressed:(id)sender {
    UIButton* b = sender;
    TagItem* t = mDataOutput[b.tag];
    t.count++;
    if (t.count>=[t.value count]) {
        t.count = 0;
    }
    NSString* title = t.value[t.count];
    [b setTitle:title forState:UIControlStateNormal];
}

- (IBAction)takePhotoBtnPressed:(id)sender forEvent:(UIEvent *)event {
    if (![self.plugin cameraAccessCheck])
        return;
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"Saving...";
    [self.picker takePicture];
}
- (IBAction)closeBtnPressed:(id)sender {
    [self.plugin closeCamera];
    if (mBackNotify) {
        [self.plugin sendError:@"close button clicked"];
    }
}
- (IBAction)flashBtnPressed:(id)sender {
    [_flashBtnData setType:[_flashBtnData getNextType]];
    [_flashBtnData updateButton:_flashBtn picker:_picker];
}
- (IBAction)thumbnailBtnPressed:(id)sender {
    [_imageView setHidden:NO];
    [_imageViewBtn setHidden:NO];
}
- (IBAction)imageViewBtnPressed:(id)sender {
    [_imageView setHidden:YES];
    [_imageViewBtn setHidden:YES];
}


#pragma mark - UIImagePickerControllerDelegate

-(void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    NSString* timestamp = [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]*1000];
    NSString* filename = [NSString stringWithFormat:@"%@.%@",timestamp,mEncodingType];
    NSString* filenameThumb = [NSString stringWithFormat:@"%@_thumb.%@",timestamp,mEncodingType];
    
    //check free space
    NSError *error = nil;
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSDictionary * const pathAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths firstObject] error:&error];
    NSAssert(pathAttributes, @"");
    NSNumber * const fileSystemSizeInBytes = [pathAttributes objectForKey: NSFileSystemFreeSize];
    const long long numberOfBytesRemaining = [fileSystemSizeInBytes longLongValue];
    
    // Image taken
    UIImage* image = [info objectForKey:UIImagePickerControllerOriginalImage];
    UIImage* imageResize = [self resizeImage:image];
    UIImage* imageThumb = nil;
    if (mThumbnail > 0) {
        imageThumb = [self resizeImage:image width:imageResize.size.width*(mThumbnail*0.01f) height:imageResize.size.height*(mThumbnail*0.01f)];
    }
    
    // Image path
    NSString* documentsDirectory = [paths objectAtIndex:0];
    NSString* imagePath = [documentsDirectory stringByAppendingPathComponent:filename];
    NSString* imagePathThumb = @"";
    if (mThumbnail > 0) {
        imagePathThumb = [documentsDirectory stringByAppendingPathComponent:filenameThumb];
    }
    
    // Image data
    NSData* imageData = nil;
    NSData* imageDataThumb = nil;
    if ([mEncodingType rangeOfString:@"png"].length>0) {
        imageData = UIImagePNGRepresentation(imageResize);
        if (mThumbnail > 0) {
            imageDataThumb = UIImagePNGRepresentation(imageThumb);
        }
    } else {
        imageData = UIImageJPEGRepresentation(imageResize, mQuality*0.01f);
        if (mThumbnail > 0) {
            imageDataThumb = UIImageJPEGRepresentation(imageThumb, mQuality*0.01f);
        }
    }
    
    NSUInteger dataLength = [imageData length];
    if (imageDataThumb) {
        dataLength += [imageDataThumb length];
    }
    if (numberOfBytesRemaining <= dataLength) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to Save - Disk Full"
                                                        message:[NSString stringWithFormat:@"Available Space: %lld",numberOfBytesRemaining]
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
    else {
        // Write the data to the file
        [imageData writeToFile:imagePath atomically:YES];
        if (imageDataThumb) {
            [imageDataThumb writeToFile:imagePathThumb atomically:YES];
        }
        
        //generate hash of the image
        NSString* hash = [self hmacsha512:[self hexadecimalString:imageData] secret:SECRET_KEY];
        
        NSMutableDictionary* output = [@{
                                 @"imageURI":imagePath,
                                 @"imageThumbURI": imagePathThumb,
                                 @"lastModifiedDate":timestamp,
                                 @"size":[@([imageData length]) stringValue],
                                 @"type":mEncodingType,
                                 @"hash":hash,
                                 @"flashType":[_flashBtnData name]
                                 } mutableCopy];
        if ([mDataOutput count]>0) {
            NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
            for(TagItem* t in mDataOutput) {
                [data setValue:t.value[t.count] forKey:t.btn_id];
            }
            [output setValue:data forKey:@"data"];
        }
        
        //update thumbnail
        if (mThumbnail > 0) {
            [_thumbnailBtn setImage:imageThumb forState:UIControlStateNormal];
            [_thumbnailBtn.imageView setContentMode:UIViewContentModeScaleAspectFill];
            [_thumbnailBtn setHidden:NO];
            
            //hide button
            [_imageViewBtn setHidden:YES];
            
            //setup image view
            [_imageView setImage:imageResize];
            [_imageView setHidden:YES];
        }
        
        // Return output
        [self.plugin resultData:output];
    }
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
}

- (UIImage*)resizeImage:(UIImage*)image {
    return[self resizeImage:image width:mPhotoWidth height:mPhotoHeight];
}

- (UIImage*)resizeImage:(UIImage*)image width:(float)photoWidth height:(float)photoHeight {
    float previewRatio = mPreviewWidth / mPreviewHeight;
    float width = CAMERA_ASPECT*photoHeight;
    float height = photoHeight;
    if (previewRatio > CAMERA_ASPECT) {
        width = photoWidth;
        height = photoWidth / CAMERA_ASPECT;
    }
    
    //down scale and crop
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(photoWidth,photoHeight),YES,1.0f);
    switch (image.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            image = [UIImage imageWithCGImage:image.CGImage
                                scale:1
                          orientation:UIImageOrientationUp];
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        default:
            break;
    }
    CGRect cropRect = CGRectMake((photoWidth-width)*0.5f, (photoHeight-height)*0.5f, width, height);
    UIRectClip(cropRect);
    [image drawInRect:cropRect];
    UIImage* scaleImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //maintain orientation if upside down
    if (image.imageOrientation==UIImageOrientationDown) {
        return [UIImage imageWithCGImage:scaleImage.CGImage
                                   scale:1
                             orientation:image.imageOrientation];
    }
    return scaleImage;
}

#pragma mark - HMAC-SHA512 encoding

- (NSString *)hexadecimalString:(NSData *)data {
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */
    
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    
    if (!dataBuffer)
        return [NSString string];
    
    NSUInteger          dataLength  = [data length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return [NSString stringWithString:hexString];
}

- (NSString *)hmacsha512:(NSString *)data secret:(NSString *)key {
    
    const char *cKey  = [key cStringUsingEncoding:NSASCIIStringEncoding];
    const char *cData = [data cStringUsingEncoding:NSASCIIStringEncoding];
    
    unsigned char cHMAC[CC_SHA512_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA512, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
    NSString *hash = [HMAC base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
    return hash;
}
@end
