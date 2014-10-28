/********* CDVppw_camera_plugin.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>

@interface ppw_camera_plugin : CDVPlugin {
  // Member variables go here.
}

- (void)openCamera:(CDVInvokedUrlCommand*)command;
@end

@implementation CDVppw_camera_plugin

- (void)openCamera:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* echo = [command.arguments objectAtIndex:0];

    if (echo != nil && [echo length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end
