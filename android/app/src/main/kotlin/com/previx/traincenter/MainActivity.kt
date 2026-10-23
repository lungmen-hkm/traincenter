package com.previx.traincenter

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity of TrainCenter.
 *
 * Besides the standard Flutter plumbing it exposes a tiny method channel that
 * lets the Dart layer keep the screen awake while a GPS recording is running.
 * The implementation lives in the host app so that TrainCenter does not need
 * an extra plugin dependency for a two line feature.
 */
class MainActivity : FlutterActivity() {

    /** Channel used to toggle the "keep screen on" window flag. */
    private val wakelockChannel = "com.previx.traincenter/wakelock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wakelockChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setKeepScreenOn(enabled)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Adds or removes the `FLAG_KEEP_SCREEN_ON` window flag.
     *
     * @param enabled whether the screen should stay awake.
     */
    private fun setKeepScreenOn(enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }
}
