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
            [self sendError:@"Error presenting camera view"];
        }
    }
}

-(void)closeCamera:(CDVInvokedUrlCommand *)command {
    if (self.overlay) {
        [self closeCamera];
    }
    else {
        [self sendError:@"camera could not be closed. camera activity is not available"];
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
    AVAuthorizationStatus a = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (a) {
        case AVAuthorizationStatusAuthorized: {
            return YES;
        }
            break;
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                     completionHandler:^(BOOL granted) {
                                         if (granted) {
                                             [self openCamera:self.latestCommand];
                                         }
                                         else {
                                             [self sendError:@"Camera Access Failed"];
                                         }
                                     }];
            
        }
            break;
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
        default: {
            [self sendError:@"Camera Access Denied"];
        }
            break;
    }
    
    return NO;
}

-(void)sendError {
    [self sendError:nil];
}

-(void)sendError:(NSString*)msg {
    if (!msg) {
        msg = @"Camera Error";
    }
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:msg];
    [self.commandDelegate sendPluginResult:result callbackId:self.latestCommand.callbackId];
}

@end
