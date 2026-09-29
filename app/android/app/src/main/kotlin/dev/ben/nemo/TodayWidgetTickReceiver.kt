package dev.ben.nemo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver

/**
 * A tap on a Today widget row's circle.
 *
 * The row goes at once; the write follows in Dart (`todayWidgetBackground` in
 * `today_widget_tick.dart`), which home_widget runs in a Flutter engine of its own and which then
 * pushes the new list. Starting that engine takes a moment, so the widget does not wait for it.
 */
class TodayWidgetTickReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val taskId = intent.data?.lastPathSegment ?: return
    TodayWidgetProvider.markPending(context, taskId)
    TodayWidgetProvider.redrawAll(context)
    // home_widget's own receiver: starts Flutter and queues the Dart callback.
    HomeWidgetBackgroundReceiver().onReceive(context, intent)
  }

  companion object {
    const val ACTION_TICK = "dev.ben.nemo.widget.TICK"
  }
}
