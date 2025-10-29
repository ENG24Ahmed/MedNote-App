package com.example.mednote

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

object ReminderAppointmentHelper {

    // غيرنا الـ IDs (v2) حتى ينعكس الصوت حتى لو كانت قنوات قديمة منشأة بدون صوت
    const val CH_REMINDERS = "mednote_reminders_channel_v2"
    const val CH_APPOINTMENTS = "mednote_appointments_channel_v2"

    private fun appSoundUri(ctx: Context): Uri =
        // لأن الملف اسمه mednote.mp3 ⇒ نستخدم "raw/mednote" بدون الامتداد
        Uri.parse("android.resource://${ctx.packageName}/raw/mednote")

    private fun soundAttrs(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

    /** إنشاء قناتي التذكيرات والمواعيد بنفس صوت التطبيق */
    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val sound = appSoundUri(ctx)
            val attrs = soundAttrs()

            if (nm.getNotificationChannel(CH_REMINDERS) == null) {
                val c = NotificationChannel(
                    CH_REMINDERS,
                    "تذكيرات عامة",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "إشعارات التذكيرات العامة"
                    enableLights(true)
                    lightColor = Color.CYAN
                    enableVibration(true)
                    setSound(sound, attrs)   // ← نفس النغمة
                }
                nm.createNotificationChannel(c)
            }

            if (nm.getNotificationChannel(CH_APPOINTMENTS) == null) {
                val c = NotificationChannel(
                    CH_APPOINTMENTS,
                    "مواعيد الطبيب",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "إشعارات مواعيد الطبيب"
                    enableLights(true)
                    lightColor = Color.GREEN
                    enableVibration(true)
                    setSound(sound, attrs)   // ← نفس النغمة
                }
                nm.createNotificationChannel(c)
            }
        }
    }

    // --------- جدولة تذكير عام ----------
    fun scheduleReminderExact(ctx: Context, args: Map<String, Any?>) {
        ensureChannels(ctx)

        val timeMillis = (args["timeMillis"] as? Number)?.toLong() ?: return
        val id = reminderId(
            (args["title"] as? String).orEmpty(),
            timeMillis
        )

        val pi = PendingIntent.getBroadcast(
            ctx,
            id,
            Intent(ctx, ReminderReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", (args["title"] as? String).orEmpty())
                putExtra("body", (args["notes"] as? String).orEmpty())
                putExtra("channel", CH_REMINDERS)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= 23) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMillis, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, timeMillis, pi)
        }
    }

    fun cancelReminder(ctx: Context, args: Map<String, Any?>) {
        val timeMillis = (args["timeMillis"] as? Number)?.toLong() ?: return
        val id = reminderId((args["title"] as? String).orEmpty(), timeMillis)

        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            ctx,
            id,
            Intent(ctx, ReminderReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) am.cancel(pi)

        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
    }

    private fun reminderId(title: String, timeMillis: Long): Int {
        val key = "$title|$timeMillis"
        return 1000000 + (key.hashCode() and 0x7fffffff)
    }

    // --------- جدولة مواعيد الطبيب ----------
    fun scheduleAppointmentExact(ctx: Context, args: Map<String, Any?>) {
        ensureChannels(ctx)

        val patient = (args["patientName"] as? String).orEmpty()
        val doctor  = (args["doctorName"] as? String).orEmpty()
        val title   = (args["title"] as? String).orEmpty()
        val notes   = (args["notes"] as? String).orEmpty()
        val timeMillis = (args["timeMillis"] as? Number)?.toLong() ?: return
        val preMinutes = (args["preMinutes"] as? Number)?.toInt() ?: 60
        val morningHour = (args["morningHour"] as? Number)?.toInt() ?: 8

        val base = apptBaseId(patient, doctor, title, timeMillis)

        val cal = java.util.Calendar.getInstance().apply {
            timeInMillis = timeMillis
            set(java.util.Calendar.HOUR_OF_DAY, morningHour)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        scheduleOne(
            ctx, base + 1, cal.timeInMillis,
            "موعد اليوم: $title",
            "$patient • $doctor${if (notes.isNotEmpty()) " • $notes" else ""}",
            CH_APPOINTMENTS
        )

        val beforeAt = timeMillis - preMinutes * 60_000L
        scheduleOne(
            ctx, base + 2, beforeAt,
            "موعد بعد $preMinutes دقيقة",
            "$title • $patient • $doctor",
            CH_APPOINTMENTS
        )
    }

    fun cancelAppointment(ctx: Context, args: Map<String, Any?>) {
        val patient = (args["patientName"] as? String).orEmpty()
        val doctor  = (args["doctorName"] as? String).orEmpty()
        val title   = (args["title"] as? String).orEmpty()
        val timeMillis = (args["timeMillis"] as? Number)?.toLong() ?: return
        val base = apptBaseId(patient, doctor, title, timeMillis)

        cancelOne(ctx, base + 1)
        cancelOne(ctx, base + 2)

        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).apply {
            cancel(base + 1); cancel(base + 2)
        }
    }

    private fun apptBaseId(p: String, d: String, t: String, tm: Long): Int {
        val key = "$p|$d|$t|$tm"
        return 2000000 + (key.hashCode() and 0x7fffffff)
    }

    private fun scheduleOne(
        ctx: Context,
        id: Int,
        whenMillis: Long,
        title: String,
        body: String,
        channel: String
    ) {
        val pi = PendingIntent.getBroadcast(
            ctx,
            id,
            Intent(ctx, ReminderReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("channel", channel)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= 23) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, whenMillis, pi)
        }
    }

    private fun cancelOne(ctx: Context, id: Int) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            ctx,
            id,
            Intent(ctx, ReminderReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pi != null) am.cancel(pi)
    }
}
