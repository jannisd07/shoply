package com.dominik.shoply

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL_OAUTH = "com.shoply.oauth"
    private val CHANNEL_WIDGET = "com.shoply.widget"
    private val CHANNEL_SIRI = "com.shoply.app/siri"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // OAuth channel for handling redirects
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_OAUTH)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOAuthWindow" -> {
                        val authUrl = call.argument<String>("authUrl")
                        val redirectScheme = call.argument<String>("redirectScheme")
                        if (authUrl != null) {
                            // Open OAuth URL in browser
                            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(authUrl))
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "Auth URL is required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Widget channel for home screen widgets
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_WIDGET)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget", "updateShoppingListWidget" -> {
                        // Refresh shopping list widgets
                        ShoppingListWidget.refreshWidgets(this)
                        result.success(true)
                    }
                    "updateSavedRecipesWidget" -> {
                        // Saved recipes widget refresh
                        result.success(true)
                    }
                    "clearWidget" -> {
                        // Refresh widgets to show empty state
                        ShoppingListWidget.refreshWidgets(this)
                        result.success(true)
                    }
                    "refreshAllWidgets" -> {
                        ShoppingListWidget.refreshWidgets(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Siri-equivalent channel (for Google Assistant compatibility)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SIRI)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncLists" -> {
                        // Android doesn't need Siri sync, but handle gracefully
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLink(intent)
    }
    
    private fun handleDeepLink(intent: Intent?) {
        intent?.data?.let { uri ->
            // Handle deep links for shared lists, OAuth, etc.
            val scheme = uri.scheme
            val host = uri.host
            val path = uri.path
            
            when {
                // OAuth callback
                scheme == "com.dominik.shoply" -> {
                    // OAuth redirect will be handled by Supabase Flutter SDK
                }
                // Shared list deep link
                scheme == "shoply" && host == "list" -> {
                    // List deep link will be handled by Flutter router
                }
                // HTTPS deep link
                scheme == "https" && host == "shoplyai.app" -> {
                    // HTTPS deep link will be handled by Flutter router
                }
                // Google Assistant actions - recipes
                scheme == "shoply" && host == "recipes" -> {
                    handleRecipeAction(uri)
                }
                // Google Assistant actions - lists
                scheme == "shoply" && (host == "addItem" || host == "createList" || host == "viewList" || host == "lists") -> {
                    handleListAction(uri, host)
                }
            }
        }
        
        // Handle Google Assistant voice actions
        handleVoiceAction(intent)
    }
    
    private fun handleRecipeAction(uri: android.net.Uri) {
        val path = uri.path ?: ""
        val query = uri.getQueryParameter("q")
        
        when {
            path.contains("search") && query != null -> {
                // Recipe search - save to SharedPreferences for Flutter
                getSharedPreferences("voice_assistant", MODE_PRIVATE).edit().apply {
                    putString("action", "searchRecipes")
                    putString("query", query)
                    putLong("timestamp", System.currentTimeMillis())
                    apply()
                }
            }
            path.contains("saved") -> {
                // Show saved recipes
                getSharedPreferences("voice_assistant", MODE_PRIVATE).edit().apply {
                    putString("action", "showSavedRecipes")
                    putLong("timestamp", System.currentTimeMillis())
                    apply()
                }
            }
        }
    }
    
    private fun handleListAction(uri: android.net.Uri, action: String) {
        when (action) {
            "addItem" -> {
                val itemName = uri.getQueryParameter("item")
                val listName = uri.getQueryParameter("list")
                if (itemName != null) {
                    getSharedPreferences("voice_assistant", MODE_PRIVATE).edit().apply {
                        putString("action", "addItem")
                        putString("itemName", itemName)
                        putString("listName", listName ?: "")
                        putLong("timestamp", System.currentTimeMillis())
                        apply()
                    }
                }
            }
            "createList" -> {
                val listName = uri.getQueryParameter("name")
                if (listName != null) {
                    getSharedPreferences("voice_assistant", MODE_PRIVATE).edit().apply {
                        putString("action", "createList")
                        putString("listName", listName)
                        putLong("timestamp", System.currentTimeMillis())
                        apply()
                    }
                }
            }
        }
    }
    
    private fun handleVoiceAction(intent: Intent?) {
        // Handle Google Assistant App Actions
        val action = intent?.action
        
        when (action) {
            // Standard Android intents that Assistant can trigger
            "android.intent.action.VIEW" -> {
                // Already handled by deep link
            }
            "com.google.android.gms.actions.SEARCH_ACTION" -> {
                // Voice search
                val query = intent.getStringExtra("query") ?: intent.getStringExtra(android.app.SearchManager.QUERY)
                if (query != null) {
                    getSharedPreferences("voice_assistant", MODE_PRIVATE).edit().apply {
                        putString("action", "searchRecipes")
                        putString("query", query)
                        putLong("timestamp", System.currentTimeMillis())
                        apply()
                    }
                }
            }
            "android.intent.action.CREATE_NOTE" -> {
                // Create shopping list item
                val title = intent.getStringExtra(android.content.Intent.EXTRA_TITLE)
                val text = intent.getStringExtra(android.content.Intent.EXTRA_TEXT)
                val itemName = title ?: text
                if (itemName != null) {
                    getSharedPreferences("voice_assistant", MODE_PRIVATE).edit().apply {
                        putString("action", "addItem")
                        putString("itemName", itemName)
                        putLong("timestamp", System.currentTimeMillis())
                        apply()
                    }
                }
            }
        }
    }
}
