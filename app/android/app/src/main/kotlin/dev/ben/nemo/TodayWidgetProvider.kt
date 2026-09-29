package dev.ben.nemo

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/**
 * The Today home-screen widget.
 *
 * The app pushes a week of open dated tasks and its look (see
 * `today_widget_data.dart`); this picks today's and the overdue ones at draw
 * time, so the widget stays right across midnight without the app. It
 * redraws at the next local midnight (an inexact alarm), on a time, zone or
 * language change, and after a reboot, which also clears alarms.
 */
class TodayWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (id in appWidgetIds) {
      appWidgetManager.updateAppWidget(id, render(context, appWidgetManager, id, widgetData))
    }
    armMidnight(context)
  }

  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    appWidgetManager.updateAppWidget(
        appWidgetId,
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context)),
    )
  }

  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      ACTION_REDRAW,
      Intent.ACTION_BOOT_COMPLETED,
      Intent.ACTION_TIME_CHANGED,
      Intent.ACTION_TIMEZONE_CHANGED,
      Intent.ACTION_LOCALE_CHANGED -> redrawAll(context)
      else -> super.onReceive(context, intent)
    }
  }

  override fun onDisabled(context: Context) {
    super.onDisabled(context)
    alarms(context).cancel(redrawIntent(context, MIDNIGHT_REQUEST))
  }

  companion object {
    private const val ACTION_REDRAW = "dev.ben.nemo.widget.REDRAW"
    private const val KEY_TASKS = "today.tasks"
    private const val KEY_LOOK = "today.look"
    private const val SCHEME = "nemo-widget"

    /** Ids ticked off here whose write has not reached the list yet. */
    private const val PENDING_PREFS = "nemo_today_widget"
    private const val KEY_PENDING = "pending"
    private const val PENDING_MS = 30_000L

    private const val MIDNIGHT_REQUEST = 1
    private const val PENDING_REQUEST = 2

    private const val HEADER_DP = 60
    private const val ROW_DP = 44
    private const val MORE_DP = 36
    private const val MAX_ROWS = 12

    /** Draws every placed Today widget again from the stored data. */
    fun redrawAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))
      val data = HomeWidgetPlugin.getData(context)
      for (id in ids) manager.updateAppWidget(id, render(context, manager, id, data))
      if (ids.isNotEmpty()) armMidnight(context)
    }

    /**
     * Hides [taskId] until the app's write lands, or for [PENDING_MS] if it never does, and
     * redraws once that time is up.
     */
    fun markPending(context: Context, taskId: String) {
      val now = System.currentTimeMillis()
      val pending = JSONObject()
      for ((id, at) in pendingIds(context, now)) pending.put(id, at)
      pending.put(taskId, now)
      context
          .getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
          .edit()
          .putString(KEY_PENDING, pending.toString())
          .apply()
      alarms(context)
          .set(AlarmManager.RTC, now + PENDING_MS + 1_000, redrawIntent(context, PENDING_REQUEST))
    }

    private fun pendingIds(context: Context, now: Long): Map<String, Long> {
      val raw =
          context
              .getSharedPreferences(PENDING_PREFS, Context.MODE_PRIVATE)
              .getString(KEY_PENDING, null) ?: return emptyMap()
      return try {
        val json = JSONObject(raw)
        json
            .keys()
            .asSequence()
            .map { it to json.getLong(it) }
            .filter { (_, at) -> now - at in 0 until PENDING_MS }
            .toMap()
      } catch (_: Exception) {
        emptyMap()
      }
    }

    private class Task(val id: String, val title: String, val due: Long, val timed: Boolean)

    private fun tasks(raw: String?): List<Task> {
      if (raw == null) return emptyList()
      return try {
        val json = JSONArray(raw)
        (0 until json.length()).map {
          val t = json.getJSONObject(it)
          Task(t.getString("id"), t.getString("title"), t.getLong("due"), t.optBoolean("timed"))
        }
      } catch (_: Exception) {
        emptyList()
      }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
    ): RemoteViews {
      val now = System.currentTimeMillis()
      val today = dayStart(now, 0)
      val tomorrow = dayStart(now, 1)
      val pending = pendingIds(context, now)
      val due = tasks(data.getString(KEY_TASKS, null)).filter { it.due < tomorrow && it.id !in pending }
      val look = Look.from(context, data.getString(KEY_LOOK, null))

      val views = RemoteViews(context.packageName, R.layout.today_widget)
      look.color(views, R.id.today_background, "setColorFilter", Role.BACKGROUND)
      look.color(views, R.id.today_title, "setTextColor", Role.TEXT)
      look.color(views, R.id.today_count, "setTextColor", Role.ACCENT)
      look.color(views, R.id.today_add, "setColorFilter", Role.ACCENT)
      look.color(views, R.id.today_empty, "setTextColor", Role.SECONDARY)
      views.setTextViewText(R.id.today_count, if (due.isEmpty()) "" else due.size.toString())
      views.setOnClickPendingIntent(R.id.today_header, open(context, "today"))
      views.setOnClickPendingIntent(R.id.today_add, open(context, "add"))
      views.setOnClickPendingIntent(R.id.today_empty, open(context, "today"))
      views.setViewVisibility(R.id.today_empty, if (due.isEmpty()) View.VISIBLE else View.GONE)

      views.removeAllViews(R.id.today_rows)
      val room = heightDp(context, manager.getAppWidgetOptions(widgetId)) - HEADER_DP
      val shown =
          if (due.size * ROW_DP <= room) due.size
          else ((room - MORE_DP) / ROW_DP).coerceAtLeast(0)
      for (task in due.take(shown.coerceAtMost(MAX_ROWS))) {
        views.addView(R.id.today_rows, row(context, look, task, today, now))
      }
      val rest = due.size - shown.coerceAtMost(MAX_ROWS)
      if (rest > 0 && room >= MORE_DP) {
        val more = RemoteViews(context.packageName, R.layout.today_widget_more)
        more.setTextViewText(
            R.id.today_more,
            context.resources.getQuantityString(R.plurals.today_widget_more, rest, rest),
        )
        look.color(more, R.id.today_more, "setTextColor", Role.SECONDARY)
        more.setOnClickPendingIntent(R.id.today_more, open(context, "today"))
        views.addView(R.id.today_rows, more)
      }
      return views
    }

    private fun row(context: Context, look: Look, task: Task, today: Long, now: Long): RemoteViews {
      val row = RemoteViews(context.packageName, R.layout.today_widget_row)
      val overdue = if (task.timed) task.due < now else task.due < today
      row.setTextViewText(R.id.today_row_title, task.title)
      look.color(row, R.id.today_row_title, "setTextColor", Role.TEXT)
      look.color(
          row, R.id.today_row_circle, "setColorFilter", if (overdue) Role.OVERDUE else Role.SECONDARY)
      row.setContentDescription(
          R.id.today_row_circle, context.getString(R.string.today_widget_tick, task.title))

      val date = Date(task.due)
      val time = if (task.timed) DateFormat.getTimeFormat(context).format(date) else null
      val label =
          if (task.due < today) {
            val pattern = DateFormat.getBestDateTimePattern(Locale.getDefault(), "MMMd")
            val day = SimpleDateFormat(pattern, Locale.getDefault()).format(date)
            if (time == null) day else "$day, $time"
          } else time
      if (label != null) {
        row.setTextViewText(R.id.today_row_due, label)
        row.setViewVisibility(R.id.today_row_due, View.VISIBLE)
        look.color(
            row, R.id.today_row_due, "setTextColor", if (overdue) Role.OVERDUE else Role.SECONDARY)
      }
      row.setOnClickPendingIntent(R.id.today_row_text, open(context, "task/${Uri.encode(task.id)}"))
      row.setOnClickPendingIntent(R.id.today_row_circle, tick(context, task.id))
      return row
    }

    /** The widget's height in dp in the current orientation. */
    private fun heightDp(context: Context, options: Bundle): Int {
      val landscape =
          context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
      val height =
          options.getInt(
              if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
              else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
      return if (height > 0) height else 110
    }

    /** Opens the app on nemo-widget://[path]; the app turns that into a route. */
    private fun open(context: Context, path: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("$SCHEME://$path"))

    private fun tick(context: Context, taskId: String): PendingIntent {
      val intent =
          Intent(context, TodayWidgetTickReceiver::class.java)
              .setAction(TodayWidgetTickReceiver.ACTION_TICK)
              .setData(Uri.parse("$SCHEME://tick/${Uri.encode(taskId)}"))
      return PendingIntent.getBroadcast(
          context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun redrawIntent(context: Context, request: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            request,
            Intent(context, TodayWidgetProvider::class.java).setAction(ACTION_REDRAW),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Inexact and not waking the device: the launcher only draws when the screen is on. */
    private fun armMidnight(context: Context) {
      val at = dayStart(System.currentTimeMillis(), 1) + 1_000
      alarms(context).set(AlarmManager.RTC, at, redrawIntent(context, MIDNIGHT_REQUEST))
    }

    private fun alarms(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    /** Local midnight [days] days after the day of [now]. */
    private fun dayStart(now: Long, days: Int): Long =
        Calendar.getInstance()
            .apply {
              timeInMillis = now
              set(Calendar.HOUR_OF_DAY, 0)
              set(Calendar.MINUTE, 0)
              set(Calendar.SECOND, 0)
              set(Calendar.MILLISECOND, 0)
              add(Calendar.DAY_OF_MONTH, days)
            }
            .timeInMillis
  }

  private enum class Role(val key: String, val dynamic: Int) {
    BACKGROUND("background", R.color.today_widget_dynamic_background),
    TEXT("text", R.color.today_widget_dynamic_text),
    SECONDARY("secondary", R.color.today_widget_dynamic_secondary),
    ACCENT("accent", R.color.today_widget_dynamic_accent),
    OVERDUE("overdue", 0),
  }

  /** The app's colours, as `widgetLook` in `today_widget_data.dart` pushed them. */
  private class Look(
      private val mode: String,
      private val dynamic: Boolean,
      private val light: Map<Role, Int>,
      private val dark: Map<Role, Int>,
      private val nightNow: Boolean,
  ) {
    /**
     * Calls [method] on [id] with [role]'s colour. With the theme following the system on Android
     * 12+, the launcher picks light or dark as it draws -- from the wallpaper's palette when
     * [dynamic] -- so a switch to dark mode needs no redraw. Otherwise the colour is decided now.
     */
    fun color(views: RemoteViews, id: Int, method: String, role: Role) {
      val light = light.getValue(role)
      val dark = dark.getValue(role)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && mode == "system") {
        if (dynamic && role.dynamic != 0) {
          views.setColor(id, method, role.dynamic)
        } else {
          views.setColorInt(id, method, light, dark)
        }
      } else {
        val night = mode == "dark" || (mode == "system" && nightNow)
        views.setInt(id, method, if (night) dark else light)
      }
    }

    companion object {
      /** nemo's own look, until the app has pushed one. */
      private val defaultLight =
          mapOf(
              Role.BACKGROUND to 0xFFF5F8F8.toInt(),
              Role.TEXT to 0xFF10201F.toInt(),
              Role.SECONDARY to 0xFF4F6362.toInt(),
              Role.ACCENT to 0xFF0E7C86.toInt(),
              Role.OVERDUE to 0xFFC62828.toInt(),
          )
      private val defaultDark =
          mapOf(
              Role.BACKGROUND to 0xFF0E1616.toInt(),
              Role.TEXT to 0xFFDDE7E6.toInt(),
              Role.SECONDARY to 0xFF9FB2B0.toInt(),
              Role.ACCENT to 0xFF5BC0C9.toInt(),
              Role.OVERDUE to 0xFFFF8A80.toInt(),
          )

      fun from(context: Context, raw: String?): Look {
        val nightNow =
            (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        val json =
            try {
              raw?.let { JSONObject(it) }
            } catch (_: Exception) {
              null
            }
        return Look(
            mode = json?.optString("mode", "system") ?: "system",
            dynamic = json?.optBoolean("dynamic") ?: false,
            light = roles(json?.optJSONObject("light"), defaultLight),
            dark = roles(json?.optJSONObject("dark"), defaultDark),
            nightNow = nightNow,
        )
      }

      private fun roles(json: JSONObject?, fallback: Map<Role, Int>): Map<Role, Int> =
          Role.entries.associateWith { role ->
            if (json != null && json.has(role.key)) json.getLong(role.key).toInt()
            else fallback.getValue(role)
          }
    }
  }
}
