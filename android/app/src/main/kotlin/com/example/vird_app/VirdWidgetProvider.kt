package com.example.vird_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.app.PendingIntent
import android.content.Intent
import android.view.View

class VirdWidgetProvider : HomeWidgetProvider() {

    /**
     * home_widget paketi Dart int'lerini bazen Int, bazen Long olarak
     * kaydedebilir. Bu yardımcı her iki durumu da güvenle okur.
     */
    private fun SharedPreferences.safeGetInt(key: String, default: Int = 0): Int {
        return try {
            val all = this.all
            when (val value = all[key]) {
                is Int -> value
                is Long -> value.toInt()
                is String -> value.toIntOrNull() ?: default
                is Double -> value.toInt()
                is Float -> value.toInt()
                else -> default
            }
        } catch (e: Exception) {
            default
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.vird_widget_layout)

            // ── Veriyi SharedPreferences'tan güvenli oku ────────────────
            val seri = widgetData.safeGetInt("seri", 0)
            val hasanat = widgetData.safeGetInt("hasanat", 0)
            val hatimName = widgetData.getString("hatim_name", "") ?: ""
            val hatimCurrent = widgetData.safeGetInt("hatim_current", 0)
            val hatimTotal = widgetData.safeGetInt("hatim_total", 604)
            val todayLogged = try {
                widgetData.getBoolean("today_logged", false)
            } catch (e: Exception) {
                false
            }

            // ── Seri & Hasanat ──────────────────────────────────────────
            views.setTextViewText(R.id.seri_text, "$seri Gün")
            views.setTextViewText(R.id.hasanat_text, "$hasanat")

            // ── Hatim bilgisi ───────────────────────────────────────────
            if (hatimName.isNotEmpty()) {
                views.setTextViewText(R.id.hatim_name_text, hatimName)
                views.setTextViewText(R.id.hatim_progress_text, "$hatimCurrent/$hatimTotal")
            } else {
                views.setTextViewText(R.id.hatim_name_text, "Aktif hatim yok")
                views.setTextViewText(R.id.hatim_progress_text, "")
            }

            // ── Progress bar ────────────────────────────────────────────
            if (hatimTotal > 0 && hatimCurrent > 0) {
                views.setProgressBar(R.id.hatim_progress_bar, hatimTotal, hatimCurrent, false)
                views.setViewVisibility(R.id.hatim_progress_bar, View.VISIBLE)
            } else {
                views.setProgressBar(R.id.hatim_progress_bar, 100, 0, false)
                views.setViewVisibility(R.id.hatim_progress_bar, View.INVISIBLE)
            }

            // ── Durum mesajı ────────────────────────────────────────────
            val statusMsg = if (todayLogged) {
                "Bugün okudum ✓ Maşallah!"
            } else {
                if (seri > 0) "Bugün okumadın · $seri günlük serini koru! 📖"
                else "Bugün okumadın · Hadi başla! 📖"
            }
            views.setTextViewText(R.id.status_text, statusMsg)

            // ── Tıklama: Uygulamayı aç ─────────────────────────────────
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
