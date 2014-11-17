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

#define SECRET_KEY @"password"

#define CAMERA_ASPECT 1.3333333f //default camera aspect ratio 4:3

#define FLASH_AUTO_ICON @"\ue000"
#define FLASH_ON_ICON @"\ue001"
#define FLASH_OFF_ICON @"\ue003"

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
@interface tagItem : NSObject
@property(nonatomic,assign) int count; //item selected in carousel
@property(strong,nonatomic) NSArray* value; //list of carousel items
@property(strong,nonatomic) NSString* btn_id; //id from carousel button
@end
@implementation tagItem
@end

@interface PPWCameraViewController () {
    int mPhotoWidth;
    int mPhotoHeight;
    float mPreviewWidth;
    float mPreviewHeight;
    NSString* mEncodingType;
    int mQuality;
    
    NSMutableArray* mDataOutput;
}
@property (strong, nonatomic) IBOutlet UIView *preview;
@property (strong, nonatomic) IBOutlet UIButton *flashBtn;
@property (strong, nonatomic) IBOutlet UIButton *takePictureBtn;
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
        self.picker.view.transform = CGAffineTransformMakeRotation(-M_PI/2);
//        self.picker.view.userInteractionEnabled = NO;
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
    if (options[@"qualitys"])
        mQuality = [options[@"qualitys"] intValue];
    
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
            tagItem* t = [[tagItem alloc] init];
            t.value = value;
            t.btn_id = item[@"id"];
            t.count = 0;
            NSString* initial = item[@"initial"];
            for(int i=0; i<[value count]; ++i) {
                if (initial && [initial compare:value[i]] == NSOrderedSame) {
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
    tagItem* t = mDataOutput[b.tag];
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
}
- (IBAction)flashBtnPressed:(id)sender {

    UIButton* b = sender;
    NSString* title;
    UIColor* color;
    //choose next mode
    switch (b.tag) {
        case UIImagePickerControllerCameraFlashModeAuto:
            b.tag = UIImagePickerControllerCameraFlashModeOn;
            break;
        case UIImagePickerControllerCameraFlashModeOn:
            b.tag = UIImagePickerControllerCameraFlashModeOff;
            break;
        case UIImagePickerControllerCameraFlashModeOff:
        default:
            b.tag = UIImagePickerControllerCameraFlashModeAuto;
            break;
    }
    
    //choose new color and icon
    switch (b.tag) {
        case UIImagePickerControllerCameraFlashModeAuto:
            color = [UIColor whiteColor];
            title = FLASH_AUTO_ICON;
            break;

        case UIImagePickerControllerCameraFlashModeOff:
            color = [UIColor darkGrayColor];
            title = FLASH_OFF_ICON;
            break;
        case UIImagePickerControllerCameraFlashModeOn:
        default:
            color = [UIColor yellowColor];
            title = FLASH_ON_ICON;
            break;
    }
    self.picker.cameraFlashMode = b.tag;
    b.layer.borderUIColor = color;
    [b setTitleColor:color forState:UIControlStateNormal];
    [b setTitle:title forState:UIControlStateNormal];
}
//- (IBAction)switchCameraBtnPressed:(id)sender {
//    switch (self.picker.cameraDevice) {
//        case UIImagePickerControllerCameraDeviceRear:
//            self.picker.cameraDevice = UIImagePickerControllerCameraDeviceFront;
//            break;
//        case UIImagePickerControllerCameraDeviceFront:
//        default:
//            self.picker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
//            break;
//    }
//}

#pragma mark - UIImagePickerControllerDelegate

-(void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    NSString* timestamp = [NSString stringWithFormat:@"%.0f",[[NSDate date] timeIntervalSince1970]*1000];
    NSString* filename = [NSString stringWithFormat:@"%@.%@",timestamp,mEncodingType];
    
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
    
    // Image path
    NSString* documentsDirectory = [paths objectAtIndex:0];
    NSString* imagePath = [documentsDirectory stringByAppendingPathComponent:filename];
    
    // Image data
    NSData* imageData = nil;
    if ([mEncodingType rangeOfString:@"png"].length>0) {
        imageData = UIImagePNGRepresentation(imageResize);
    } else {
        imageData = UIImageJPEGRepresentation(imageResize, mQuality*0.01f);
    }
    
    if (numberOfBytesRemaining <= [imageData length]) {
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
        
        //generate hash of the image
        NSString* hash = [self hmacsha512:[self hexadecimalString:imageData] secret:SECRET_KEY];
        
        NSMutableDictionary* output = [@{
                                 @"imageURI":imagePath,
                                 @"lastModifiedDate":timestamp,
                                 @"size":[@([imageData length]) stringValue],
                                 @"type":mEncodingType,
                                 @"hash":hash
                                 } mutableCopy];
        if ([mDataOutput count]>0) {
            NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
            for(tagItem* t in mDataOutput) {
                [data setValue:t.value[t.count] forKey:t.btn_id];
            }
            [output setValue:data forKey:@"data"];
        }
        
        // Return output
        [self.plugin resultData:output];
    }
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    });
}

- (UIImage*)resizeImage:(UIImage*)image;
{
    //crop
//    UIGraphicsBeginImageContextWithOptions(self.preview.frame.size,YES,[UIScreen mainScreen].scale*(mPreviewWidth/self.preview.frame.size.width));
//    [image drawInRect:self.picker.view.frame];
//    UIImage* cropImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    
    //down scale
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(mPhotoWidth,mPhotoHeight),YES,1);
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
    [image drawInRect:CGRectMake(0, 0, mPhotoWidth, mPhotoHeight)];
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

#pragma mark - HMAC-SHA1 encoding

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
