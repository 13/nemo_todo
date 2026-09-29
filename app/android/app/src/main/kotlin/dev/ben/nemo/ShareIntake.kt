package dev.ben.nemo

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Hands what another app shares with nemo to the Dart side, which turns it
 * into a draft task (lib/features/share).
 *
 * Dart asks for the share that started the activity with `initial`; one
 * arriving while the app runs is pushed to it as `shared`. Either way the
 * payload is `{text, subject, images}`, the pictures as raw bytes: Dart
 * re-encodes them through the same pipeline as the camera, so nothing here
 * decodes or keeps them.
 */
class ShareIntake :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener {
    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    /** The launch intent's share, until Dart has taken it. */
    private var initial: Shared? = null
    private var initialRead = false

    private class Shared(val text: String?, val subject: String?, val uris: List<Uri>)

    override fun onAttachedToEngine(flutter: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutter.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(flutter: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        io.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
        // Only the first attachment's intent is the launch; a later one
        // (after a configuration change) carries the same, already taken.
        if (!initialRead) {
            initialRead = true
            initial = read(binding.activity.intent)
        }
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addOnNewIntentListener(this)
    }

    private fun detach() {
        binding?.removeOnNewIntentListener(this)
        binding = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        val shared = read(intent) ?: return false
        load(shared) { payload -> channel?.invokeMethod("shared", payload) }
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initial" -> {
                val shared = initial
                initial = null
                if (shared == null) result.success(null) else load(shared, result::success)
            }
            else -> result.notImplemented()
        }
    }

    /** What [intent] shares, or null when it is not a share. */
    private fun read(intent: Intent?): Shared? {
        if (intent == null) return null
        // Reopened from the recent apps list: the same intent again, which
        // was already handled (or dismissed) when it was new.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val uris = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(stream(intent))
            Intent.ACTION_SEND_MULTIPLE -> streams(intent)
            else -> return null
        }
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        if (text.isNullOrBlank() && subject.isNullOrBlank() && uris.isEmpty()) return null
        return Shared(text, subject, uris)
    }

    @Suppress("DEPRECATION")
    private fun stream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): List<Uri> =
        (
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
        )?.toList() ?: emptyList()

    /**
     * Reads the pictures' bytes off the main thread -- a provider may be
     * slow, or remote -- and hands the payload back on it.
     */
    private fun load(shared: Shared, done: (Map<String, Any?>) -> Unit) {
        val resolver = binding?.activity?.contentResolver
        io.execute {
            val images = shared.uris.mapNotNull { uri ->
                try {
                    resolver?.openInputStream(uri)?.use { input ->
                        val out = ByteArrayOutputStream()
                        val buffer = ByteArray(64 * 1024)
                        var total = 0
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            total += n
                            if (total > MAX_BYTES) return@use null
                            out.write(buffer, 0, n)
                        }
                        out.toByteArray()
                    }
                } catch (e: Exception) {
                    // Gone, or not ours to read: the rest still arrives.
                    null
                }
            }
            val payload = mapOf(
                "text" to shared.text,
                "subject" to shared.subject,
                "images" to images,
            )
            main.post { done(payload) }
        }
    }

    companion object {
        const val CHANNEL = "dev.ben.nemo/share"

        /** Larger than any photo a phone takes; anything bigger is skipped. */
        const val MAX_BYTES = 25 * 1024 * 1024
    }
}
