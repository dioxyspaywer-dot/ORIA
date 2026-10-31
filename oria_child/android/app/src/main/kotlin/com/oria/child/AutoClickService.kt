package com.oria.child

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

class AutoClickService : AccessibilityService() {

    companion object {
        private const val TAG = "ORIA_Robot"
        private val ALLOW_KEYWORDS = listOf(
            "commencer", "autoriser", "accepter", "allow", "start", "ok",
            "démarrer", "enregistrer", "capturer", "partager", "capture"
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                val className = event.className?.toString() ?: ""
                val packageName = event.packageName?.toString() ?: ""

                // Détecter la popup MediaProjection système
                if (className.contains("MediaProjection") ||
                    className.contains("Screenshot") ||
                    className.contains("ScreenCapture") ||
                    className.contains("SystemUI") ||
                    packageName.contains("com.android.systemui")) {

                    Log.d(TAG, "🤖 Popup détectée: $className ($packageName)")
                    rootInActiveWindow?.let { findAndClickAllowButton(it) }
                }
            }
        }
    }

    private fun findAndClickAllowButton(node: AccessibilityNodeInfo) {
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue

            val text = child.text?.toString()?.lowercase() ?: ""
            val desc = child.contentDescription?.toString()?.lowercase() ?: ""

            if (child.isClickable && ALLOW_KEYWORDS.any { text.contains(it) || desc.contains(it) }) {
                Log.d(TAG, "✅ Clic auto sur: '$text'")
                child.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                child.recycle()
                return
            }

            findAndClickAllowButton(child)
            child.recycle()
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "⚠️ Robot interrompu")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "🤖 Robot ORIA activé")
    }
}