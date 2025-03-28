//
//  CDVAppUpdate
//
//  Created by Austen Zeh <developerDawg@gmail.com> on 2020-03-16
//
#import "CDVAppUpdate.h"
#import <objc/runtime.h>
#import <Cordova/CDVViewController.h>

static NSString *const TAG = @"CDVAppUpdate";

@implementation CDVAppUpdate

-(void) needsUpdate:(CDVInvokedUrlCommand*)command
{
    NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
    NSString* appID = infoDictionary[@"CFBundleIdentifier"];
    NSString* force_api = nil;
    NSString* force_key = nil;
    if ([command.arguments count] > 0) {
        force_api = [command.arguments objectAtIndex:0];
        force_key = [command.arguments objectAtIndex:1];
    }
    NSString *jsonString = @"{\"resultCount\":1,\"results\":[{\"trackName\":\"Spring: Easy Access Savings\",\"version\":\"1.800.2 (45)\"}]}";
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* lookup = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSMutableDictionary *resultObj = [[NSMutableDictionary alloc]initWithCapacity:10];
    BOOL update_avail = NO;
    BOOL update_force = NO;
    BOOL invalid_number = NO;

    NSLog(@"%@ Checking for app update", TAG);
    if ([lookup[@"resultCount"] integerValue] == 1) {
        NSString* appStoreVersion = lookup[@"results"][0][@"version"];
        
        // Remove anything in parentheses
        NSRange range = [appStoreVersion rangeOfString:@"("];
        if (range.location != NSNotFound) {
            appStoreVersion = [appStoreVersion substringToIndex:range.location];
        }

        // Trim whitespace
        appStoreVersion = [appStoreVersion stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if (appStoreVersion) {
            [resultObj setObject:appStoreVersion forKey:@"store_version"];
        } else {
             [resultObj setObject:@"" forKey:@"store_version"]; // Assign an empty string to prevent crashes
        }
        
        NSArray* appStoreVersionArr = [appStoreVersion componentsSeparatedByString:@"."];
        NSString* currentVersion = infoDictionary[@"CFBundleShortVersionString"];
        NSArray* currentVersionArr = [currentVersion componentsSeparatedByString:@"."];

        for (int idx=0; idx<[appStoreVersionArr count]; idx++) {
            NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
            f.numberStyle = NSNumberFormatterDecimalStyle;
            NSNumber* appStoreVersionNumber = [f numberFromString:[appStoreVersionArr objectAtIndex:idx]];
            NSNumber* currentVersionNumber = [f numberFromString:[currentVersionArr objectAtIndex:idx]];

            // Safety check for NSNumberFormatter
            if (!appStoreVersionNumber || !currentVersionNumber) {
                NSLog(@"Error: Failed to parse version numbers");
                invalid_number = YES;
                [resultObj setObject:[NSNumber numberWithBool:invalid_number] forKey:@"invalid_num"];
                continue;
            }

            if ([currentVersionNumber compare:appStoreVersionNumber] == NSOrderedAscending) {
                NSLog(@"%@ Need to update [%@ != %@]", TAG, appStoreVersion, currentVersion);
                if ([force_api length] > 0) {
                    NSURL* force_url = [NSURL URLWithString:[NSString stringWithFormat:force_api]];
                    NSData* force_data = [NSData dataWithContentsOfURL:force_url];
                    NSDictionary* force_lookup = [NSJSONSerialization JSONObjectWithData:force_data options:0 error:nil];
                    update_force = [force_lookup objectForKey:force_key];
                    for (id key in force_lookup) {
                        [resultObj setObject:[force_lookup objectForKey:key] forKey:key];
                    }
                }
                NSLog(@"%@ Force Update: %i", TAG, update_force);
                update_avail = YES;
                break;
            }
        }
    }

    
    [resultObj setObject:[NSNumber numberWithBool:update_avail] forKey:@"update_available"];

    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultObj];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

@end
