package com.nbdeveloper.nb_crm_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "nb_crm/trip_video"
    private val encoderExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var encoder: TripVideoEncoder? = null
    private var outputFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val width = call.argument<Int>("width") ?: 1280
                        val height = call.argument<Int>("height") ?: 720
                        val fps = call.argument<Int>("fps") ?: 12
                        encoderExecutor.execute {
                            try {
                                encoder?.finish()
                            } catch (_: Exception) {
                            }
                            try {
                                val file = File(cacheDir, "trip_${System.currentTimeMillis()}.mp4")
                                if (file.exists()) file.delete()
                                val enc = TripVideoEncoder(width, height, fps, file)
                                enc.start()
                                encoder = enc
                                outputFile = file
                                mainHandler.post { result.success(file.absolutePath) }
                            } catch (e: Exception) {
                                encoder = null
                                outputFile = null
                                mainHandler.post { result.error("start_failed", e.message, null) }
                            }
                        }
                    }
                    "addFrame" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("bad_args", "Missing frame bytes", null)
                            return@setMethodCallHandler
                        }
                        encoderExecutor.execute {
                            try {
                                val enc = encoder ?: throw IllegalStateException("Encoder not started")
                                enc.addJpegOrPngFrame(bytes)
                                mainHandler.post { result.success(true) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("frame_failed", e.message, null) }
                            }
                        }
                    }
                    "finish" -> {
                        encoderExecutor.execute {
                            try {
                                encoder?.finish()
                                val path = outputFile?.absolutePath
                                encoder = null
                                mainHandler.post { result.success(path) }
                            } catch (e: Exception) {
                                encoder = null
                                mainHandler.post { result.error("finish_failed", e.message, null) }
                            }
                        }
                    }
                    "cancel" -> {
                        encoderExecutor.execute {
                            try {
                                encoder?.finish()
                            } catch (_: Exception) {
                            }
                            encoder = null
                            outputFile?.delete()
                            outputFile = null
                            mainHandler.post { result.success(true) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
