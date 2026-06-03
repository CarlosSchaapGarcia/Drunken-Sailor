package com.example.drunken_sailor

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class VibrationMethodChannel(private val context: Context) {
  companion object {
    private const val CHANNEL = "com.example.drunken_sailor/vibration"
  }

  private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
  private var currentVibration: Long? = null

  fun setupChannel(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, resultHandler ->
        when (call.method) {
          "startVibration" -> {
            val onDuration = call.argument<Int>("onDuration")?.toLong() ?: 500
            val offDuration = call.argument<Int>("offDuration")?.toLong() ?: 500
            val amplitude = call.argument<Int>("amplitude") ?: 128

            startVibration(onDuration, offDuration, amplitude)
            resultHandler.success(null)
          }
          "stopVibration" -> {
            stopVibration()
            resultHandler.success(null)
          }
          else -> resultHandler.notImplemented()
        }
      }
  }

  private fun startVibration(onDuration: Long, offDuration: Long, amplitude: Int) {
    stopVibration()

    if (!vibrator.hasVibrator()) {
      return
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      // API 26+: Use VibrationEffect with waveform
      val pattern = longArrayOf(0, onDuration, offDuration)

      val effect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        // API 33+: createWaveform with amplitudes and repeat index
        val amplitudes = intArrayOf(0, amplitude, 0)
        VibrationEffect.createWaveform(pattern, amplitudes, 1)
      } else {
        // API 26-32: createWaveform with timings only
        VibrationEffect.createWaveform(pattern, 0)
      }

      vibrator.vibrate(effect)
      currentVibration = System.currentTimeMillis()
    } else {
      // Fallback for API < 26: Use deprecated pattern-based vibration
      @Suppress("DEPRECATION")
      val pattern = longArrayOf(0, onDuration, offDuration)
      vibrator.vibrate(pattern, 1)
      currentVibration = System.currentTimeMillis()
    }
  }

  private fun stopVibration() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB_MR1) {
      vibrator.cancel()
    }
    currentVibration = null
  }

  fun dispose() {
    stopVibration()
  }
}
