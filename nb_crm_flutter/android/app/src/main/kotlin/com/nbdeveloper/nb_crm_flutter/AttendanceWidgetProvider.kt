package com.nbdeveloper.nb_crm_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class AttendanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.attendance_widget)

            val employeeName = widgetData.getString("employee_name", "Employee") ?: "Employee"
            val employeeCode = widgetData.getString("employee_code", "") ?: ""
            val dateStr = widgetData.getString("date_str", "Today") ?: "Today"
            val punchIn = widgetData.getString("punch_in", "—") ?: "—"
            val punchOut = widgetData.getString("punch_out", "—") ?: "—"
            val isPunchedIn = widgetData.getBoolean("is_punched_in", false)
            val isPunchedOut = widgetData.getBoolean("is_punched_out", false)
            val cooldownRemaining = widgetData.getInt("cooldown_remaining_min", 0)

            views.setTextViewText(R.id.tv_employee_name, employeeName)
            views.setTextViewText(R.id.tv_employee_code, if (employeeCode.isNotEmpty()) "#$employeeCode" else "")
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

            // Launch Intent -> Brings user to Attendance / Quick Punch
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("nbhrms://attendance?action=punch&source=widget")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.btn_action, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
