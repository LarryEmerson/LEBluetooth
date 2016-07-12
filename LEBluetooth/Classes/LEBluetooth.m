//
//  LEBluetooth
//  ygj-app-ios
//
//  Created by emerson larry on 16/1/14.
//  Copyright © 2016年 LarryEmerson. All rights reserved.
//

#import "LEBlueTooth.h"

@implementation LEBluetooth{
    BabyBluetooth *curBlueTooth;
    NSMutableArray *curCBPeripheralArray;
    NSString *curConnectedBluetoothUUID;
    id<LEBluetoothDelegate> curDelegate;
    CBCentralManagerState curBluetoothState;
}
static LEBluetooth *theSharedInstance = nil;
+ (instancetype) sharedInstance { @synchronized(self) { if (theSharedInstance == nil) { theSharedInstance = [[self alloc] init]; 
} } return theSharedInstance; }
+ (id) allocWithZone:(NSZone *)zone { @synchronized(self) { if (theSharedInstance == nil) { theSharedInstance = [super allocWithZone:zone]; return theSharedInstance; } } return nil; }
+ (id) copyWithZone:(NSZone *)zone { return self; }
+ (id) mutableCopyWithZone:(NSZone *)zone { return self; }
-(id) init{
    self=[super init];
    [self initManager];
    return self;
}
-(void) initManager{
    curCBPeripheralArray=[[NSMutableArray alloc] init];
    curBlueTooth=[BabyBluetooth shareBabyBluetooth];
    [self setBluetoothDelegate];
    curBlueTooth.scanForPeripherals().begin();
}
#define BluetoothChannel @"channel"
-(BOOL) checkBluetoothState{
    BOOL state= curBluetoothState==CBCentralManagerStatePoweredOn;
    return state;
}
-(void) setDelegate:(id<LEBluetoothDelegate>) delegate{
    curDelegate=delegate;
}
-(void) onScan{
    if([self checkBluetoothState]){
        curBlueTooth.scanForPeripherals().connectToPeripherals().discoverServices().discoverCharacteristics().readValueForCharacteristic().discoverDescriptorsForCharacteristic().readValueForDescriptors().begin();
    }
}
-(void) onCancelScan{
    [curBlueTooth cancelScan];
}
-(BOOL) onConnectTo:(NSString *) uuid{
    BOOL found=NO;
    if([self checkBluetoothState]){
        curConnectedBluetoothUUID=uuid;
        if(curCBPeripheralArray.count>0){
            for (int i=0; i<curCBPeripheralArray.count; i++) {
                CBPeripheral *per=[curCBPeripheralArray objectAtIndex:i];
                if([per.identifier.UUIDString isEqualToString:curConnectedBluetoothUUID]){
                    [curBlueTooth cancelScan];
                    curBlueTooth.having([curCBPeripheralArray objectAtIndex:0]).and.channel(BluetoothChannel).then.connectToPeripherals().discoverServices().discoverCharacteristics().readValueForCharacteristic().discoverDescriptorsForCharacteristic().readValueForDescriptors().begin();
                    found=YES;
                    break;
                }
            }
        }
    }
    return found;
}
-(void) onDisconnect{
    [self setDelegate:nil];
    [curCBPeripheralArray removeAllObjects];
    [curBlueTooth cancelScan];
    [curBlueTooth cancelAllPeripheralsConnection];
    [curBlueTooth stop];
}
-(void) onWriteMessage:(NSString *) message{
    if([self checkBluetoothState]){
        for(int i=0;i<curCBPeripheralArray.count;i++){
            CBPeripheral *per=[curCBPeripheralArray objectAtIndex:i];
            CBCharacteristic *cbCha=nil; 
            NSData *data = [message dataUsingEncoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
            if([per.identifier.UUIDString isEqualToString:curConnectedBluetoothUUID]){
                for (int a=0; a<per.services.count; a++) {
                    CBService *service=[per.services objectAtIndex:a];
                    for (int b=0; b<service.characteristics.count; b++) {
                        CBCharacteristic *cbchar=[service.characteristics objectAtIndex:b];
                        if(cbchar.properties& CBCharacteristicPropertyWrite){
                            cbCha=cbchar;
                            break;
                        }
                    }
                }
            }
            if(cbCha){
                NSLog(@"%@",message);
                [per writeValue:data forCharacteristic:cbCha type:CBCharacteristicWriteWithResponse];
            }
        }
    }
}
-(void) onDiscovedNewPeripheral:(CBPeripheral *) peripheral{
    NSString *uuidStr =@"";
    if(peripheral.identifier&&peripheral.identifier.UUIDString){
        uuidStr=peripheral.identifier.UUIDString;
    }
    BOOL found=NO;
    for (int i=0; i<curCBPeripheralArray.count; i++) {
        CBPeripheral *per=[curCBPeripheralArray objectAtIndex:i];
        NSString *uuid=@"";
        if(per.identifier&&per.identifier.UUIDString){
            uuid=per.identifier.UUIDString;
        }
        if([uuidStr isEqualToString:uuid]){
            found=YES;
            break;
        }
    }
    if(!found){
        if(curDelegate){
            [curDelegate onScannedWithNewDevice:peripheral];
        }
        [curCBPeripheralArray addObject:peripheral];
    }
}
-(void) onClearCachedPeripheralsAndScan{
    if([self checkBluetoothState]){
        [curCBPeripheralArray removeAllObjects];
        [self onScan];
    }
}
//
-(void) delegateForConnected:(NSString *) uuid{
    if(curDelegate){
        [curDelegate onConnectedTo:uuid];
    }
}
-(void) delegateForFailedToConnect:(NSString *) uuid{
    if(curDelegate){
        [curDelegate onFailedToConnect:uuid];
    }
}
-(void) delegateForDisconnected:(NSString *) uuid{
    if(curDelegate){
        [curDelegate onDisconnectedTo:uuid];
    }
}
-(void) delegateForWriteSucceed{
    if(curDelegate){
        [curDelegate onWriteSucceed];
    }
}
//设置蓝牙委托
-(void)setBluetoothDelegate{
    __weak typeof(self) weakSelf = self;
    //
    NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@NO};
    /*连接选项->
     CBConnectPeripheralOptionNotifyOnConnectionKey :当应用挂起时，如果有一个连接成功时，如果我们想要系统为指定的peripheral显示一个提示时，就使用这个key值。
     CBConnectPeripheralOptionNotifyOnDisconnectionKey :当应用挂起时，如果连接断开时，如果我们想要系统为指定的peripheral显示一个断开连接的提示时，就使用这个key值。
     CBConnectPeripheralOptionNotifyOnNotificationKey:
     当应用挂起时，使用该key值表示只要接收到给定peripheral端的通知就显示一个提
     */
    NSDictionary *connectOptions = @{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES,
                                     CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES,
                                     CBConnectPeripheralOptionNotifyOnNotificationKey:@YES};
    [curBlueTooth setBabyOptionsAtChannel:BluetoothChannel scanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:connectOptions scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
    //
    [curBlueTooth setBlockOnCentralManagerDidUpdateState:^(CBCentralManager *central) {
        curBluetoothState=central.state;
    }];
    //设置扫描到设备的委托
    [curBlueTooth setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
        NSLog(@"搜索到了设备:%@",peripheral.name);
        [weakSelf onDiscovedNewPeripheral:peripheral];
    }];
    [curBlueTooth setBlockOnConnectedAtChannel:BluetoothChannel block:^(CBCentralManager *central, CBPeripheral *peripheral) {
        NSLog(@"设备：%@--连接成功",peripheral.name);
        if(peripheral.identifier&&peripheral.identifier.UUIDString){
            [weakSelf delegateForConnected:peripheral.identifier.UUIDString];
        }
    }];
    //设置设备连接失败的委托
    [curBlueTooth setBlockOnFailToConnectAtChannel:BluetoothChannel block:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        NSLog(@"设备：%@--连接失败",peripheral.name);
        if(peripheral.identifier&&peripheral.identifier.UUIDString){
            [weakSelf delegateForFailedToConnect:peripheral.identifier.UUIDString];
        }
    }];
    //设置设备断开连接的委托
    [curBlueTooth setBlockOnDisconnectAtChannel:BluetoothChannel block:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        NSLog(@"设备：%@--断开连接",peripheral.name);
        if(peripheral.identifier&&peripheral.identifier.UUIDString){
            [weakSelf delegateForDisconnected:peripheral.identifier.UUIDString];
        }
    }];
    [curBlueTooth setBlockOnCancelAllPeripheralsConnectionBlock:^(CBCentralManager *centralManager) {
        NSLog(@"取消所有连接 setBlockOnCancelAllPeripheralsConnectionBlock");
    }];
    
    [curBlueTooth setBlockOnCancelScanBlock:^(CBCentralManager *centralManager) {
        NSLog(@"取消扫描 setBlockOnCancelScanBlock");
    }];
    //
    //设置写数据成功的block
    [curBlueTooth setBlockOnDidWriteValueForCharacteristicAtChannel:BluetoothChannel block:^(CBCharacteristic *characteristic, NSError *error) {
        //        NSLog(@"写数据成功 setBlockOnDidWriteValueForCharacteristicAtChannel characteristic:%@ and new value:%@",characteristic.UUID, characteristic.value);
        if(error){
            NSLog(@"%@",error.localizedDescription);
        }else{
            [weakSelf delegateForWriteSucceed];
        }
    }];
    //设置发现设备的Services的委托
    //    [curBlueTooth setBlockOnDiscoverServices:^(CBPeripheral *peripheral, NSError *error) {
    //    }];
    //设置发现设service的Characteristics的委托
    //    [curBlueTooth setBlockOnDiscoverCharacteristics:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
    //        NSLog(@"===service name:%@",service.UUID);
    //        for (CBCharacteristic *c in service.characteristics) {
    //            NSLog(@"charateristic name is :%@",c.UUID);
    //        }
    //    }];
    //设置读取characteristics的委托
    //    [curBlueTooth setBlockOnReadValueForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
    //        NSLog(@"characteristic name:%@ value is:%@",characteristics.UUID,characteristics.value);
    //    }];
    //设置发现characteristics的descriptors的委托
    //    [curBlueTooth setBlockOnDiscoverDescriptorsForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
    //        NSLog(@"===characteristic name:%@",characteristic.service.UUID);
    //        for (CBDescriptor *d in characteristic.descriptors) {
    //            NSLog(@"CBDescriptor name is :%@",d.UUID);
    //        }
    //    }];
    //设置读取Descriptor的委托
    //    [curBlueTooth setBlockOnReadValueForDescriptors:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
    //        NSLog(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
    //    }];
    //设置查找设备的过滤器
    //    [curBlueTooth setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName) {
    //        //设置查找规则是名称大于1 ， the search rule is peripheral.name length > 1
    //        if (peripheralName.length >1) {
    //            return YES;
    //        }
    //        return NO;
    //    }];
    
}
@end
