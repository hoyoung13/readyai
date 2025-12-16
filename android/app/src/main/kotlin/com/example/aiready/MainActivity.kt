package com.example.aiready

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val audioChannelName = "ai/interview_audio"
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var tts: TextToSpeech? = null
    private var ttsReady: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannelName)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareAudio" -> result.success(prepareAudioRouting())
            "restoreAudio" -> {
                restoreAudioRouting()
                result.success(null)
            }
            "initTts" -> initTts(result)
            "speakText" -> {
                val text: String? = call.argument("text")
                speakText(text, result)
            }
            "stopTts" -> {
                tts?.stop()
                result.success(null)
            }
            "shutdownTts" -> {
                shutdownTts()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun prepareAudioRouting(): Boolean {
        val manager = audioManager ?: return false
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            .setAudioAttributes(attrs)
            .setOnAudioFocusChangeListener { /* no-op */ }
            .setWillPauseWhenDucked(true)
            .build()

        val granted = manager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        audioFocusRequest = request

        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        manager.isSpeakerphoneOn = true
        return granted
    }

    private fun restoreAudioRouting() {
        val manager = audioManager ?: return
        audioFocusRequest?.let { manager.abandonAudioFocusRequest(it) }
        audioFocusRequest = null
        manager.mode = AudioManager.MODE_NORMAL
        manager.isSpeakerphoneOn = false
    }

    private fun initTts(result: MethodChannel.Result) {
        if (tts != null && ttsReady) {
            result.success(null)
            return
        }

        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            tts?.language = Locale.KOREAN
            tts?.setSpeechRate(0.5f)
            tts?.setPitch(1.0f)

            val attrsBuilder = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .setLegacyStreamType(AudioManager.STREAM_ACCESSIBILITY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                attrsBuilder.setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_NONE)
            }
            tts?.setAudioAttributes(attrsBuilder.build())

            result.success(null)
        }
    }

    private fun speakText(text: String?, result: MethodChannel.Result) {
        if (!ttsReady || text.isNullOrBlank()) {
            result.error("TTS_NOT_READY", "TTS is not ready", null)
            return
        }
        tts?.stop()
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "interview-question")
        result.success(null)
    }

    private fun shutdownTts() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false
    }
}
