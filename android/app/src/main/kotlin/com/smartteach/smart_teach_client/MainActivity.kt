package com.smartteach.smart_teach_client

import android.os.Build
import android.os.Bundle
import android.webkit.CookieManager
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val cookieChannelName = "smart_teach/cookies"
    private val predictiveBackChannelName = "smart_teach/predictive_back"
    private var predictiveBackCallback: OnBackInvokedCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13+ 系统级预测式返回：返回手势会实时预览，松手后弹出当前路由。
        // 在 targetSdk 33 下必须始终注册回调，否则系统返回手势会直接关闭 Activity。
        registerPredictiveBack()
    }

    private fun registerPredictiveBack() {
        if (Build.VERSION.SDK_INT < 33) return
        if (predictiveBackCallback != null) return
        val callback = OnBackInvokedCallback {
            flutterEngine?.navigationChannel?.popRoute()
        }
        predictiveBackCallback = callback
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            callback
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cookieChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCookies" -> {
                        val url = call.argument<String>("url") ?: ""
                        // 强制同步 WebView 刚写入的 Cookie，再读取（含 HttpOnly 的 flarum_session）
                        val manager = CookieManager.getInstance()
                        manager.flush()
                        val cookies = manager.getCookie(url) ?: ""
                        result.success(cookies)
                    }
                    "clearCookies" -> {
                        CookieManager.getInstance().removeAllCookies(null)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, predictiveBackChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setPredictiveBack" -> {
                        // 预测式返回是 Android 13+ 的系统级能力，始终注册以保证返回正常；
                        // 开关用于记录偏好，这里同步刷新回调状态。
                        registerPredictiveBack()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
