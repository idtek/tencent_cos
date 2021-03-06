package com.silbermond.tencent_cos;

import android.app.Activity;
import android.content.Context;
import android.util.Log;
import com.tencent.cos.xml.CosXmlService;
import com.tencent.cos.xml.CosXmlServiceConfig;
import com.tencent.cos.xml.exception.CosXmlClientException;
import com.tencent.cos.xml.exception.CosXmlServiceException;
import com.tencent.cos.xml.listener.CosXmlProgressListener;
import com.tencent.cos.xml.listener.CosXmlResultListener;
import com.tencent.cos.xml.model.CosXmlRequest;
import com.tencent.cos.xml.model.CosXmlResult;
import com.tencent.cos.xml.transfer.COSXMLDownloadTask;
import com.tencent.cos.xml.transfer.COSXMLUploadTask;
import com.tencent.cos.xml.transfer.TransferConfig;
import com.tencent.cos.xml.transfer.TransferManager;
import com.tencent.cos.xml.transfer.TransferState;
import com.tencent.cos.xml.transfer.TransferStateListener;
import com.tencent.qcloud.core.auth.QCloudCredentialProvider;
import com.tencent.qcloud.core.auth.ShortTimeCredentialProvider;

import java.util.HashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/** TencentCosPlugin */
public class TencentCosPlugin implements FlutterPlugin, MethodCallHandler {
  Registrar registrar;
  MethodChannel channel;
  Context context;
  String TAG = "TencentCosPlugin";
  final HashMap<String, COSXMLUploadTask> uploads = new HashMap<>();

