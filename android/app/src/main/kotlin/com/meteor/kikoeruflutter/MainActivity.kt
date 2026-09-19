package com.meteor.kikoeruflutter

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.ProxySelector
import java.net.URI

class MainActivity : AudioServiceFragmentActivity() {
    private var floatingLyricPlugin: FloatingLyricPlugin? = null
    private var audioHapticsBridge: AudioHapticsBridge? = null
    private var subtitleDirectoryPicker: SubtitleDirectoryPicker? = null
    private var localTranslationBridge: LocalTranslationBridge? = null
    private val screenAwakeChannelName = "com.meteor.kikoeruflutter/screen_awake"
    private val systemProxyChannelName = "com.meteor.kikoeruflutter/system_proxy"
    private val aiBenchmarkChannelName = "com.meteor.kikoeruflutter/ai_benchmark"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册悬浮字幕插件
        floatingLyricPlugin = FloatingLyricPlugin.getInstance(this)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FloatingLyricPlugin.CHANNEL
        )
        floatingLyricPlugin?.attachChannel(channel)
        channel.setMethodCallHandler(floatingLyricPlugin)
        audioHapticsBridge = AudioHapticsBridge(
            context = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        subtitleDirectoryPicker = SubtitleDirectoryPicker(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )
        localTranslationBridge = LocalTranslationBridge(
            messenger = flutterEngine.dartExecutor.binaryMessenger
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            systemProxyChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemProxy" -> result.success(getSystemProxy())
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenAwakeChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            aiBenchmarkChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTelemetry" -> result.success(getAiBenchmarkTelemetry())
                else -> result.notImplemented()
            }
        }
    }

    private fun getAiBenchmarkTelemetry(): Map<String, Any?> {
        val batteryManager =
            getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val powerManager =
            getSystemService(Context.POWER_SERVICE) as PowerManager
        val batteryIntent = registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )

        fun validInt(value: Int): Int? =
            if (value == Int.MIN_VALUE) null else value

        fun validLong(value: Long): Long? =
            if (value == Long.MIN_VALUE) null else value

        val batteryLevel = batteryIntent?.getIntExtra(
            BatteryManager.EXTRA_LEVEL,
            Int.MIN_VALUE
        )
        val batteryScale = batteryIntent?.getIntExtra(
            BatteryManager.EXTRA_SCALE,
            Int.MIN_VALUE
        )

        val batteryPercent = if (
            batteryLevel != null &&
            batteryScale != null &&
            batteryLevel != Int.MIN_VALUE &&
            batteryScale > 0
        ) {
            (batteryLevel * 100.0 / batteryScale)
        } else {
            validInt(
                batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            )?.toDouble()
        }

        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "thermalStatus" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                powerManager.currentThermalStatus
            } else {
                null
            },
            "batteryPercent" to batteryPercent,
            "batteryCurrentMicroAmps" to validInt(
                batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            ),
            "batteryChargeCounterMicroAh" to validInt(
                batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
            ),
            "batteryEnergyCounterNanoWh" to validLong(
                batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
            ),
            "batteryTemperatureTenthsC" to batteryIntent?.getIntExtra(
                BatteryManager.EXTRA_TEMPERATURE,
                Int.MIN_VALUE
            )?.takeIf { it != Int.MIN_VALUE },
            "batteryVoltageMv" to batteryIntent?.getIntExtra(
                BatteryManager.EXTRA_VOLTAGE,
                Int.MIN_VALUE
            )?.takeIf { it != Int.MIN_VALUE },
            "batteryPlugged" to batteryIntent?.getIntExtra(
                BatteryManager.EXTRA_PLUGGED,
                0
            )
        )
    }

    private fun getSystemProxy(): String? {
        val proxySelector = ProxySelector.getDefault() ?: return null
        val urls = listOf(
            URI("https://api.asmr-200.com/"),
            URI("http://api.asmr-200.com/")
        )

        for (url in urls) {
            try {
                val proxy = proxySelector.select(url).firstOrNull {
                    it.type() == Proxy.Type.HTTP
                } ?: continue
                val address = proxy.address() as? InetSocketAddress ?: continue
                return "${address.hostString}:${address.port}"
            } catch (_: Exception) {
                // Try the next URL, then fall back to the legacy JVM properties.
            }
        }

        val host = System.getProperty("http.proxyHost")
        val port = System.getProperty("http.proxyPort")
        return if (!host.isNullOrBlank() && !port.isNullOrBlank()) {
            "$host:$port"
        } else {
            null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (subtitleDirectoryPicker?.handleActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        // 不在 Activity 销毁时清理悬浮窗，以便在后台（如侧滑返回桌面）时保持显示
        // floatingLyricPlugin?.cleanup()
        audioHapticsBridge?.dispose()
        audioHapticsBridge = null
        subtitleDirectoryPicker?.dispose()
        subtitleDirectoryPicker = null
        localTranslationBridge?.dispose()
        localTranslationBridge = null
        super.onDestroy()
    }
}
