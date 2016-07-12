//
//  LEBlueTooth.h
//  ygj-app-ios
//
//  Created by emerson larry on 16/1/14.
//  Copyright © 2016年 LarryEmerson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BabyBluetooth.h"
#define BlueToothPrint @"BluetoothPrint"

@protocol LEBluetoothDelegate<NSObject>
-(void) onScannedWithNewDevice:(CBPeripheral *) peripheral;
-(void) onConnectedTo:(NSString *) uuid;
-(void) onFailedToConnect:(NSString *) uuid;
-(void) onDisconnectedTo:(NSString *) uuid;
-(void) onWriteSucceed;
@end
@interface LEBluetooth : NSObject
+(LEBluetooth *) sharedInstance;
-(void) setDelegate:(id<LEBluetoothDelegate>) delegate;
-(void) onScan;
-(void) onCancelScan;
-(BOOL) onConnectTo:(NSString *) uuid;
-(void) onWriteMessage:(NSString *) message;
-(void) onClearCachedPeripheralsAndScan;
-(void) onDisconnect;
@end
