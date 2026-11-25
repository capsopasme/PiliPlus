package com.example.piliplus

import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.view.WindowManager.LayoutParams
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    /** 进入播放页前的窗口底色，离开时恢复 */
    private var savedWindowBackground: Drawable? = null
    private var videoBackground = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "piliplus/window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVideoBackground" -> {
                        setVideoBackground(call.arguments as? Boolean ?: false)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 旋转/全屏切换时，Flutter 按新尺寸重绘之前露出的是窗口底色（浅色主题为白色），
     * 播放页期间换成黑色，避免切换瞬间闪白边。
     */
    private fun setVideoBackground(enable: Boolean) {
        if (enable == videoBackground) return
        videoBackground = enable
        if (enable) {
            savedWindowBackground = window.decorView.background
            window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        } else {
            window.setBackgroundDrawable(savedWindowBackground)
            savedWindowBackground = null
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (AndroidHelper.isFoldable) {
            AndroidHelper.ToDart.onConfigurationChanged?.run()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        AndroidHelper.ToDart.onUserLeaveHint?.run()
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration?) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        AndroidHelper.isPipMode = isInPictureInPictureMode
    }
}
