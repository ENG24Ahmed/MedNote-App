package com.example.mednote

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "mednote/notifications"

        const val EXTRA_ACTION = "action"          // "OPEN_TODAY"
        const val EXTRA_PATIENT = "patientName"
        const val EXTRA_MED = "medicineName"
        const val EXTRA_DOSE_TEXT = "doseText"
        const val EXTRA_TIME_MILLIS = "timeMillis"
        const val EXTRA_SNOOZE_MIN = "snoozeMinutes"
    }

    private var methodChannel: MethodChannel? = null
    private val prefs: SharedPreferences by lazy {
        getSharedPreferences("mednote_prefs", MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // ===== جرعات الدواء (تبقى كما هي) =====
                "scheduleDose" -> {
                    val args = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    NotificationHelper.scheduleExactDose(applicationContext, args as Map<String, Any?>)
                    result.success(true)
                }
                "cancelDose" -> {
                    val args = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    NotificationHelper.cancelDose(applicationContext, args as Map<String, Any?>)
                    result.success(true)
                }
                "cancelAllDoses" -> {
                    NotificationHelper.cancelAll(applicationContext)
                    result.success(true)
                }
                "requestPermissions" -> {
                    NotificationHelper.requestNotificationsPermission(this)
                    result.success(true)
                }
                // 🔒 يفتح إعداد المنبّه الدقيق مرة واحدة فقط
                "openExactAlarmSettings" -> {
                    openExactAlarmSettingsOnce()
                    result.success(true)
                }
                "getAndClearTakenQueue" -> {
                    val list = NotificationHelper.getAndClearTakenQueue(applicationContext)
                    result.success(list.map { JSONObject(it).toMapCompat() })
                }

                // ===== تذكير عام =====
                "scheduleReminder" -> {
                    val args = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    ReminderAppointmentHelper.scheduleReminderExact(
                        applicationContext,
                        args as Map<String, Any?>
                    )
                    result.success(true)
                }
                "cancelReminder" -> {
                    val args = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    ReminderAppointmentHelper.cancelReminder(
                        applicationContext,
                        args as Map<String, Any?>
                    )
                    result.success(true)
                }

                // ===== موعد طبيب =====
                "scheduleAppointment" -> {
                    val args = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    ReminderAppointmentHelper.scheduleAppointmentExact(
                        applicationContext,
                        args as Map<String, Any?>
                    )
                    result.success(true)
                }
                "cancelAppointment" -> {
                    val args = call.arguments as Map<*, *>
                    @Suppress("UNCHECKED_CAST")
                    ReminderAppointmentHelper.cancelAppointment(
                        applicationContext,
                        args as Map<String, Any?>
                    )
                    result.success(true)
                }

                // ===== استثناء تحسين البطارية (كما هو) =====
                "openBatteryOptimizationSettings" -> {
                    try {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        val pkg = packageName
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !pm.isIgnoringBatteryOptimizations(pkg)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$pkg")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openExactAlarmSettingsOnce() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val opened = prefs.getBoolean("exact_alarm_opened_once", false)
            val alarmManager = getSystemService(ALARM_SERVICE) as android.app.AlarmManager
            val allowed = alarmManager.canScheduleExactAlarms()
            if (!opened && !allowed) {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:$packageName")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    prefs.edit().putBoolean("exact_alarm_opened_once", true).apply()
                } catch (_: Exception) { /* تجاهل */ }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return
        val payload = mapOf("action" to action)
        methodChannel?.invokeMethod("notificationAction", payload)
    }
}

private fun JSONObject.toMapCompat(): Map<String, Any?> =
    keys().asSequence().associateWith { k -> this.opt(k) }
