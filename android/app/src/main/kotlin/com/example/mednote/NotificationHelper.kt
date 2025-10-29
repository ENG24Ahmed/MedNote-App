package com.example.mednote

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.abs
import org.json.JSONObject

object NotificationHelper {

    private const val CHANNEL_ID = "mednote_dose_channel_v2" // قناة جديدة بصوت مخصّص
    private const val CHANNEL_NAME = "تذكير الجرعات"
    private const val CHANNEL_DESC = "تنبيهات مواعيد الأدوية بدقة وبصوت مخصّص"

    private const val PREFS = "mednote_prefs"
    private const val KEY_TAKEN_QUEUE = "taken_queue"

    private fun ensureChannel(ctx: Context) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // صوت من res/raw/mednote.mp3
            val soundUri = Uri.parse("android.resource://${ctx.packageName}/raw/mednote")
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC
                enableLights(true)
                lightColor = Color.CYAN
                enableVibration(true)
                setSound(soundUri, attrs) // ← نغمة مخصّصة
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(channel)
        }
    }

    fun requestNotificationsPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= 33) {
            activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    fun openExactAlarmSettings(activity: Activity) {
        try {
            if (Build.VERSION.SDK_INT >= 31) {
                val am = activity.getSystemService(AlarmManager::class.java)
                if (am != null && !am.canScheduleExactAlarms()) {
                    val i = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    activity.startActivity(i)
                }
            }
        } catch (_: Exception) {}
    }

    private fun requestCodeForDoseKey(key: String): Int = abs(key.hashCode())

    private fun doseKeyFromArgs(args: Map<*, *>): String {
        val patient = (args["patientName"] ?: "").toString()
        val med = (args["medicineName"] ?: "").toString()
        val doseText = (args["doseText"] ?: "").toString()
        val timeMillis = (args["timeMillis"] ?: 0L).toString()
        return "$patient|$med|$doseText|$timeMillis"
    }

    private fun buildContentIntent(ctx: Context): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_ACTION, "OPEN_TODAY")
        }
        return PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildActionBroadcast(
        ctx: Context,
        args: Map<*, *>,
        action: String
    ): PendingIntent {
        val i = Intent(ctx, ActionReceiver::class.java).apply {
            putExtra(MainActivity.EXTRA_ACTION, action)
            putExtra(MainActivity.EXTRA_PATIENT, (args["patientName"] ?: "").toString())
            putExtra(MainActivity.EXTRA_MED, (args["medicineName"] ?: "").toString())
            putExtra(MainActivity.EXTRA_DOSE_TEXT, (args["doseText"] ?: "").toString())
            putExtra(MainActivity.EXTRA_TIME_MILLIS, (args["timeMillis"] as? Number)?.toLong() ?: 0L)
            putExtra(MainActivity.EXTRA_SNOOZE_MIN, (args["snoozeMinutes"] as? Number)?.toInt() ?: 10)
        }
        val req = requestCodeForDoseKey(doseKeyFromArgs(args)) + when (action) {
            "TAKEN" -> 1
            "SNOOZE" -> 2
            else -> 3
        }
        return PendingIntent.getBroadcast(
            ctx, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun showDoseNotification(ctx: Context, args: Map<*, *>) {
        ensureChannel(ctx)

        val patient = (args["patientName"] ?: "").toString()
        val med = (args["medicineName"] ?: "").toString()
        val type = (args["type"] ?: "دواء").toString()
        val doseText = (args["doseText"] ?: "").toString()
        val timeMillis = (args["timeMillis"] as? Number)?.toLong() ?: 0L

        val fmt = SimpleDateFormat("h:mm a", Locale("ar"))
        val timeStr = try { fmt.format(java.util.Date(timeMillis)) } catch (_: Exception) { "" }

        val title = "دواء • $patient"
        val line1 = "$type $med"
        val line2 = "الجرعة: $doseText"
        val line3 = "وقت الجرعة: $timeStr"

        val content = NotificationCompat.InboxStyle()
            .addLine(line1)
            .addLine(line2)
            .addLine(line3)

        val tapIntent = buildContentIntent(ctx)
        val takeIntent = buildActionBroadcast(ctx, args, "TAKEN")
        val snoozeIntent = buildActionBroadcast(ctx, args, "SNOOZE")

        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("$line1 • $doseText")
            .setStyle(content)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(tapIntent)
            .addAction(0, "أخذت الدواء", takeIntent)
            .addAction(0, "ذكرني لاحقًا", snoozeIntent)

        // للأجهزة قبل أندرويد O: نضبط الصوت على مستوى الـ Builder أيضًا
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            val soundUri = Uri.parse("android.resource://${ctx.packageName}/raw/mednote")
            builder.setSound(soundUri)
        }

        val id = requestCodeForDoseKey(doseKeyFromArgs(args))
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(id, builder.build())
    }

    fun scheduleExactDose(ctx: Context, args: Map<*, *>) {
        val timeMillis = (args["timeMillis"] as? Number)?.toLong() ?: return
        val lead = (args["reminderLeadMinutes"] as? Number)?.toLong() ?: 0L
        val triggerAt = if (lead > 0) timeMillis - lead * 60_000L else timeMillis

        val key = doseKeyFromArgs(args)
        val req = requestCodeForDoseKey(key)

        val i = Intent(ctx, AlarmReceiver::class.java).apply {
            putExtra("args", HashMap(args))
        }
        val pi = PendingIntent.getBroadcast(
            ctx, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= 23) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi)
        }
    }

    fun cancelDose(ctx: Context, args: Map<*, *>) {
        val key = doseKeyFromArgs(args)
        val req = requestCodeForDoseKey(key)
        val i = Intent(ctx, AlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            ctx, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi)
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(req)
    }

    // ======= طابور "أخذت الجرعة" عبر SharedPreferences =======

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun enqueueTaken(ctx: Context, args: Map<*, *>) {
        val json = JSONObject().apply {
            put("patientName", (args["patientName"] ?: "").toString())
            put("medicineName", (args["medicineName"] ?: "").toString())
            put("doseText", (args["doseText"] ?: "").toString())
            put("timeMillis", (args["timeMillis"] as? Number)?.toLong() ?: 0L)
        }.toString()

        val set = prefs(ctx).getStringSet(KEY_TAKEN_QUEUE, mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        set.add(json)
        prefs(ctx).edit().putStringSet(KEY_TAKEN_QUEUE, set).apply()
    }

    fun getAndClearTakenQueue(ctx: Context): List<Map<String, Any?>> {
        val set = prefs(ctx).getStringSet(KEY_TAKEN_QUEUE, emptySet())?.toMutableSet() ?: mutableSetOf()
        val list = set.mapNotNull {
            try {
                val o = JSONObject(it)
                mapOf(
                    "patientName" to o.optString("patientName", ""),
                    "medicineName" to o.optString("medicineName", ""),
                    "doseText" to o.optString("doseText", ""),
                    "timeMillis" to o.optLong("timeMillis", 0L)
                )
            } catch (_: Exception) { null }
        }
        prefs(ctx).edit().remove(KEY_TAKEN_QUEUE).apply()
        return list
    }

    fun cancelAll(ctx: Context) {
        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
    }
}
