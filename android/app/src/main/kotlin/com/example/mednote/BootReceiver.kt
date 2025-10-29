package com.example.mednote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // بإمكانك هنا إعادة جدولة الجرعات من DB بعد إقلاع الجهاز.
        // نتركها فارغة الآن؛ ستُعاد الجدولة عند فتح التطبيق.
    }
}
