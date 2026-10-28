package app.oria.control

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.graphics.Color
import android.view.Gravity
import android.view.ViewGroup
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : Activity() {
    private val requestCodePermissions = 101
    private val requestCodeScreenShare = 102
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        render()
    }

    private fun render() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 36, 28, 24)
            setBackgroundColor(Color.rgb(246, 248, 252))
        }
        val scroll = ScrollView(this)
        val content = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val isParent = BuildConfig.APP_ROLE == "parent"
        val title = TextView(this).apply {
            text = if (isParent) "oria xx" else "oria"
            textSize = 28f
            setTextColor(Color.rgb(24, 39, 75))
            gravity = Gravity.CENTER_VERTICAL
        }
        val subtitle = TextView(this).apply {
            text = if (isParent) "Tableau de bord parental" else "Assistant de configuration"
            textSize = 15f
            setTextColor(Color.DKGRAY)
            setPadding(0, 8, 0, 22)
        }
        status = TextView(this).apply {
            textSize = 15f
            setTextColor(Color.rgb(30, 90, 70))
            setPadding(0, 12, 0, 18)
        }
        content.addView(title)
        content.addView(subtitle)
        content.addView(status)

        addButton(content, "🎙  Configurer le microphone") { requestMediaPermissions(audio = true, camera = false) }
        addButton(content, "📷  Configurer la caméra") { requestMediaPermissions(audio = false, camera = true) }
        addButton(content, "📱  Autoriser le partage d'écran") { requestScreenShare() }
        addButton(content, "🔎  Vérifier les autorisations") { updatePermissionStatus() }
        addButton(content, "ℹ️  Confidentialité et aide") {
            status.text = "ORIA ne démarre aucune capture automatiquement. Android affiche les demandes d'autorisation et de partage d'écran."
        }
        scroll.addView(content)
        root.addView(scroll, ViewGroup.LayoutParams(-1, -1))
        setContentView(root)
        updatePermissionStatus()
    }

    private fun addButton(parent: LinearLayout, label: String, action: () -> Unit) {
        val button = Button(this).apply {
            text = label
            textSize = 15f
            isAllCaps = false
            setOnClickListener { action() }
        }
        val params = LinearLayout.LayoutParams(-1, ViewGroup.LayoutParams.WRAP_CONTENT)
        params.setMargins(0, 6, 0, 6)
        parent.addView(button, params)
    }

    private fun requestMediaPermissions(audio: Boolean, camera: Boolean) {
        val needed = mutableListOf<String>()
        if (audio && ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED)
            needed.add(Manifest.permission.RECORD_AUDIO)
        if (camera && ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED)
            needed.add(Manifest.permission.CAMERA)
        if (needed.isEmpty()) {
            status.text = "Autorisation déjà accordée. Aucune capture n'est active."
            return
        }
        ActivityCompat.requestPermissions(this, needed.toTypedArray(), requestCodePermissions)
    }

    private fun requestScreenShare() {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        status.text = "Android va afficher une demande système. Le partage ne commence qu'après confirmation."
        startActivityForResult(manager.createScreenCaptureIntent(), requestCodeScreenShare)
    }

    private fun updatePermissionStatus() {
        val audio = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        val camera = ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
        status.text = "Microphone : ${if (audio) "autorisé" else "non autorisé"}\nCaméra : ${if (camera) "autorisée" else "non autorisée"}\nÉcran : confirmation Android requise à chaque session.\nAucune capture n'est active."
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        updatePermissionStatus()
    }

    @Deprecated("Use system consent flow; retained for compatibility with this prototype.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestCodeScreenShare) {
            status.text = if (resultCode == RESULT_OK)
                "Partage d'écran autorisé pour cette session système. Le flux distant n'est pas encore implémenté dans ce prototype."
            else "Partage d'écran annulé. Aucune capture n'est active."
        }
    }
}
