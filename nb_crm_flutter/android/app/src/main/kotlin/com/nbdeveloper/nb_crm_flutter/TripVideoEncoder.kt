package com.nbdeveloper.nb_crm_flutter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

class TripVideoEncoder(
    private val width: Int,
    private val height: Int,
    private val fps: Int,
    private val outputFile: File,
) {
    private val mime = MediaFormat.MIMETYPE_VIDEO_AVC
    private lateinit var encoder: MediaCodec
    private lateinit var muxer: MediaMuxer
    private val bufferInfo = MediaCodec.BufferInfo()
    private var trackIndex = -1
    private var muxerStarted = false
    private var frameIndex = 0L
    private var colorFormat = MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar

    fun start() {
        if (width % 2 != 0 || height % 2 != 0) {
            throw IllegalArgumentException("Video size must be even")
        }
        val format = MediaFormat.createVideoFormat(mime, width, height)
        colorFormat = pickColorFormat()
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
        format.setInteger(MediaFormat.KEY_BIT_RATE, 2_800_000)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)

        encoder = MediaCodec.createEncoderByType(mime)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()
        muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    fun addJpegOrPngFrame(imageBytes: ByteArray) {
        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            ?: throw IllegalArgumentException("Could not decode frame")
        val scaled = if (bitmap.width != width || bitmap.height != height) {
            Bitmap.createScaledBitmap(bitmap, width, height, true).also {
                if (it != bitmap) bitmap.recycle()
            }
        } else {
            bitmap
        }
        try {
            val yuv = bitmapToYuv(scaled)
            queueYuv(yuv)
            drainEncoder(false)
            frameIndex++
        } finally {
            scaled.recycle()
        }
    }

    fun finish() {
        val inputIndex = encoder.dequeueInputBuffer(10_000)
        if (inputIndex >= 0) {
            encoder.queueInputBuffer(
                inputIndex,
                0,
                0,
                presentationTimeUs(),
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
        }
        drainEncoder(true)
        try {
            encoder.stop()
        } catch (_: Exception) {
        }
        encoder.release()
        if (muxerStarted) {
            try {
                muxer.stop()
            } catch (_: Exception) {
            }
        }
        muxer.release()
    }

    private fun presentationTimeUs(): Long {
        return frameIndex * 1_000_000L / fps
    }

    private fun queueYuv(yuv: ByteArray) {
        val inputIndex = encoder.dequeueInputBuffer(10_000)
        if (inputIndex < 0) {
            throw IllegalStateException("Encoder input buffer unavailable")
        }
        val input = encoder.getInputBuffer(inputIndex) ?: throw IllegalStateException("Null input buffer")
        input.clear()
        input.put(yuv)
        encoder.queueInputBuffer(inputIndex, 0, yuv.size, presentationTimeUs(), 0)
    }

    private fun drainEncoder(endOfStream: Boolean) {
        var idleTries = 0
        while (true) {
            val outIndex = encoder.dequeueOutputBuffer(bufferInfo, 10_000)
            when {
                outIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    idleTries++
                    if (idleTries > 30) return
                }
                outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (muxerStarted) throw IllegalStateException("Format changed twice")
                    trackIndex = muxer.addTrack(encoder.outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
                outIndex >= 0 -> {
                    val encoded = encoder.getOutputBuffer(outIndex)
                    if (encoded != null && bufferInfo.size > 0 && muxerStarted) {
                        encoded.position(bufferInfo.offset)
                        encoded.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, encoded, bufferInfo)
                    }
                    encoder.releaseOutputBuffer(outIndex, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return
                    }
                }
                else -> return
            }
        }
    }

    private fun pickColorFormat(): Int {
        val codec = MediaCodec.createEncoderByType(mime)
        return try {
            val caps = codec.codecInfo.getCapabilitiesForType(mime)
            val preferred = intArrayOf(
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar,
            )
            for (fmt in preferred) {
                if (caps.colorFormats.contains(fmt)) return fmt
            }
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        } finally {
            codec.release()
        }
    }

    private fun bitmapToYuv(bitmap: Bitmap): ByteArray {
        val w = bitmap.width
        val h = bitmap.height
        val argb = IntArray(w * h)
        bitmap.getPixels(argb, 0, w, 0, 0, w, h)
        val ySize = w * h
        val out = ByteArray(ySize * 3 / 2)
        var uv = ySize
        val planar = colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
        val uPlane = if (planar) ByteArray(ySize / 4) else null
        val vPlane = if (planar) ByteArray(ySize / 4) else null
        var uvPlanar = 0

        var i = 0
        for (y in 0 until h) {
            for (x in 0 until w) {
                val c = argb[i++]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                val yy = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                out[y * w + x] = yy.coerceIn(0, 255).toByte()
                if (y % 2 == 0 && x % 2 == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    if (planar) {
                        uPlane!![uvPlanar] = u.coerceIn(0, 255).toByte()
                        vPlane!![uvPlanar] = v.coerceIn(0, 255).toByte()
                        uvPlanar++
                    } else {
                        // NV12: UU VV interleaved as U, V
                        out[uv++] = u.coerceIn(0, 255).toByte()
                        out[uv++] = v.coerceIn(0, 255).toByte()
                    }
                }
            }
        }
        if (planar) {
            System.arraycopy(uPlane!!, 0, out, ySize, uPlane.size)
            System.arraycopy(vPlane!!, 0, out, ySize + uPlane.size, vPlane.size)
        }
        return out
    }
}
