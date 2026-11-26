package com.nbdeveloper.nb_crm_flutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class AttendanceWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            super.onReceive(context, intent)
        } catch (t: Throwable) {
            Log.e("AttendanceWidget", "Error in onReceive: ${t.message}", t)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            widgetData: SharedPreferences
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.attendance_widget)

                val employeeName = widgetData.getString("employee_name", null) ?: "Employee"
                val employeeCode = widgetData.getString("employee_code", null) ?: ""
                val dateStr = widgetData.getString("date_str", null) ?: "Today"
                val punchIn = widgetData.getString("punch_in", null) ?: "—"
                val punchOut = widgetData.getString("punch_out", null) ?: "—"
                val isPunchedIn = widgetData.getBoolean("is_punched_in", false)
                val isPunchedOut = widgetData.getBoolean("is_punched_out", false)
                val cooldownRemaining = widgetData.getInt("cooldown_remaining_min", 0)

                views.setTextViewText(R.id.tv_employee_name, employeeName)
                views.setTextViewText(
                    R.id.tv_employee_code,
                    if (employeeCode.isNotEmpty()) "#$employeeCode" else ""
                )
                views.setTextViewText(R.id.tv_date, dateStr)
                views.setTextViewText(R.id.tv_punch_in, punchIn)
                views.setTextViewText(R.id.tv_punch_out, punchOut)

                // Dynamic Action Button State
                if (!isPunchedIn) {
                    views.setTextViewText(R.id.btn_action, "Punch In Now")
                    views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.widget_btn_punch_in)
                } else if (!isPunchedOut) {
                    if (cooldownRemaining > 0) {
                        views.setTextViewText(R.id.btn_action, "Punch Out (${cooldownRemaining}m)")
                        views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.widget_btn_disabled)
                    } else {
                        views.setTextViewText(R.id.btn_action, "Punch Out Now")
                        views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.widget_btn_punch_out)
                    }
                } else {
                    views.setTextViewText(R.id.btn_action, "Shift Completed ✔")
                    views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.widget_btn_completed)
                }

                // Official HomeWidgetLaunchIntent handles background launch permissions on modern Android versions
                val clickUri = Uri.parse("nbhrms://attendance?action=punch&source=widget")
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    clickUri
                )

                views.setOnClickPendingIntent(R.id.btn_action, pendingIntent)
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (t: Throwable) {
                Log.e("AttendanceWidget", "Error updating widget id $appWidgetId: ${t.message}", t)
            }
        }
    }
}
