package com.mewatitune.player

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var volumeEvents: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(SoftwareEqEngine())

        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mewati.sound/volume")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> result.success(systemVolume(am))
                    "max" -> result.success(
                        am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1),
                    )
                    "locked" -> result.success(keyguardLocked())
                    "set" -> {
                        // Lock screen owns STREAM_MUSIC. Writing it here fights the
                        // hardware buttons and snaps volume (often to full).
                        if (keyguardLocked()) {
                            result.success(systemVolume(am))
                        } else {
                            val v = (call.arguments as? Number)?.toDouble() ?: 0.0
                            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
                            am.setStreamVolume(
                                AudioManager.STREAM_MUSIC,
                                (v.coerceIn(0.0, 1.0) * max).toInt(),
                                0,
                            )
                            result.success(systemVolume(am))
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "mewati.sound/volumeEvents")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEvents = events
                    events?.success(systemVolume(am))
                    if (receiver == null) {
                        receiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context?, intent: Intent?) {
                                val type = intent?.getIntExtra(
                                    "android.media.EXTRA_VOLUME_STREAM_TYPE",
                                    -1,
                                ) ?: -1
                                if (type != -1 && type != AudioManager.STREAM_MUSIC) return
                                volumeEvents?.success(systemVolume(am))
                            }
                        }
                        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
                        if (Build.VERSION.SDK_INT >= 33) {
                            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                        } else {
                            @Suppress("DEPRECATION")
                            registerReceiver(receiver, filter)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    volumeEvents = null
                    receiver?.let {
                        try {
                            unregisterReceiver(it)
                        } catch (_: Exception) {
                        }
                    }
                    receiver = null
                }
            })
    }

    private fun keyguardLocked(): Boolean {
        val km = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        return km.isKeyguardLocked
    }

    private fun systemVolume(am: AudioManager): Double {
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        return am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max
    }
}