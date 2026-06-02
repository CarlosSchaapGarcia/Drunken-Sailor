package com.example.drunken_sailor

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.service.ServiceAware
import io.flutter.embedding.engine.plugins.sharedpreferences.SharedPreferencesPlugin
import io.flutter.embedding.engine.plugins.workmanager.WorkmanagerPlugin
import io.flutter.plugin.common.MethodChannel

class VibrationMethodChannel(private val context: Context) {
  companion object {
    private const val CHANNEL = "com.example.drunken_sailor/vibration"
  }

  private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
  private var currentVibration: Long? = null

  fun setupChannel(flutterEngine: FlutterEngine) {
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "startVibration" -> {
            val onDuration = call.argument<Int>("onDuration")?.toLong() ?: 500
            val offDuration = call.argument<Int>("offDuration")?.toLong() ?: 500
            val amplitude = call.argument<Int>("amplitude") ?: 128

            startVibration(onDuration, offDuration, amplitude)
            result(null)
          }
          "stopVibration" -> {
            stopVibration()
            result(null)
          }
          else -> result(null)
        }
      }
  }

  private fun startVibration(onDuration: Long, offDuration: Long, amplitude: Int) {
    stopVibration()

    if (!vibrator.hasVibrator()) {
      return
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      // API 26+: Use VibrationEffect with waveform for smooth, repeating vibration
      val pattern = longArrayOf(0, onDuration, offDuration)
      val amplitudes = intArrayOf(0, amplitude, 0)

      val effect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        // API 33+: Can use repeat index for proper infinite looping
        VibrationEffect.createWaveform(pattern, amplitudes, 1)
      } else {
        // API 26-32: createWaveform with repeat
        VibrationEffect.createWaveform(pattern, amplitudes)
      }

      vibrator.vibrate(effect)
      currentVibration = System.currentTimeMillis()
    } else {
      // Fallback for API < 26: Use deprecated pattern-based vibration
      @Suppress("DEPRECATION")
      vibrator.vibrate(longArrayOf(0, onDuration, offDuration), 1)
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
