package com.smartteach.smart_teach_client

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "smart_teach/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
    }
}
