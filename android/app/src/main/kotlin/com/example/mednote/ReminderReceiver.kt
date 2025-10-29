package com.example.mednote

import android.net.Uri
import android.os.Build
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id      = intent.getIntExtra("id", 0)
        val title   = intent.getStringExtra("title") ?: "تذكير"
        val body    = intent.getStringExtra("body") ?: ""
        val channel = intent.getStringExtra("channel") ?: ReminderAppointmentHelper.CH_REMINDERS

        // تأكد من وجود القنوات بالصوت
        ReminderAppointmentHelper.ensureChannels(context)

        val builder = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)

        // قبل Android O: لازم نحدد الصوت على مستوى الـ Builder
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            val sound: Uri = Uri.parse("android.resource://${context.packageName}/raw/mednote")
            builder.setSound(sound)
        }

        NotificationManagerCompat.from(context).notify(id, builder.build())
    }
}
