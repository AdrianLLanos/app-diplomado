package bo.edu.uajms.dental_care

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var saveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dental_care/png_files")
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("busy", "Hay una seleccion de archivo en curso", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "pickPng" -> {
                        pending = result
                        try {
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                type = "image/png"
                                addCategory(Intent.CATEGORY_OPENABLE)
                            }, 7001)
                        } catch (error: Exception) {
                            pending = null
                            result.error("pick_failed", "No se pudo abrir el selector", null)
                        }
                    }
                    "savePng", "saveFile" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("empty", "No hay imagen para guardar", null)
                            return@setMethodCallHandler
                        }
                        saveBytes = bytes
                        pending = result
                        try {
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                type = call.argument<String>("mimeType") ?: "image/png"
                                addCategory(Intent.CATEGORY_OPENABLE)
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "radiografia.png")
                            }, 7002)
                        } catch (error: Exception) {
                            pending = null
                            saveBytes = null
                            result.error("save_failed", "No se pudo abrir el destino", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Activity result callback required by the local file channel")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7001 && requestCode != 7002) return
        val result = pending ?: return
        pending = null
        val bytesToSave = saveBytes
        saveBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        Thread {
            try {
                if (requestCode == 7001) {
                    var name = "radiografia.png"
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                        if (it.moveToFirst()) name = it.getString(0) ?: name
                    }
                    val bytes = contentResolver.openInputStream(uri)?.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        var count = input.read(buffer)
                        while (count != -1) {
                            if (output.size() + count > 50 * 1024 * 1024) {
                                throw IllegalArgumentException("La imagen supera 50 MB")
                            }
                            output.write(buffer, 0, count)
                            count = input.read(buffer)
                        }
                        output.toByteArray()
                    } ?: throw IllegalArgumentException("No se pudo leer el archivo")
                    runOnUiThread { result.success(mapOf("name" to name, "bytes" to bytes)) }
                } else {
                    val bytes = bytesToSave ?: throw IllegalArgumentException("No hay imagen")
                    contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                        ?: throw IllegalArgumentException("No se pudo guardar la imagen")
                    runOnUiThread { result.success(true) }
                }
            } catch (error: Exception) {
                runOnUiThread { result.error("file_error", error.message ?: "Error al procesar archivo", null) }
            }
        }.start()
    }
}