  @Override
  public void onAttachedToEngine( FlutterPluginBinding flutterPluginBinding) {
    final MethodChannel channel = new MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "tencent_cos");
    channel.setMethodCallHandler(new TencentCosPlugin());
    this.channel = channel;
    this.context = flutterPluginBinding.getApplicationContext();
  }

  // This static function is optional and equivalent to onAttachedToEngine. It supports the old
  // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
  // plugin registration via this function while apps migrate to use the new Android APIs
  // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
  //
  // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
  // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
  // depending on the user's project. onAttachedToEngine or registerWith must both be defined
  // in the same class.
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "tencent_cos");

    channel.setMethodCallHandler(new TencentCosPlugin(channel, registrar));
  }

    TencentCosPlugin() {

    }

    TencentCosPlugin(MethodChannel channel, Registrar registrar) {
      this.channel = channel;
      this.registrar = registrar;
      this.context = registrar.context();
    }

  @Override
  public void onMethodCall(MethodCall call, final Result result) {
    Log.i(TAG, "jyjyjy--- onMethodCall =" + call.method);
    if (call.method.equals("TencentCos.uploadFile")) {
        if (channel == null && registrar != null) {
            channel = new MethodChannel(registrar.messenger(), "tencent_cos");
        }
        String region = call.argument("region");
        String appid = call.argument("appid");
        String bucket = call.argument("bucket");
        final String cosPath = call.argument("cosPath");

        QCloudCredentialProvider credentialProvider = new ShortTimeCredentialProvider(call.<String>argument("secretId"), call.<String>argument("secretKey"), 300);
        TransferConfig transferConfig = new TransferConfig.Builder().build();
        CosXmlServiceConfig.Builder builder = new CosXmlServiceConfig.Builder().setAppidAndRegion(appid, region).setDebuggable(false).isHttps(true).setEndpointSuffix("cos.accelerate.myqcloud.com");
        builder.setSocketTimeout(10000);
        //创建 CosXmlServiceConfig 对象，根据需要修改默认的配置参数
        CosXmlServiceConfig serviceConfig = new CosXmlServiceConfig(builder);
        CosXmlService cosXmlService = new CosXmlService(registrar.context(), serviceConfig, credentialProvider);
        //初始化 TransferManager
        TransferManager transferManager = new TransferManager(cosXmlService, transferConfig);

        final String localPath = call.argument("localPath");

        //上传文件
        COSXMLUploadTask cosxmlUploadTask = transferManager.upload(bucket, cosPath, localPath, null);
        uploads.put(cosPath, cosxmlUploadTask);

        final HashMap<String, Object> data = new HashMap<>();
        data.put("localPath", localPath);
        data.put("cosPath", cosPath);
        cosxmlUploadTask.setCosXmlProgressListener(new CosXmlProgressListener() {

            @Override
            public void onProgress(final long complete, final long target) {
                ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        // Log.i(TAG, " onProgress =" + (complete * 100 / target) + "%");
                        long progress = complete * 100 / target;
                        final HashMap<String, Object> data = new HashMap<>();
                        data.put("progress", (int) progress);
                        data.put("localPath", localPath);
                        channel.invokeMethod("onUploadProgress", data);
                    }
                });
            }
        });
        //设置返回结果回调
        cosxmlUploadTask.setCosXmlResultListener(new CosXmlResultListener() {
            @Override
            public void onSuccess(CosXmlRequest request, CosXmlResult httPesult) {
                Log.i(TAG, "Success: " + httPesult.printResult());
                uploads.remove(cosPath);
                ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        result.success(data);
                    }
                });
            }

            @Override
            public void onFail(CosXmlRequest request, CosXmlClientException exception, CosXmlServiceException serviceException) {            
                final HashMap<String, Object> error = new HashMap<>();
                uploads.remove(cosPath);
                ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        //result.error前端没catch到，因此同样用success，但内容为空
                        result.success(error);
                    }
                });

            }
        });
    } else if (call.method.equals("TencentCos.downloadFile")) {
        String region = call.argument("region");
        String appid = call.argument("appid");
        String bucket = call.argument("bucket");
        final String cosPath = call.argument("cosPath");

        QCloudCredentialProvider credentialProvider = new ShortTimeCredentialProvider(call.<String>argument("secretId"), call.<String>argument("secretKey"), 300);
        TransferConfig transferConfig = new TransferConfig.Builder().build();
        CosXmlServiceConfig.Builder builder = new CosXmlServiceConfig.Builder().setAppidAndRegion(appid, region).setDebuggable(false).isHttps(true);
        builder.setSocketTimeout(10000);
        //创建 CosXmlServiceConfig 对象，根据需要修改默认的配置参数
        CosXmlServiceConfig serviceConfig = new CosXmlServiceConfig(builder);
        CosXmlService cosXmlService = new CosXmlService(registrar.context(), serviceConfig, credentialProvider);
        //初始化 TransferManager
        TransferManager transferManager = new TransferManager(cosXmlService, transferConfig);

        String saveDir = call.argument("saveDir");
        final String fileName = call.argument("fileName");
        //下载文件
        COSXMLDownloadTask cosxmlDownloadTask = transferManager.download(context, bucket, cosPath, saveDir, fileName);
        cosxmlDownloadTask.setCosXmlProgressListener(new CosXmlProgressListener() {
            @Override
            public void onProgress(final long complete, final long target) {
                ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        long progress = complete * 100 / target;
                        final HashMap<String, Object> data = new HashMap<>();
                        data.put("progress",(int) progress);
                        data.put("fileName", fileName);
                        channel.invokeMethod("downloadProgress", data);
                    }
                });

            }
        });

        final HashMap<String, Object> data = new HashMap<>();
        data.put("savaPath", saveDir + fileName);
        data.put("cosPath", cosPath);
        cosxmlDownloadTask.setCosXmlResultListener(new CosXmlResultListener() {
            @Override
            public void onSuccess(CosXmlRequest request,  CosXmlResult cosResult) {
                Log.i("tencentCos", "onSuccess: " + cosResult.printResult());
                ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        result.success(data);
                    }
                });
            }

            @Override
            public void onFail(CosXmlRequest request, CosXmlClientException exception, CosXmlServiceException serviceException) {
                ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        result.error("failed", "failed", "failed");
                        Log.i("tencentCos", "onFail:--------- ");
                    }
                });
            }
        });
    } else if (call.method.equals("TencentCos.cancelUpload")) {
        final String cosPath = call.argument("cosPath");
        COSXMLUploadTask cosxmlUploadTask = uploads.get(cosPath);
        if (cosxmlUploadTask != null) {
            cosxmlUploadTask.cancel();
            uploads.remove(cosPath);
        }
        // ((Activity) registrar.activeContext()).runOnUiThread(new Runnable() {
        //     @Override
        //     public void run() {
        //         final HashMap<String, Object> data = new HashMap<>();
        //         result.success(data);
        //     }
        // });
    }else {
        result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
  }
}
