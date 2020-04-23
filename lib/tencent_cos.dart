import 'dart:async';

import 'package:flutter/services.dart';


typedef Future<dynamic> EventHandler(Map<String, dynamic> event);

class TencentCos {
  static const MethodChannel _channel = const MethodChannel('tencent_cos');
  static EventHandler _onUploadProcess;
  static EventHandler _onDownloadProcess;

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  // cosPath：dev/fileName.fileType 存cos服务器的路径和文件名称
  //  localPath: 本地文件存储路径
  static Future<dynamic> uploadByFile(
      String region,
      String appid,
      String bucket,
      String secretId,
      String secretKey,
      String cosPath,
      String localPath) {
    return _channel.invokeMethod<dynamic>('TencentCos.uploadFile', {
      'region': region,
      'appid': appid,
      'bucket': bucket,
      'secretId': secretId,
      'secretKey': secretKey,
      'cosPath': cosPath,
      'localPath': localPath,
    });
  }
  
  //cosPath:并非完整路径，而是dev/fileName.fileType
  //saveDir存储的文件夹路径
  //fileName存储本地的文件名
  static Future<dynamic> downloadByCos(
      String region,
      String appid,
      String bucket,
      String secretId,
      String secretKey,
      String cosPath,
	  String saveDir,
      String fileName) {
    return _channel.invokeMethod<dynamic>('TencentCos.downloadFile', {
      'region': region,
      'appid': appid,
      'bucket': bucket,
      'secretId': secretId,
      'secretKey': secretKey,
      'cosPath': cosPath,
      'saveDir': saveDir,
	  'fileName': fileName
    });
  } 


  // call.method 分别对应上传进度onProgress和下载进度downloadProgress
  static void setMethodCallHandler(Future<dynamic> handler(MethodCall call)) {
    _channel.setMethodCallHandler(handler);
  }

  static void addProgressHandler({EventHandler onUploadProcess, EventHandler onDownloadProcess,}) {
    _onUploadProcess = onUploadProcess;
    _onDownloadProcess = onDownloadProcess;
    _channel.setMethodCallHandler(_handleMethod);
  }
  
  static Future<Null> _handleMethod(MethodCall call) async {
    print('TencentCos' + "_handleMethod:");

    switch (call.method) {
      case "onProgress":
        return _onUploadProcess(call.arguments.cast<String, dynamic>());
      case "onOpenNotification":
        return _onDownloadProcess(call.arguments.cast<String, dynamic>());
      default:
        throw new UnsupportedError("Unrecognized Event");
    }
  } 
}