package com.example.nero

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val DOCUMENT_EXPORT_CHANNEL = "nero/document_export"
        private const val PLATFORM_BRIDGE_CHANNEL = "nero/device_bridge"

        private const val CREATE_DOCUMENT_REQUEST_CODE = 4107
        private const val PICK_IMAGES_REQUEST_CODE = 4108
        private const val CAPTURE_IMAGE_REQUEST_CODE = 4109
    }

    private var documentExportChannel: MethodChannel? = null
    private var platformBridgeChannel: MethodChannel? = null

    private var pendingCreateDocumentResult: MethodChannel.Result? = null
    private var pendingPickImagesResult: MethodChannel.Result? = null
    private var pendingCaptureImageResult: MethodChannel.Result? = null

    private var pendingCameraFile: File? = null
    private var pendingCameraUri: Uri? = null
    private var pendingSharedPayload: Map<String, Any?>? = null
    private lateinit var nativeToolRuntime: NativeToolRuntime

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nativeToolRuntime = NativeToolRuntime(this)
        pendingSharedPayload = extractSharedPayload(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        documentExportChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOCUMENT_EXPORT_CHANNEL)
                .also { channel ->
                    channel.setMethodCallHandler { call, result ->
                        when (call.method) {
                            "createDocument" -> handleCreateDocument(call, result)
                            "writeDocument" -> handleWriteDocument(call, result)
                            else -> result.notImplemented()
                        }
                    }
                }

        platformBridgeChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_BRIDGE_CHANNEL)
                .also { channel ->
                    channel.setMethodCallHandler { call, result ->
                        when (call.method) {
                            "pickImages" -> handlePickImages(result)
                            "captureImage" -> handleCaptureImage(result)
                            "shareText" -> handleShareText(call, result)
                            "shareFiles" -> handleShareFiles(call, result)
                            "openFile" -> handleOpenFile(call, result)
                            "consumePendingSharedPayload" -> {
                                val payload = pendingSharedPayload
                                pendingSharedPayload = null
                                result.success(payload)
                            }
                            "releasePersistedUriPermission" ->
                                handleReleasePersistedUriPermission(call, result)
                            "executeToolRequest" -> handleExecuteToolRequest(call, result)
                            else -> result.notImplemented()
                        }
                    }
                }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractSharedPayload(intent) ?: return
        pendingSharedPayload = payload
        platformBridgeChannel?.invokeMethod("sharedPayloadReceived", payload)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            CREATE_DOCUMENT_REQUEST_CODE -> {
                val pendingResult = pendingCreateDocumentResult ?: return
                pendingCreateDocumentResult = null

                if (resultCode != RESULT_OK) {
                    pendingResult.success(null)
                    return
                }

                val uri = data?.data
                if (uri == null) {
                    pendingResult.success(null)
                    return
                }

                persistUriPermission(uri, data.flags)
                pendingResult.success(uri.toString())
            }

            PICK_IMAGES_REQUEST_CODE -> {
                val pendingResult = pendingPickImagesResult ?: return
                pendingPickImagesResult = null

                if (resultCode != RESULT_OK) {
                    pendingResult.success(emptyList<Map<String, Any?>>())
                    return
                }

                try {
                    val flags = data?.flags ?: 0
                    val uris = extractResultUris(data)
                    val imported =
                        uris
                            .distinctBy { it.toString() }
                            .map { uri ->
                                persistUriPermission(uri, flags)
                                importUriToWorkspaceFile(
                                    uri = uri,
                                    folderName = "photos",
                                    fallbackPrefix = "photo",
                                )
                            }
                    pendingResult.success(imported)
                } catch (error: Exception) {
                    pendingResult.error(
                        "pick_images_failed",
                        error.message,
                        null,
                    )
                }
            }

            CAPTURE_IMAGE_REQUEST_CODE -> {
                val pendingResult = pendingCaptureImageResult ?: return
                pendingCaptureImageResult = null
                val outputFile = pendingCameraFile
                val outputUri = pendingCameraUri
                pendingCameraFile = null
                pendingCameraUri = null

                if (resultCode != RESULT_OK || outputFile == null || !outputFile.exists()) {
                    outputFile?.delete()
                    pendingResult.success(null)
                    return
                }

                val item =
                    buildWorkspaceFileMap(
                        title = outputFile.name,
                        sourceUri = outputUri?.toString(),
                        localFile = outputFile,
                        mimeType = "image/jpeg",
                    )
                pendingResult.success(item)
            }
        }
    }

    private fun handleCreateDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingCreateDocumentResult != null) {
            result.error(
                "create_document_in_progress",
                "Another document creation request is already active.",
                null,
            )
            return
        }

        val suggestedName = call.argument<String>("suggestedName")?.trim()
        val mimeType = call.argument<String>("mimeType")?.trim()
        if (suggestedName.isNullOrEmpty() || mimeType.isNullOrEmpty()) {
            result.error(
                "create_document_invalid_args",
                "Missing suggestedName or mimeType.",
                null,
            )
            return
        }

        pendingCreateDocumentResult = result
        val intent =
            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, suggestedName)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
        startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE)
    }

    private fun handleWriteDocument(call: MethodCall, result: MethodChannel.Result) {
        val uriValue = call.argument<String>("uri")?.trim()
        val bytes = call.argument<ByteArray>("bytes")
        if (uriValue.isNullOrEmpty() || bytes == null) {
            result.error(
                "write_document_invalid_args",
                "Missing uri or bytes.",
                null,
            )
            return
        }

        val uri = Uri.parse(uriValue)
        try {
            contentResolver.openOutputStream(uri, "w")?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            } ?: throw FileNotFoundException("Unable to open destination for writing.")

            result.success(mapOf("sizeBytes" to bytes.size))
        } catch (error: Exception) {
            val code =
                when (error) {
                    is FileNotFoundException -> "write_document_not_found"
                    is SecurityException -> "write_document_denied"
                    is IOException -> "write_document_io"
                    else -> "write_document_failed"
                }
            result.error(code, error.message, null)
        }
    }

    private fun handlePickImages(result: MethodChannel.Result) {
        if (pendingPickImagesResult != null) {
            result.error(
                "pick_images_in_progress",
                "Another image import request is already active.",
                null,
            )
            return
        }

        pendingPickImagesResult = result
        val intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                    type = "image/*"
                    putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, 10)
                }
            } else {
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "image/*"
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                }
            }
        startActivityForResult(intent, PICK_IMAGES_REQUEST_CODE)
    }

    private fun handleCaptureImage(result: MethodChannel.Result) {
        if (pendingCaptureImageResult != null) {
            result.error(
                "capture_image_in_progress",
                "Another camera capture request is already active.",
                null,
            )
            return
        }

        val outputFile =
            createWorkspaceFile(
                folderName = "camera",
                desiredName = "camera_${System.currentTimeMillis()}.jpg",
            )
        val outputUri = fileUriFor(outputFile)
        val intent =
            Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, outputUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }

        if (intent.resolveActivity(packageManager) == null) {
            result.error(
                "capture_image_unavailable",
                "No camera app is available to capture an image.",
                null,
            )
            return
        }

        pendingCaptureImageResult = result
        pendingCameraFile = outputFile
        pendingCameraUri = outputUri
        startActivityForResult(intent, CAPTURE_IMAGE_REQUEST_CODE)
    }

    private fun handleShareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")?.trim()
        if (text.isNullOrEmpty()) {
            result.success(null)
            return
        }

        val subject = call.argument<String>("subject")?.trim()
        val intent =
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (!subject.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
            }
        startActivity(Intent.createChooser(intent, "Share with"))
        result.success(null)
    }

    private fun handleShareFiles(call: MethodCall, result: MethodChannel.Result) {
        val paths =
            (call.argument<List<String>>("paths") ?: emptyList())
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        val sourceUris =
            (call.argument<List<String>>("uris") ?: emptyList())
                .map { it.trim() }
                .filter { it.isNotEmpty() }
        val text = call.argument<String>("text")?.trim()
        val subject = call.argument<String>("subject")?.trim()
        val mimeType = call.argument<String>("mimeType")?.trim()?.ifEmpty { null }

        val streamUris = mutableListOf<Uri>()
        for (path in paths) {
            val file = File(path)
            if (file.exists()) {
                streamUris.add(fileUriFor(file))
            }
        }
        for (value in sourceUris) {
            streamUris.add(Uri.parse(value))
        }

        if (streamUris.isEmpty() && text.isNullOrEmpty()) {
            result.success(null)
            return
        }

        val shareIntent =
            when {
                streamUris.size > 1 ->
                    Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                        type = mimeType ?: "*/*"
                        putParcelableArrayListExtra(
                            Intent.EXTRA_STREAM,
                            ArrayList(streamUris),
                        )
                    }
                streamUris.size == 1 ->
                    Intent(Intent.ACTION_SEND).apply {
                        type = mimeType ?: "*/*"
                        putExtra(Intent.EXTRA_STREAM, streamUris.first())
                    }
                else ->
                    Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                    }
            }.apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (!text.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                if (!subject.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
            }

        startActivity(Intent.createChooser(shareIntent, "Share with"))
        result.success(null)
    }

    private fun handleOpenFile(call: MethodCall, result: MethodChannel.Result) {
        val sourceUri = call.argument<String>("sourceUri")?.trim()
        val localPath = call.argument<String>("localPath")?.trim()
        val mimeType = call.argument<String>("mimeType")?.trim()?.ifEmpty { null }

        val uri =
            when {
                !localPath.isNullOrEmpty() -> {
                    val file = File(localPath)
                    if (!file.exists()) {
                        result.error("open_file_missing", "The selected file no longer exists.", null)
                        return
                    }
                    fileUriFor(file)
                }
                !sourceUri.isNullOrEmpty() -> Uri.parse(sourceUri)
                else -> {
                    result.error("open_file_invalid_args", "Missing localPath or sourceUri.", null)
                    return
                }
            }

        val intent =
            Intent(Intent.ACTION_VIEW).apply {
                if (mimeType == null) {
                    data = uri
                } else {
                    setDataAndType(uri, mimeType)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

        if (intent.resolveActivity(packageManager) == null) {
            result.error(
                "open_file_unavailable",
                "No compatible app is available to open this file.",
                null,
            )
            return
        }

        startActivity(intent)
        result.success(null)
    }

    private fun handleReleasePersistedUriPermission(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val value = call.argument<String>("uri")?.trim()
        if (value.isNullOrEmpty()) {
            result.success(null)
            return
        }
        try {
            contentResolver.releasePersistableUriPermission(
                Uri.parse(value),
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
        }
        result.success(null)
    }

    private fun handleExecuteToolRequest(call: MethodCall, result: MethodChannel.Result) {
        val jobId = call.argument<String>("jobId")?.trim()
        val toolType = call.argument<String>("toolType")?.trim()
        val parameters = call.argument<Map<String, Any?>>("parameters") ?: emptyMap()

        if (jobId.isNullOrEmpty() || toolType.isNullOrEmpty()) {
            result.error("execute_tool_invalid_args", "Missing jobId or toolType.", null)
            return
        }

        val directory = nativeToolRuntime.resolveJobDirectory(jobId, parameters)
        val requestFile = File(directory, "request.json")

        try {
            val requestJson = JSONObject().apply {
                put("jobId", jobId)
                put("toolType", toolType)
                put("parameters", JSONObject(parameters.toMutableMap()))
            }
            requestFile.writeText(requestJson.toString())
            result.success(nativeToolRuntime.execute(jobId, toolType, parameters))
        } catch (e: Exception) {
            result.error("execute_tool_failed", e.message, null)
        }
    }

    private fun getExtensionForToolType(toolType: String): String = when (toolType) {
        "generate_docx" -> "docx"
        "generate_xlsx" -> "xlsx"
        "generate_report_pdf" -> "pdf"
        "package_zip" -> "zip"
        "materialize_project_tree" -> "json"
        else -> ""
    }

    private fun getMimeTypeForToolType(toolType: String): String = when (toolType) {
        "generate_docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "generate_xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        "generate_report_pdf" -> "application/pdf"
        "package_zip" -> "application/zip"
        "materialize_project_tree" -> "application/json"
        else -> "application/octet-stream"
    }

    private fun extractResultUris(data: Intent?): List<Uri> {
        if (data == null) {
            return emptyList()
        }
        val result = mutableListOf<Uri>()
        data.data?.let(result::add)
        val clipData = data.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index)?.uri?.let(result::add)
            }
        }
        return result
    }

    private fun extractSharedPayload(intent: Intent?): Map<String, Any?>? {
        if (intent == null) {
            return null
        }
        val action = intent.action ?: return null
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.ifEmpty { null }
        val uris = mutableListOf<Uri>()
        collectSharedUris(intent, uris)

        val imported =
            uris
                .distinctBy { it.toString() }
                .map { uri ->
                    importUriToWorkspaceFile(
                        uri = uri,
                        folderName = "shared",
                        fallbackPrefix = "shared_item",
                    )
                }

        if ((text == null || text.isEmpty()) && imported.isEmpty()) {
            return null
        }

        return mapOf(
            "text" to text,
            "files" to imported,
        )
    }

    @Suppress("DEPRECATION")
    private fun collectSharedUris(intent: Intent, destination: MutableList<Uri>) {
        val clipData = intent.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index)?.uri?.let(destination::add)
            }
        }

        if (intent.action == Intent.ACTION_SEND) {
            val singleUri =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            singleUri?.let(destination::add)
            return
        }

        val multipleUris =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
            }
        multipleUris?.let(destination::addAll)
    }

    private fun importUriToWorkspaceFile(
        uri: Uri,
        folderName: String,
        fallbackPrefix: String,
    ): Map<String, Any?> {
        val displayName = queryDisplayName(uri) ?: "${fallbackPrefix}_${System.currentTimeMillis()}"
        val mimeType = contentResolver.getType(uri) ?: guessMimeType(displayName)
        val extension = guessExtension(displayName, mimeType)
        val targetFile =
            createWorkspaceFile(
                folderName = folderName,
                desiredName = withExtension(displayName, extension),
            )

        contentResolver.openInputStream(uri)?.use { input ->
            targetFile.outputStream().use { output ->
                input.copyTo(output)
            }
        } ?: throw FileNotFoundException("Unable to open imported content.")

        return buildWorkspaceFileMap(
            title = displayName,
            sourceUri = uri.toString(),
            localFile = targetFile,
            mimeType = mimeType,
        )
    }

    private fun buildWorkspaceFileMap(
        title: String,
        sourceUri: String?,
        localFile: File,
        mimeType: String?,
    ): Map<String, Any?> {
        val extension = guessExtension(title, mimeType)
        return mapOf(
            "title" to withExtension(title, extension),
            "sourceUri" to sourceUri,
            "localPath" to localFile.absolutePath,
            "mimeType" to mimeType,
            "extension" to extension,
            "sizeBytes" to localFile.length(),
        )
    }

    private fun createWorkspaceFile(folderName: String, desiredName: String): File {
        val directory =
            File(filesDir, "workspace${File.separator}$folderName").apply {
                mkdirs()
            }
        val safeName = sanitizeFileName(desiredName)
        val base = safeName.substringBeforeLast('.', safeName)
        val extension = safeName.substringAfterLast('.', "")
        var candidate = File(directory, safeName)
        var counter = 1
        while (candidate.exists()) {
            val nextName =
                if (extension.isEmpty()) {
                    "${base}_$counter"
                } else {
                    "${base}_$counter.$extension"
                }
            candidate = File(directory, nextName)
            counter += 1
        }
        return candidate
    }

    private fun fileUriFor(file: File): Uri {
        return FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file,
        )
    }

    private fun persistUriPermission(uri: Uri, flags: Int) {
        if (flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION == 0) {
            return
        }
        val persistedFlags =
            flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        if (persistedFlags == 0) {
            return
        }
        try {
            contentResolver.takePersistableUriPermission(uri, persistedFlags)
        } catch (_: SecurityException) {
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index)
            }
        }
        return null
    }

    private fun guessMimeType(fileName: String): String? {
        val extension = fileName.substringAfterLast('.', "").lowercase()
        if (extension.isEmpty()) {
            return null
        }
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
    }

    private fun guessExtension(fileName: String, mimeType: String?): String? {
        val fromName = fileName.substringAfterLast('.', "").lowercase()
        if (fromName.isNotEmpty()) {
            return fromName
        }
        val fromMime =
            mimeType?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        return fromMime?.lowercase()
    }

    private fun withExtension(fileName: String, extension: String?): String {
        val normalized = sanitizeFileName(fileName)
        if (extension.isNullOrEmpty()) {
            return normalized
        }
        if (normalized.substringAfterLast('.', "").equals(extension, ignoreCase = true)) {
            return normalized
        }
        val base = normalized.substringBeforeLast('.', normalized)
        return "$base.$extension"
    }

    private fun sanitizeFileName(raw: String): String {
        val cleaned =
            raw
                .replace(Regex("[\\\\/:*?\"<>|]+"), "_")
                .replace(Regex("\\s+"), "_")
                .trim('_')
        return if (cleaned.isEmpty()) "item_${System.currentTimeMillis()}" else cleaned
    }
}
