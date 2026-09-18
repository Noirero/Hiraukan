package com.meteor.kikoeruflutter

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FloatingLyricPlugin private constructor(private val context: Context) : MethodCallHandler {
    companion object {
        const val CHANNEL = "com.kikoeru.flutter/floating_lyric"

        @Volatile
        private var instance: FloatingLyricPlugin? = null

        fun getInstance(context: Context): FloatingLyricPlugin {
            return instance ?: synchronized(this) {
                instance ?: FloatingLyricPlugin(context.applicationContext).also { instance = it }
            }
        }
    }

    private var windowManager: WindowManager? = null
    private var floatingView: FloatingLyricView? = null
    private var isShowing = false
    private var touchEnabled = true
    private var channel: MethodChannel? = null

    init {
        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    fun attachChannel(channel: MethodChannel) {
        this.channel = channel
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "show" -> show(call.argument<String>("text") ?: "♪ - ♪", result)
            "hide" -> hide(result)
            "updateText" -> updateText(call.argument<String>("text") ?: "", result)
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "updateStyle" -> updateStyle(call, result)
            "setTouchEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setTouchEnabled(enabled, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun show(text: String, result: Result) {
        if (!hasPermission()) {
            result.error("NO_PERMISSION", "没有悬浮窗权限", null)
            return
        }

        try {
            if (isShowing) {
                floatingView?.updateText(text)
                result.success(true)
                return
            }

            val params = WindowManager.LayoutParams().apply {
                width = WindowManager.LayoutParams.WRAP_CONTENT
                height = WindowManager.LayoutParams.WRAP_CONTENT
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                format = PixelFormat.TRANSLUCENT
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                x = 0
                y = 100
            }

            floatingView = FloatingLyricView(
                context,
                windowManager!!,
                params,
                touchEnabled,
                { enabled -> handleTouchEnabledChanged(enabled) },
                {
                    hide(null)
                    channel?.invokeMethod("onClose", null)
                }
            )
            floatingView?.updateText(text)
            windowManager?.addView(floatingView as android.view.View, params)
            isShowing = true
            result.success(true)
        } catch (e: Exception) {
            result.error("SHOW_FAILED", "显示悬浮窗失败: ${e.message}", null)
        }
    }

    private fun hide(result: Result?) {
        try {
            if (isShowing && floatingView != null) {
                windowManager?.removeView(floatingView as android.view.View)
                floatingView = null
                isShowing = false
            }
            result?.success(true)
        } catch (e: Exception) {
            result?.error("HIDE_FAILED", "隐藏悬浮窗失败: ${e.message}", null)
        }
    }

    private fun updateText(text: String, result: Result) {
        try {
            if (isShowing && floatingView != null) {
                floatingView?.updateText(text)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("UPDATE_FAILED", "更新文本失败: ${e.message}", null)
        }
    }

    private fun hasPermission(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }

    private fun requestPermission(result: Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                context.startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
                )
                result.success(false)
            } else {
                result.success(true)
            }
        } catch (e: Exception) {
            result.error("REQUEST_FAILED", "请求权限失败: ${e.message}", null)
        }
    }

    private fun updateStyle(call: MethodCall, result: Result) {
        try {
            floatingView?.updateStyle(
                call.argument<Double>("fontSize")?.toFloat(),
                call.argument<Number>("textColor")?.toInt(),
                call.argument<Number>("backgroundColor")?.toInt(),
                call.argument<Double>("cornerRadius")?.toFloat(),
                call.argument<Double>("paddingHorizontal")?.toFloat(),
                call.argument<Double>("paddingVertical")?.toFloat(),
                call.argument<String>("fontFamily"),
                call.argument<Number>("fontWeight")?.toInt(),
                call.argument<Boolean>("shadowEnabled"),
                call.argument<Double>("shadowBlur")?.toFloat(),
                call.argument<Number>("shadowColor")?.toInt(),
                call.argument<Number>("transparencyMode")?.toInt(),
                call.argument<Boolean>("showCloseButton")
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("UPDATE_STYLE_FAILED", "更新样式失败: ${e.message}", null)
        }
    }

    private fun setTouchEnabled(enabled: Boolean, result: Result) {
        try {
            touchEnabled = enabled
            floatingView?.touchEnabled = enabled
            result.success(true)
        } catch (e: Exception) {
            result.error("SET_TOUCH_FAILED", "设置触摸模式失败: ${e.message}", null)
        }
    }

    private fun handleTouchEnabledChanged(enabled: Boolean) {
        touchEnabled = enabled
        channel?.invokeMethod("onTouchEnabledChanged", mapOf("enabled" to enabled))
    }

    fun cleanup() {
        if (isShowing) {
            try {
                windowManager?.removeView(floatingView as android.view.View)
            } catch (_: Exception) {}
            floatingView = null
            isShowing = false
        }
    }
}
