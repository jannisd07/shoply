package com.dominik.shoply

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONObject

class ShoppingListWidget : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget first enabled
    }

    override fun onDisabled(context: Context) {
        // Widget last instance disabled
    }
    
    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.shopping_list_widget)
            
            // Load data from SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("flutter.widget_shopping_list", null)
            
            if (jsonString != null) {
                try {
                    val json = JSONObject(jsonString)
                    val listName = json.optString("listName", "Shopping List")
                    val itemCount = json.optInt("itemCount", 0)
                    val checkedCount = json.optInt("checkedCount", 0)
                    val uncheckedCount = json.optInt("uncheckedCount", 0)
                    
                    views.setTextViewText(R.id.widget_title, listName)
                    views.setTextViewText(R.id.widget_count, "$checkedCount/$itemCount")
                    
                    // Build items text
                    val itemsArray = json.optJSONArray("items")
                    val itemsText = StringBuilder()
                    if (itemsArray != null) {
                        var count = 0
                        for (i in 0 until minOf(itemsArray.length(), 5)) {
                            val item = itemsArray.getJSONObject(i)
                            if (!item.optBoolean("isChecked", false)) {
                                val name = item.optString("name", "")
                                val quantity = item.optInt("quantity", 1)
                                if (count > 0) itemsText.append("\n")
                                itemsText.append("• $name")
                                if (quantity > 1) itemsText.append(" ×$quantity")
                                count++
                                if (count >= 5) break
                            }
                        }
                        if (uncheckedCount > 5) {
                            itemsText.append("\n+${uncheckedCount - 5} more...")
                        }
                    }
                    
                    views.setTextViewText(R.id.widget_items, 
                        if (itemsText.isEmpty()) "No items" else itemsText.toString())
                    
                } catch (e: Exception) {
                    views.setTextViewText(R.id.widget_title, "Shopping List")
                    views.setTextViewText(R.id.widget_items, "Tap to open")
                    views.setTextViewText(R.id.widget_count, "0/0")
                }
            } else {
                views.setTextViewText(R.id.widget_title, "Shopping List")
                views.setTextViewText(R.id.widget_items, "Tap to open")
                views.setTextViewText(R.id.widget_count, "0/0")
            }
            
            // Set click intent to open app
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("shoply://lists"))
            intent.setPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                intent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        
        fun refreshWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, ShoppingListWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                updateWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }
}
