#import "TencentCosPlugin.h"
#import "QCloudCore.h"
#import "QCloudCOSXML/QCloudCOSXML.h"

@interface TencentCosPlugin()<QCloudSignatureProvider>
//NSDictionary *arguments;

@property (nonatomic, strong)NSDictionary *arguments;
@property (nonatomic, strong)FlutterMethodChannel *channel;
- (id)initWithChannel:(FlutterMethodChannel *)channel;
@end

@implementation TencentCosPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"tencent_cos"
            binaryMessenger:[registrar messenger]];
  TencentCosPlugin* instance = [[TencentCosPlugin alloc] init];
    instance.channel = channel;
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (id)initWithChannel:(FlutterMethodChannel *)channel;
{
    if (self = [super init]) {

        self.channel = channel;

    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {

  if ([@"getPlatformVersion" isEqualToString:call.method]) {
    result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"TencentCos.uploadFile" isEqualToString:call.method]) {
    self.arguments =   [call arguments];
    NSString *urlstr = self.arguments[@"localPath"];
    NSURL *url = [NSURL fileURLWithPath:urlstr];
    NSString *appid = self.arguments[@"appid"];
    NSString *region = self.arguments[@"region"];
    NSString *cosPath = self.arguments[@"cosPath"];
    NSString *bucket = self.arguments[@"bucket"];


    QCloudServiceConfiguration* configuration = [QCloudServiceConfiguration new];
    configuration.appID = appid;

    configuration.signatureProvider = self;
    QCloudCOSXMLEndPoint* endpoint = [[QCloudCOSXMLEndPoint alloc] init];
    endpoint.regionName = region;//服务地域名称，可用的地域请参考注释
    configuration.endpoint = endpoint;

    [QCloudCOSXMLService registerDefaultCOSXMLWithConfiguration:configuration];
    [QCloudCOSTransferMangerService registerDefaultCOSTransferMangerWithConfiguration:configuration];

    //上传文件
    QCloudCOSXMLUploadObjectRequest* put = [QCloudCOSXMLUploadObjectRequest new];

    put.object = cosPath;
    put.bucket = bucket;
    put.body =  url;/*文件的URL*/;
    [put setSendProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {

        // NSLog(@"upload %lld totalSend %lld aim %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
        NSNumber *a = @(totalBytesSent);
        NSNumber *b = @(totalBytesExpectedToSend);
        NSNumber *c =@(a.doubleValue/b.doubleValue*100);
        NSLog(@"上传进度-----  %@", c);
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        [data setValue:c forKey:@"progress"];
        [data setValue:urlstr forKey:@"localPath"];
        [self.channel invokeMethod:@"onUploadProgress" arguments:data];
    }];
    [put setFinishBlock:^(id outputObject, NSError* error) {
        NSMutableDictionary *data = [NSMutableDictionary dictionary];
        [data setValue:urlstr forKey:@"localPath" ];
        [data setValue:cosPath forKey:@"cosPath"];
        if(error.code == 0){
//            [self.channel invokeMethod:@"onSuccess" arguments:data];
            result(data);
        }else{
            [data setValue: error.domain forKey:@"message"];
            result(FlutterMethodNotImplemented);
//            [self.channel invokeMethod:@"onFailed" arguments:data];
        }

    }];
    [[QCloudCOSTransferMangerService defaultCOSTransferManager] UploadObject:put];
  } else if ([@"TencentCos.downloadFile" isEqualToString:call.method]) {
      self.arguments =   [call arguments];
//      NSString *appid = self.arguments[@"appid"];
//      NSString *region = self.arguments[@"region"];
      NSString *cosPath = self.arguments[@"cosPath"];
      NSString *bucket = self.arguments[@"bucket"];
      NSString *saveDir = self.arguments[@"saveDir"];
      NSString *fileName = self.arguments[@"fileName"];

//      QCloudServiceConfiguration* configuration = [QCloudServiceConfiguration new];
//      configuration.appID = appid;
//
//      configuration.signatureProvider = self;
//      QCloudCOSXMLEndPoint* endpoint = [[QCloudCOSXMLEndPoint alloc] init];
//      endpoint.regionName = region;//服务地域名称，可用的地域请参考注释
//      configuration.endpoint = endpoint;
//
//      [QCloudCOSXMLService registerDefaultCOSXMLWithConfiguration:configuration];
//      [QCloudCOSTransferMangerService registerDefaultCOSTransferMangerWithConfiguration:configuration];

      NSLog(@"download.prames------  %@  filename %@", saveDir, fileName);
      //下载文件
      QCloudGetObjectRequest* request = [QCloudGetObjectRequest new];
//      NSString *path = [saveDir stringByAppendingString: fileName];
//      request.downloadingURL = [NSURL URLWithString:QCloudTempFilePathWithExtension(path)];
      request.object = cosPath;
      request.bucket = bucket;
      
      [request setFinishBlock:^(id  _Nullable outputObject, NSError * _Nullable error) {
          NSLog(@"download callback------");
          NSMutableDictionary *data = [NSMutableDictionary dictionary];
          NSString *path = [saveDir stringByAppendingString: fileName];
          [data setValue:path forKey:@"savaPath"];
          [data setValue:cosPath forKey:@"cosPath"];
          if(error.code == 0){
//              [self.channel invokeMethod:@"onSuccess" arguments:data];
              result(data);
          }else{
              [data setValue: error.domain forKey:@"message"];
              result(FlutterMethodNotImplemented);
//              [self.channel invokeMethod:@"onFailed" arguments:data];
          }
      }];
      
      [request setDownProcessBlock:^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
          NSLog(@"upload %lld totalSend %lld aim %lld", bytesSent, totalBytesSent, totalBytesExpectedToSend);
          
          NSNumber *a = @(totalBytesSent);
          NSNumber *b = @(totalBytesExpectedToSend);
          NSNumber *c =@(a.doubleValue/b.doubleValue*100);
          NSMutableDictionary *data = [NSMutableDictionary dictionary];
          [data setValue:fileName forKey:@"fileName"];
          [data setValue:c forKey:@"progress"];
          [self.channel invokeMethod:@"onDownLoadProgress" arguments:data];
      }];
  }else {
    result(FlutterMethodNotImplemented);
  }
}

- (void) signatureWithFields:(QCloudSignatureFields*)fileds
                     request:(QCloudBizHTTPRequest*)request
                  urlRequest:(NSMutableURLRequest*)urlRequst
                   compelete:(QCloudHTTPAuthentationContinueBlock)continueBlock{
    /*向签名服务器请求临时的 Secret ID,Secret Key,Token*/
    QCloudCredential* credential =  [QCloudCredential new];
    credential.secretID = self.arguments[@"secretId"];
    credential.secretKey = self.arguments[@"secretKey"];
//    credential.token = self.arguments[@"sessionToken"];
    //    credential.expiretionDate     = self.arguments[@"sessionToken"];/*签名过期时间*/
    QCloudAuthentationV5Creator* creator = [[QCloudAuthentationV5Creator alloc] initWithCredential:credential];
    QCloudSignature* signature =  [creator signatureForData:urlRequst];
    continueBlock(signature, nil);
}

@end
