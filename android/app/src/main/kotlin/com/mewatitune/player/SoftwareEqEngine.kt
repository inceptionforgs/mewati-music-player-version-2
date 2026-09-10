package com.mewatitune.player

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.ryanheise.just_audio.SoftwareEqAudioProcessor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.log10
import kotlin.math.pow
import kotlin.math.sign
import kotlin.math.sin
import kotlin.math.tanh

class SoftwareEqEngine : FlutterPlugin, MethodChannel.MethodCallHandler, SoftwareEqAudioProcessor.Engine {
    private var channel: MethodChannel? = null
    private var bassChannel: EventChannel? = null
    private var bassSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        @Volatile
        var lastApplyArgs: Map<String, Any?>? = null
    }

    @Volatile private var enabled = false
    @Volatile private var bypass = true
    private val bands = Array(10) { Biquad() }
    private val focusBand = Biquad()
    private val defBand = Biquad()
    private val freqs = doubleArrayOf(32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0)
    private var lastGains = DoubleArray(10)
    @Volatile private var bassLin = 1.0
    @Volatile private var width = 1.0
    @Volatile private var truBass = 0.0
    @Volatile private var focusDb = 0.0
    @Volatile private var defDb = 0.0
    @Volatile private var makeupLin = 1.0
    @Volatile private var compress = false
    @Volatile private var haasSamples = 0
    @Volatile private var sampleRate = 44100
    private var haasBuf = FloatArray(96)
    private var haasWrite = 0
    private var headroomLin = 1f
    private var tbLp = 0f
    private var splitLpL = 0f
    private var splitLpR = 0f
    private var rumbleLpL = 0f
    private var rumbleLpR = 0f
    @Volatile private var splitBassOnly = true
    @Volatile private var lowGainLin = 1f
    @Volatile private var truTreble = 0.0
    @Volatile private var highGainLin = 1f
    private var airLpL = 0f
    private var airLpR = 0f
    private val jhanPeak = Biquad()
    private val jhanAir = Biquad()
    private var jhanEnvL = 0f
    private var jhanEnvR = 0f
    private var jhanSlowL = 0f
    private var jhanSlowR = 0f
    private var meterLpL = 0f
    private var meterLpR = 0f
    @Volatile private var bassEnv = 0f
    private var lastBassPost = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "mewati.sound/dsp")
        channel?.setMethodCallHandler(this)
        bassChannel = EventChannel(binding.binaryMessenger, "mewati.sound/bassEnergy")
        bassChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                bassSink = events
                events?.success(bassEnv)
            }
            override fun onCancel(arguments: Any?) {
                bassSink = null
            }
        })
        SoftwareEqAudioProcessor.setEngine(this)
        lastApplyArgs?.let { apply(it) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        bassChannel?.setStreamHandler(null)
        bassChannel = null
        bassSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "init" -> {
                    enabled = true
                    SoftwareEqAudioProcessor.setEngine(this)
                    lastApplyArgs?.let { apply(it) }
                    result.success(true)
                }
                "apply" -> {
                    apply(call.arguments as Map<*, *>)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            enabled = false
            bypass = true
            result.success(false)
        }
    }

    override fun isEnabled(): Boolean = enabled && !bypass

    private val dspLock = Any()

    override fun reset() {
        synchronized(dspLock) {
            for (b in bands) b.reset()
            focusBand.reset()
            defBand.reset()
            haasBuf.fill(0f)
            haasWrite = 0
            headroomLin = 1f
            tbLp = 0f
            splitLpL = 0f
            splitLpR = 0f
            rumbleLpL = 0f
            rumbleLpR = 0f
            airLpL = 0f
            airLpR = 0f
            jhanPeak.reset()
            jhanAir.reset()
            jhanEnvL = 0f
            jhanEnvR = 0f
            jhanSlowL = 0f
            jhanSlowR = 0f
            meterLpL = 0f
            meterLpR = 0f
            bassEnv = 0f
        }
    }

    private fun apply(args: Map<*, *>) {
        synchronized(dspLock) {
        val snap = HashMap<String, Any?>()
        for ((k, v) in args) {
            if (k is String) snap[k] = v
        }
        lastApplyArgs = snap
        headroomLin = 1f
        val gains = (args["gains"] as List<*>).map { (it as Number).toDouble() }
        var allFlat = true
        for (i in freqs.indices) {
            val g = (gains.getOrNull(i) ?: 0.0).coerceIn(-15.0, 15.0)
            lastGains[i] = g
            if (abs(g) > 0.05) allFlat = false
        }
        val bassDb = ((args["bass"] as Number?)?.toDouble() ?: 0.0).coerceIn(0.0, 6.0)
        bassLin = 10.0.pow(bassDb / 20.0)
        width = ((args["width"] as Number?)?.toDouble() ?: 1.0).coerceIn(0.85, 1.85)
        truBass = ((args["truBass"] as Number?)?.toDouble() ?: 0.0).coerceIn(0.0, 1.0)
        focusDb = ((args["focus"] as Number?)?.toDouble() ?: 0.0).coerceIn(-12.0, 12.0)
        defDb = ((args["definition"] as Number?)?.toDouble() ?: 0.0).coerceIn(-12.0, 12.0)
        compress = args["compress"] as Boolean? ?: false
        val haas = ((args["haas"] as Number?)?.toDouble() ?: 0.0).coerceIn(0.0, 0.0022)
        haasSamples = (haas * sampleRate).toInt().coerceIn(0, haasBuf.size - 1)
        var maxBoost = bassDb
        for (g in lastGains) if (g > maxBoost) maxBoost = g
        val userMakeup = ((args["makeup"] as Number?)?.toDouble() ?: 0.0)
        val autoDb = -maxBoost.coerceAtLeast(0.0) * 0.9
        makeupLin = 10.0.pow((userMakeup + autoDb) / 20.0)
        var midFx = abs(focusDb) > 0.05 || abs(defDb) > 0.05 || compress ||
            haasSamples > 0 || abs(width - 1.0) > 0.02
        if (!midFx) {
            for (i in 2 until lastGains.size) {
                if (abs(lastGains[i]) > 0.05) {
                    midFx = true
                    break
                }
            }
        }
        splitBassOnly = !midFx
        var lowDb = bassDb
        if (lastGains[0] > lowDb) lowDb = lastGains[0]
        if (lastGains[1] > lowDb) lowDb = lastGains[1]
        lowGainLin = 10.0.pow(lowDb.coerceAtLeast(0.0) / 20.0).toFloat()
        val airDb = ((args["air"] as Number?)?.toDouble() ?: 0.0).coerceIn(0.0, 15.0)
        truTreble = ((args["truTreble"] as Number?)?.toDouble() ?: 0.0).coerceIn(0.0, 1.0)
        highGainLin = 10.0.pow(airDb / 20.0).toFloat()
        rebuildFilters()
        bypass = allFlat &&
            bassDb < 0.05 &&
            truBass < 0.01 &&
            airDb < 0.05 &&
            truTreble < 0.01 &&
            abs(width - 1.0) < 0.01 &&
            abs(focusDb) < 0.05 &&
            abs(defDb) < 0.05 &&
            abs(makeupLin - 1.0) < 0.01 &&
            !compress &&
            haasSamples == 0
        enabled = true
        SoftwareEqAudioProcessor.setEngine(this)
        }
    }

    private fun rebuildFilters() {
        val sr = sampleRate.toDouble().coerceAtLeast(8000.0)
        for (i in freqs.indices) {
            val type = when (i) {
                0 -> Biquad.Type.LOWSHELF
                freqs.lastIndex -> Biquad.Type.HIGHSHELF
                else -> Biquad.Type.PEAK
            }
            bands[i].set(type, freqs[i], lastGains[i], sr)
        }
        focusBand.set(Biquad.Type.PEAK, 3200.0, focusDb, sr)
        defBand.set(Biquad.Type.HIGHSHELF, 8000.0, defDb, sr)
        val airDb = if (highGainLin <= 1.001f) 0.0 else 20.0 * log10(highGainLin.toDouble())
        jhanPeak.set(Biquad.Type.PEAK, 8800.0, airDb * 0.90, sr, 2.8)
        jhanAir.set(Biquad.Type.PEAK, 8800.0, 0.0, sr, 2.8)
        val haas = haasSamples.toDouble() / sampleRate.coerceAtLeast(1)
        haasSamples = (haas * sampleRate).toInt().coerceIn(0, haasBuf.size - 1)
    }

    override fun processInterleaved(pcm: ShortArray, frames: Int, channels: Int, sr: Int) {
        if (!isEnabled()) return
        synchronized(dspLock) {
            if (sr > 0 && sr != sampleRate) {
                sampleRate = sr
                rebuildFilters()
            }
            if (frames <= 0 || channels <= 0) return
            if (channels > 2) return
            if (channels == 1) {
                if (splitBassOnly) processMonoSplit(pcm, frames) else processMono(pcm, frames)
            } else {
                if (splitBassOnly) processStereoSplit(pcm, frames, channels) else processStereo(pcm, frames, channels)
            }
        }
    }

    private fun applyHeadroom(
        pcm: ShortArray,
        frames: Int,
        channels: Int,
        dryPeak: Float,
        wetPeak: Float,
        matchDry: Boolean,
    ) {
        val ceiling = if (matchDry) minOf(0.89f, dryPeak.coerceAtLeast(1.0e-6f)) else 0.89f
        val need = if (wetPeak > ceiling) ceiling / wetPeak else 1f
        headroomLin += (need - headroomLin) * 0.12f
        val g = headroomLin
        if (g > 0.997f && need >= 0.997f) {
            headroomLin = 1f
            return
        }
        var i = 0
        for (n in 0 until frames) {
            if (channels == 1) {
                pcm[n] = (pcm[n].toFloat() * g).toInt().coerceIn(-32767, 32767).toShort()
            } else {
                pcm[i] = (pcm[i].toFloat() * g).toInt().coerceIn(-32767, 32767).toShort()
                pcm[i + 1] = (pcm[i + 1].toFloat() * g).toInt().coerceIn(-32767, 32767).toShort()
                i += channels
            }
        }
    }

    private fun splitAlpha(): Float =
        (2.0 * PI * 150.0 / sampleRate).toFloat().coerceIn(0.02f, 0.35f)

    private fun rumbleAlpha(): Float =
        (2.0 * PI * 60.0 / sampleRate).toFloat().coerceIn(0.008f, 0.18f)

    private fun airAlpha(): Float =
        (2.0 * PI * 4800.0 / sampleRate).toFloat().coerceIn(0.20f, 0.85f)

    private fun meterBass(absBody: Float) {
        bassEnv += 0.22f * ((absBody * 3.4f).coerceAtMost(1f) - bassEnv)
        val now = SystemClock.uptimeMillis()
        if (now - lastBassPost < 32) return
        lastBassPost = now
        val v = bassEnv
        mainHandler.post { bassSink?.success(v) }
    }

    private fun processMonoSplit(pcm: ShortArray, frames: Int) {
        val tb = truBass * 0.92
        val tt = truTreble * 0.92
        val gLow = lowGainLin
        val gHigh = highGainLin
        val doBass = gLow > 1.01f || tb > 0.001
        val doTreble = gHigh > 1.01f || tt > 0.001
        val aLow = splitAlpha()
        val aRumble = rumbleAlpha()
        val aAir = airAlpha()
        var dryPeak = 1.0e-6f
        var wetPeak = 1.0e-6f
        for (n in 0 until frames) {
            val dry = pcm[n].toFloat() / 32768f
            val ad = abs(dry)
            if (ad > dryPeak) dryPeak = ad
            meterLpL += aLow * (dry - meterLpL)
            meterBass(abs(meterLpL))
            var s = dry
            if (doBass) {
                splitLpL += aLow * (dry - splitLpL)
                rumbleLpL += aRumble * (dry - rumbleLpL)
                val body = splitLpL
                val rumble = rumbleLpL
                val punch = body - rumble
                var el = rumble * 0.55f + punch * gLow
                if (tb > 0.001) {
                    tbLp += aLow * (punch * gLow - tbLp)
                    el += tanh(tbLp * 1.15f + 0.62f * tbLp * tbLp * sign(tbLp) + 0.06f * tbLp * tbLp * tbLp) * tb.toFloat()
                }
                s = (dry - body) + el
            }
            if (doTreble) {
                airLpL += aAir * (s - airLpL)
                val high = s - airLpL
                val body = airLpL
                val spark = jhanPeak.tickL(high)
                val mag = abs(spark)
                if (mag > jhanEnvL) jhanEnvL = mag else jhanEnvL += 0.28f * (mag - jhanEnvL)
                jhanSlowL += 0.007f * (mag - jhanSlowL)
                val hit = (jhanEnvL - jhanSlowL).coerceAtLeast(0f)
                val punch = (gHigh - 1f).coerceAtLeast(0f)
                var eh = high * (1f + punch * 0.30f) + spark * punch * (0.40f + hit * 6.2f)
                if (tt > 0.001) {
                    eh += tanh(spark * (0.40f + hit * 2.2f)) * tt.toFloat()
                }
                s = body + eh
            }
            val aw = abs(s)
            if (aw > wetPeak) wetPeak = aw
            pcm[n] = (s.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
        }
        applyHeadroom(pcm, frames, 1, dryPeak, wetPeak, matchDry = false)
    }

    private fun processStereoSplit(pcm: ShortArray, frames: Int, channels: Int) {
        val tb = truBass * 0.92
        val tt = truTreble * 0.92
        val gLow = lowGainLin
        val gHigh = highGainLin
        val doBass = gLow > 1.01f || tb > 0.001
        val doTreble = gHigh > 1.01f || tt > 0.001
        val aLow = splitAlpha()
        val aRumble = rumbleAlpha()
        val aAir = airAlpha()
        var dryPeak = 1.0e-6f
        var wetPeak = 1.0e-6f
        var i = 0
        for (n in 0 until frames) {
            val dryL = pcm[i].toFloat() / 32768f
            val dryR = pcm[i + 1].toFloat() / 32768f
            val ad = maxOf(abs(dryL), abs(dryR))
            if (ad > dryPeak) dryPeak = ad
            meterLpL += aLow * (dryL - meterLpL)
            meterLpR += aLow * (dryR - meterLpR)
            meterBass(maxOf(abs(meterLpL), abs(meterLpR)))
            var ol = dryL
            var orr = dryR
            if (doBass) {
                splitLpL += aLow * (dryL - splitLpL)
                splitLpR += aLow * (dryR - splitLpR)
                rumbleLpL += aRumble * (dryL - rumbleLpL)
                rumbleLpR += aRumble * (dryR - rumbleLpR)
                val bodyL = splitLpL
                val bodyR = splitLpR
                val punchL = bodyL - rumbleLpL
                val punchR = bodyR - rumbleLpR
                var el = rumbleLpL * 0.55f + punchL * gLow
                var er = rumbleLpR * 0.55f + punchR * gLow
                if (tb > 0.001) {
                    val mono = (punchL + punchR) * 0.5f * gLow
                    tbLp += aLow * (mono - tbLp)
                    val add = tanh(tbLp * 1.15f + 0.62f * tbLp * tbLp * sign(tbLp) + 0.06f * tbLp * tbLp * tbLp) * tb.toFloat()
                    el += add
                    er += add
                }
                ol = (dryL - bodyL) + el
                orr = (dryR - bodyR) + er
            }
            if (doTreble) {
                airLpL += aAir * (ol - airLpL)
                airLpR += aAir * (orr - airLpR)
                val highL = ol - airLpL
                val highR = orr - airLpR
                val sparkL = jhanPeak.tickL(highL)
                val sparkR = jhanPeak.tickR(highR)
                val magL = abs(sparkL)
                val magR = abs(sparkR)
                if (magL > jhanEnvL) jhanEnvL = magL else jhanEnvL += 0.28f * (magL - jhanEnvL)
                if (magR > jhanEnvR) jhanEnvR = magR else jhanEnvR += 0.28f * (magR - jhanEnvR)
                jhanSlowL += 0.007f * (magL - jhanSlowL)
                jhanSlowR += 0.007f * (magR - jhanSlowR)
                val hitL = (jhanEnvL - jhanSlowL).coerceAtLeast(0f)
                val hitR = (jhanEnvR - jhanSlowR).coerceAtLeast(0f)
                val punch = (gHigh - 1f).coerceAtLeast(0f)
                var ehL = highL * (1f + punch * 0.30f) + sparkL * punch * (0.40f + hitL * 6.2f)
                var ehR = highR * (1f + punch * 0.30f) + sparkR * punch * (0.40f + hitR * 6.2f)
                if (tt > 0.001) {
                    ehL += tanh(sparkL * (0.40f + hitL * 2.2f)) * tt.toFloat()
                    ehR += tanh(sparkR * (0.40f + hitR * 2.2f)) * tt.toFloat()
                }
                ol = airLpL + ehL
                orr = airLpR + ehR
            }
            val aw = maxOf(abs(ol), abs(orr))
            if (aw > wetPeak) wetPeak = aw
            pcm[i] = (ol.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            pcm[i + 1] = (orr.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            i += channels
        }
        applyHeadroom(pcm, frames, channels, dryPeak, wetPeak, matchDry = false)
    }

    private fun processMono(pcm: ShortArray, frames: Int) {
        val tb = truBass * 0.92
        val mk = makeupLin.toFloat()
        val bass = bassLin.toFloat()
        val aLow = splitAlpha()
        var dryPeak = 1.0e-6f
        var wetPeak = 1.0e-6f
        for (n in 0 until frames) {
            val dry = pcm[n].toFloat() / 32768f
            val ad = abs(dry)
            if (ad > dryPeak) dryPeak = ad
            meterLpL += aLow * (dry - meterLpL)
            meterBass(abs(meterLpL))
            var s = dry
            for (b in bands) s = b.tickL(s)
            s = focusBand.tickL(s)
            s = defBand.tickL(s)
            s *= bass
            if (tb > 0.001) {
                val a = (2.0 * PI * 150.0 / sampleRate).toFloat().coerceIn(0.02f, 0.35f)
                tbLp += a * (s - tbLp)
                s += (tanh(tbLp * 1.15f + 0.62f * tbLp * tbLp * sign(tbLp) + 0.06f * tbLp * tbLp * tbLp) * tb.toFloat())
            }
            s *= mk
            if (compress) s = tanh(s * 1.15f)
            val aw = abs(s)
            if (aw > wetPeak) wetPeak = aw
            pcm[n] = (s.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
        }
        applyHeadroom(pcm, frames, 1, dryPeak, wetPeak, matchDry = true)
    }

    private fun processStereo(pcm: ShortArray, frames: Int, channels: Int) {
        val tb = truBass * 0.92
        val w = width
        val delay = haasSamples
        val mk = makeupLin.toFloat()
        val bass = bassLin.toFloat()
        val aLow = splitAlpha()
        var dryPeak = 1.0e-6f
        var wetPeak = 1.0e-6f
        var i = 0
        for (n in 0 until frames) {
            val dryL = pcm[i].toFloat() / 32768f
            val dryR = pcm[i + 1].toFloat() / 32768f
            val ad = maxOf(abs(dryL), abs(dryR))
            if (ad > dryPeak) dryPeak = ad
            meterLpL += aLow * (dryL - meterLpL)
            meterLpR += aLow * (dryR - meterLpR)
            meterBass(maxOf(abs(meterLpL), abs(meterLpR)))
            var l = dryL
            var r = dryR
            for (b in bands) {
                l = b.tickL(l)
                r = b.tickR(r)
            }
            l = focusBand.tickL(l)
            r = focusBand.tickR(r)
            l = defBand.tickL(l)
            r = defBand.tickR(r)
            l *= bass
            r *= bass
            if (tb > 0.001) {
                val mono = (l + r) * 0.5f
                val a = (2.0 * PI * 150.0 / sampleRate).toFloat().coerceIn(0.02f, 0.35f)
                tbLp += a * (mono - tbLp)
                val harm = tanh(tbLp * 1.15f + 0.62f * tbLp * tbLp * sign(tbLp) + 0.06f * tbLp * tbLp * tbLp)
                val add = harm * tb.toFloat()
                l += add
                r += add
            }
            val mid = (l + r) * 0.5f
            var side = (l - r) * 0.5f * w.toFloat()
            if (delay > 0) {
                val idx = (haasWrite + haasBuf.size - delay) % haasBuf.size
                val delayed = haasBuf[idx]
                haasBuf[haasWrite] = side
                haasWrite = (haasWrite + 1) % haasBuf.size
                side = delayed
            }
            var ol = (mid + side) * mk
            var orr = (mid - side) * mk
            if (compress) {
                ol = tanh(ol * 1.15f)
                orr = tanh(orr * 1.15f)
            }
            val aw = maxOf(abs(ol), abs(orr))
            if (aw > wetPeak) wetPeak = aw
            pcm[i] = (ol.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            pcm[i + 1] = (orr.coerceIn(-1f, 1f) * 32767f).toInt().toShort()
            i += channels
        }
        applyHeadroom(pcm, frames, channels, dryPeak, wetPeak, matchDry = true)
    }

    private class Biquad {
        enum class Type { PEAK, LOWSHELF, HIGHSHELF }

        private data class Coeffs(
            val b0: Double,
            val b1: Double,
            val b2: Double,
            val a1: Double,
            val a2: Double,
        )

        private val coeffs = java.util.concurrent.atomic.AtomicReference(
            Coeffs(1.0, 0.0, 0.0, 0.0, 0.0),
        )
        private var x1l = 0.0; private var x2l = 0.0; private var y1l = 0.0; private var y2l = 0.0
        private var x1r = 0.0; private var x2r = 0.0; private var y1r = 0.0; private var y2r = 0.0

        fun reset() {
            x1l = 0.0; x2l = 0.0; y1l = 0.0; y2l = 0.0
            x1r = 0.0; x2r = 0.0; y1r = 0.0; y2r = 0.0
        }

        fun set(type: Type, hz: Double, gainDb: Double, sr: Double, qIn: Double? = null) {
            val a = 10.0.pow(gainDb / 40.0)
            val w0 = 2.0 * PI * hz / sr
            val cosw = cos(w0)
            val sinw = sin(w0)
            val q = qIn ?: if (type == Type.PEAK) 1.4 else 0.9
            val alpha = sinw / (2.0 * q)
            val next: Coeffs = when (type) {
                Type.PEAK -> {
                    val a0 = 1 + alpha / a
                    Coeffs(
                        b0 = (1 + alpha * a) / a0,
                        b1 = -2 * cosw / a0,
                        b2 = (1 - alpha * a) / a0,
                        a1 = -2 * cosw / a0,
                        a2 = (1 - alpha / a) / a0,
                    )
                }
                Type.LOWSHELF -> {
                    val sqrtA = kotlin.math.sqrt(a)
                    val a0 = (a + 1) + (a - 1) * cosw + 2 * sqrtA * alpha
                    Coeffs(
                        b0 = a * ((a + 1) - (a - 1) * cosw + 2 * sqrtA * alpha) / a0,
                        b1 = 2 * a * ((a - 1) - (a + 1) * cosw) / a0,
                        b2 = a * ((a + 1) - (a - 1) * cosw - 2 * sqrtA * alpha) / a0,
                        a1 = -2 * ((a - 1) + (a + 1) * cosw) / a0,
                        a2 = ((a + 1) + (a - 1) * cosw - 2 * sqrtA * alpha) / a0,
                    )
                }
                Type.HIGHSHELF -> {
                    val sqrtA = kotlin.math.sqrt(a)
                    val a0 = (a + 1) - (a - 1) * cosw + 2 * sqrtA * alpha
                    Coeffs(
                        b0 = a * ((a + 1) + (a - 1) * cosw + 2 * sqrtA * alpha) / a0,
                        b1 = -2 * a * ((a - 1) + (a + 1) * cosw) / a0,
                        b2 = a * ((a + 1) + (a - 1) * cosw - 2 * sqrtA * alpha) / a0,
                        a1 = 2 * ((a - 1) - (a + 1) * cosw) / a0,
                        a2 = ((a + 1) - (a - 1) * cosw - 2 * sqrtA * alpha) / a0,
                    )
                }
            }
            coeffs.set(next)
        }

        fun tickL(x: Float): Float {
            val c = coeffs.get()
            val y = c.b0 * x + c.b1 * x1l + c.b2 * x2l - c.a1 * y1l - c.a2 * y2l
            x2l = x1l; x1l = x.toDouble(); y2l = y1l; y1l = y
            return y.toFloat()
        }

        fun tickR(x: Float): Float {
            val c = coeffs.get()
            val y = c.b0 * x + c.b1 * x1r + c.b2 * x2r - c.a1 * y1r - c.a2 * y2r
            x2r = x1r; x1r = x.toDouble(); y2r = y1r; y1r = y
            return y.toFloat()
        }
    }
}