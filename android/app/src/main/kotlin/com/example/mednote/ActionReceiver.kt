package com.example.mednote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class ActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra(MainActivity.EXTRA_ACTION) ?: return

        val args = hashMapOf<String, Any?>(
            "patientName" to intent.getStringExtra(MainActivity.EXTRA_PATIENT),
            "medicineName" to intent.getStringExtra(MainActivity.EXTRA_MED),
            "doseText" to intent.getStringExtra(MainActivity.EXTRA_DOSE_TEXT),
            "timeMillis" to intent.getLongExtra(MainActivity.EXTRA_TIME_MILLIS, 0L),
            "snoozeMinutes" to intent.getIntExtra(MainActivity.EXTRA_SNOOZE_MIN, 10),
            "reminderLeadMinutes" to 0
        )

        when (action) {
            "TAKEN" -> {
                NotificationHelper.cancelDose(context, args) // يخفي فورًا
                NotificationHelper.enqueueTaken(context, args) // نعلّمها مأخوذة لاحقًا داخل التطبيق
                try { Toast.makeText(context, "تم تسجيل أخذ الجرعة", Toast.LENGTH_SHORT).show() } catch (_: Exception) {}
            }
            "SNOOZE" -> {
                // اخفِ الإشعار الحالي ثم أعد جدولته بعد snooze
                NotificationHelper.cancelDose(context, args)
                val snooze = (args["snoozeMinutes"] as? Int) ?: 10
                val nowPlus = System.currentTimeMillis() + snooze * 60_000L
                args["timeMillis"] = nowPlus
                NotificationHelper.scheduleExactDose(context, args)
                try { Toast.makeText(context, "تم التأجيل $snooze دقيقة", Toast.LENGTH_SHORT).show() } catch (_: Exception) {}
            }
        }
    }
}
