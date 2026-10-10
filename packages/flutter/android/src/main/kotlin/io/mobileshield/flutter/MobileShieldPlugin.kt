package io.mobileshield.flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mobileshield.MobileShield
import io.mobileshield.MobileShieldException
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

/**
 * One instance per Flutter engine. The native SDK is process-wide, so engines share it;
 * attaching an engine never initialises it, only the Dart `init` call does.
 */
class MobileShieldPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    private var context: Context? = null
    private var sink: EventChannel.EventSink? = null
    private var listener: MobileShield.Listener? = null

    @Volatile
    private var attached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "mobile_shield").also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, "mobile_shield/threats").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        detachListener()
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding.activity)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding.activity)

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onDetachedFromActivity() {}

    // Plugin callbacks run on the platform thread; the core also holds the activity until init when needed.
    private fun attach(activity: Activity) = MobileShield.attachActivity(activity)

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        detachListener()
        sink = eventSink
        val forward = MobileShield.Listener { event ->
            val payload = event.toJson().toString()
            main.post { if (attached) sink?.success(payload) }
        }
        listener = forward
        MobileShield.addListener(forward)
    }

    override fun onCancel(arguments: Any?) = detachListener()

    private fun detachListener() {
        listener?.let { MobileShield.removeListener(it) }
        listener = null
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val app = context
        if (app == null) {
            result.error("NativeUnavailable", "plugin is detached from its engine", null)
            return
        }
        val arguments = call.arguments
        worker.execute {
            val outcome = try {
                Outcome.Success(dispatch(call.method, app, arguments))
            } catch (e: MobileShieldException) {
                val details = e.configReason?.let { mapOf("reason" to it.name) }
                Outcome.Failure(e.reason.name, e.message, details)
            } catch (e: NotImplementedError) {
                Outcome.NotImplemented
            } catch (e: LinkageError) {
                Outcome.Failure("NativeUnavailable", e.message, null)
            } catch (e: Exception) {
                Outcome.Failure("NativeError", e.message, null)
            }
            main.post {
                if (!attached) return@post
                when (outcome) {
                    is Outcome.Success -> result.success(outcome.value)
                    is Outcome.Failure -> result.error(outcome.code, outcome.message, outcome.details)
                    Outcome.NotImplemented -> result.notImplemented()
                }
            }
        }
    }

    private fun dispatch(method: String, app: Context, arguments: Any?): Any? = when (method) {
        "getSdkVersion" -> MobileShield.getSdkVersion()
        "init" -> MobileShield.init(app, config(arguments)).toJson().toString()
        "updateConfig" -> MobileShield.updateConfig(config(arguments) ?: JSONObject()).toJson().toString()
        "getConfig" -> MobileShield.getConfig().toJson().toString()
        "runChecks" -> JSONArray().also { array -> MobileShield.runChecks().forEach { array.put(it.toJson()) } }.toString()
        "startMonitoring" -> { MobileShield.startMonitoring(); null }
        "stopMonitoring" -> { MobileShield.stopMonitoring(); null }
        "isBlocked" -> MobileShield.isBlocked()
        "attestEnrol" -> MobileShield.attestEnrol(text(arguments, "kind"), text(arguments, "nonce")).toString()
        "attestAssert" -> MobileShield.attestAssert(
            text(arguments, "kind"), text(arguments, "nonce"), text(arguments, "requestHash")).toString()
        else -> throw NotImplementedError()
    }

    private fun config(arguments: Any?): JSONObject? =
        (arguments as? Map<*, *>)?.let { JSONObject(it) }

    private fun text(arguments: Any?, key: String): String =
        (arguments as? Map<*, *>)?.get(key) as? String ?: ""

    private sealed interface Outcome {
        class Success(val value: Any?) : Outcome
        class Failure(val code: String, val message: String?, val details: Any?) : Outcome
        object NotImplemented : Outcome
    }

    private companion object {
        val main = Handler(Looper.getMainLooper())

        // Single thread keeps native calls ordered (init before updateConfig) across engines.
        val worker = Executors.newSingleThreadExecutor { task ->
            Thread(task, "mobile-shield-flutter").apply { isDaemon = true }
        }
    }
}
