//
//  PPWCamera.m
//  PPWCamera
//
//  Created by Paul on 2014-10-20.
//
//

#import "PPWCamera.h"
#import <AVFoundation/AVFoundation.h>

@implementation PPWCamera

// command method
-(void)openCamera:(CDVInvokedUrlCommand *)command {
    
    // Set the hasPendingOperation field to prevent the webview from crashing (undocumented)
    self.hasPendingOperation = YES;
    
    // Save CDVInvokedUrlCommand
    self.latestCommand = command;
    
    // Present the view
    if ([self cameraAccessCheck]) {
        self.overlay = [[PPWCameraViewController alloc] initWithNibName:@"PPWCameraViewController" bundle:nil];
        if (self.overlay) {
            [self.overlay setOptions:[command argumentAtIndex:0]];
            self.overlay.plugin = self;
            self.overlay.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            [self.viewController presentViewController:self.overlay animated:NO completion:nil];
        }
        else {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not found"];
            [self.commandDelegate sendPluginResult:result callbackId:self.latestCommand.callbackId];
        }
    }
}

// return method
-(void)resultData:(NSDictionary *)output {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:output];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.latestCommand.callbackId];
    
    // Unset the self.hasPendingOperation property
    self.hasPendingOperation = NO;
}

-(void)closeCamera {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
}

-(BOOL)cameraAccessCheck {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized: {
            return YES;
        }
            break;
        case AVAuthorizationStatusNotDetermined:
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
        default: {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera Access - Denied"];
            [self.commandDelegate sendPluginResult:result callbackId:self.latestCommand.callbackId];
        }
            break;
    }
    
    return NO;
}

@end
