package com.previx.traincenter

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Host activity of TrainCenter.
 *
 * Besides the standard Flutter plumbing it exposes three tiny method channels:
 * one keeps the screen awake while a GPS recording is running, one requests the
 * Android 13+ notification permission for the foreground tracking notification,
 * and one saves exported PNGs in the public Downloads folder. The implementation
 * lives in the host app so that TrainCenter does not need extra plugin
 * dependencies for these small features.
 */
class MainActivity : FlutterActivity() {

    /** Channel used to toggle the "keep screen on" window flag. */
    private val wakelockChannel = "com.previx.traincenter/wakelock"

    /** Channel used to request the Android 13+ notification permission. */
    private val permissionChannel = "com.previx.traincenter/permissions"

    /** Channel used to save exported PNGs in the public Downloads folder. */
    private val downloadsChannel = "com.previx.traincenter/downloads"

    /** Result of the notification permission dialog while it is open. */
    private var notificationPermissionResult: MethodChannel.Result? = null

    /** Pending download while the storage permission dialog is open (API < 29). */
    private var pendingDownloadResult: MethodChannel.Result? = null
    private var pendingDownloadBytes: ByteArray? = null
    private var pendingDownloadFileName: String? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" ->
                        requestNotificationPermission(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePngToDownloads" -> savePngToDownloads(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Requests `POST_NOTIFICATIONS` on Android 13+.
     *
     * Reports `true` immediately on older versions and when the permission is
     * already granted. Otherwise the result is delivered through
     * [onRequestPermissionsResult].
     */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        // A dialog is already open: do not stack a second request.
        if (notificationPermissionResult != null) {
            result.success(false)
            return
        }
        notificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    /**
     * Saves a PNG in the public Downloads folder.
     *
     * Android 10+ writes through MediaStore, so no storage permission is
     * needed. Android 9 and older first asks for `WRITE_EXTERNAL_STORAGE`;
     * the write is completed from [onRequestPermissionsResult].
     */
    private fun savePngToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val fileName = call.argument<String>("fileName")
        if (bytes == null || fileName.isNullOrBlank()) {
            result.error("invalid_arguments", "Missing PNG bytes or file name.", null)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingDownloadResult != null) {
                result.error(
                    "busy",
                    "Another image is already waiting for storage permission.",
                    null,
                )
                return
            }
            pendingDownloadResult = result
            pendingDownloadBytes = bytes
            pendingDownloadFileName = fileName
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST_CODE,
            )
            return
        }

        try {
            result.success(writePng(bytes, fileName))
        } catch (error: Exception) {
            result.error(
                "save_failed",
                error.message ?: "Could not save the image.",
                null,
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                notificationPermissionResult?.success(granted)
                notificationPermissionResult = null
            }
            STORAGE_PERMISSION_REQUEST_CODE -> completePendingDownload(grantResults)
        }
    }

    /** Finishes a save request that was waiting for storage permission. */
    private fun completePendingDownload(grantResults: IntArray) {
        val result = pendingDownloadResult ?: return
        val bytes = pendingDownloadBytes
        val fileName = pendingDownloadFileName
        pendingDownloadResult = null
        pendingDownloadBytes = null
        pendingDownloadFileName = null

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            result.error(
                "permission_denied",
                "Allow storage access to save images in Downloads.",
                null,
            )
            return
        }
        if (bytes == null || fileName.isNullOrBlank()) {
            result.error("invalid_arguments", "The pending image data was lost.", null)
            return
        }

        try {
            result.success(writePng(bytes, fileName))
        } catch (error: Exception) {
            result.error(
                "save_failed",
                error.message ?: "Could not save the image.",
                null,
            )
        }
    }

    /** Writes the PNG using the storage API that matches the Android version. */
    private fun writePng(bytes: ByteArray, fileName: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            writePngToMediaStore(bytes, fileName)
        } else {
            writePngToLegacyDownloads(bytes, fileName)
        }
    }

    /** Android 10+: publishes the image through the Downloads collection. */
    private fun writePngToMediaStore(bytes: ByteArray, fileName: String): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "image/png")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val collection = MediaStore.Downloads.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        val uri = resolver.insert(collection, values)
            ?: throw IOException("The Downloads collection rejected the image.")

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IOException("Could not open the Downloads file for writing.")

            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }

        val savedName = displayName(uri) ?: fileName
        return "Downloads/$savedName"
    }

    /** Reads the name MediaStore actually assigned to [uri]. */
    private fun displayName(uri: Uri): String? {
        val projection = arrayOf(MediaStore.Downloads.DISPLAY_NAME)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)
            }
        }
        return null
    }

    /** Android 9 and older: writes directly to the public Downloads folder. */
    @Suppress("DEPRECATION")
    private fun writePngToLegacyDownloads(bytes: ByteArray, fileName: String): String {
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        if (!downloads.exists() && !downloads.mkdirs()) {
            throw IOException("Could not create the Downloads folder.")
        }

        val file = uniqueFile(downloads, fileName)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(file.absolutePath),
            arrayOf("image/png"),
            null,
        )
        return "Downloads/${file.name}"
    }

    /** Avoids overwriting an existing export with the same name. */
    private fun uniqueFile(directory: File, fileName: String): File {
        var candidate = File(directory, fileName)
        if (!candidate.exists()) return candidate

        val base = fileName.substringBeforeLast('.', fileName)
        val extension = fileName.substringAfterLast('.', "")
        val suffix = if (extension.isEmpty()) "" else ".$extension"
        var index = 1
        while (candidate.exists()) {
            candidate = File(directory, "${base}_$index$suffix")
            index++
        }
        return candidate
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

    private companion object {
        /** Request code for the Android 13+ notification permission dialog. */
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4301

        /** Request code for the pre-Android 10 storage permission dialog. */
        const val STORAGE_PERMISSION_REQUEST_CODE = 4302
    }
}
