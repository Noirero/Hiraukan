package com.meteor.kikoeruflutter

import android.content.Context
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LocalTranslationBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "com.noirero.hiraukan/local_translation"
        private const val ENGINE_ID = "mlkit_translation"
        private const val ENGINE_VERSION = "17.0.3"
        private const val DEFAULT_SOURCE = "ja"
        private const val DEFAULT_TARGET = "id"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val modelManager = RemoteModelManager.getInstance()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getModelStatus" -> getModelStatus(result)
            "downloadModels" -> {
                val wifiOnly = call.argument<Boolean>("wifiOnly") ?: true
                downloadModels(wifiOnly, result)
            }
            "deleteModels" -> deleteModels(result)
            "translate" -> translate(call, result)
            else -> result.notImplemented()
        }
    }

    private fun remoteModel(language: String) =
        TranslateRemoteModel.Builder(language).build()

    private fun getModelStatus(result: MethodChannel.Result) {
        getPairStatus(DEFAULT_SOURCE, DEFAULT_TARGET) { sourceReady, targetReady, error ->
            if (error != null) {
                result.success(
                    statusMap(
                        state = "failed",
                        sourceReady = sourceReady,
                        targetReady = targetReady,
                        message = error.message,
                    ),
                )
                return@getPairStatus
            }
            result.success(
                statusMap(
                    state = if (sourceReady && targetReady) "ready" else "notInstalled",
                    sourceReady = sourceReady,
                    targetReady = targetReady,
                ),
            )
        }
    }

    private fun downloadModels(wifiOnly: Boolean, result: MethodChannel.Result) {
        val conditionsBuilder = DownloadConditions.Builder()
        if (wifiOnly) conditionsBuilder.requireWifi()
        val conditions = conditionsBuilder.build()
        val source = remoteModel(DEFAULT_SOURCE)
        val target = remoteModel(DEFAULT_TARGET)

        modelManager.download(source, conditions)
            .addOnSuccessListener {
                modelManager.download(target, conditions)
                    .addOnSuccessListener {
                        result.success(
                            statusMap(
                                state = "ready",
                                sourceReady = true,
                                targetReady = true,
                            ),
                        )
                    }
                    .addOnFailureListener { error ->
                        getPairStatus(DEFAULT_SOURCE, DEFAULT_TARGET) { sourceReady, targetReady, _ ->
                            result.error(
                                "MODEL_DOWNLOAD_FAILED",
                                error.message ?: "Failed to download Indonesian model",
                                statusMap(
                                    state = "failed",
                                    sourceReady = sourceReady,
                                    targetReady = targetReady,
                                    message = error.message,
                                ),
                            )
                        }
                    }
            }
            .addOnFailureListener { error ->
                getPairStatus(DEFAULT_SOURCE, DEFAULT_TARGET) { sourceReady, targetReady, _ ->
                    result.error(
                        "MODEL_DOWNLOAD_FAILED",
                        error.message ?: "Failed to download Japanese model",
                        statusMap(
                            state = "failed",
                            sourceReady = sourceReady,
                            targetReady = targetReady,
                            message = error.message,
                        ),
                    )
                }
            }
    }

    private fun deleteModels(result: MethodChannel.Result) {
        val source = remoteModel(DEFAULT_SOURCE)
        val target = remoteModel(DEFAULT_TARGET)

        modelManager.deleteDownloadedModel(source)
            .addOnCompleteListener {
                modelManager.deleteDownloadedModel(target)
                    .addOnCompleteListener { targetTask ->
                        if (targetTask.isSuccessful) {
                            result.success(
                                statusMap(
                                    state = "notInstalled",
                                    sourceReady = false,
                                    targetReady = false,
                                ),
                            )
                        } else {
                            getPairStatus(DEFAULT_SOURCE, DEFAULT_TARGET) { sourceReady, targetReady, _ ->
                                result.error(
                                    "MODEL_DELETE_FAILED",
                                    targetTask.exception?.message ?: "Failed to delete local translation models",
                                    statusMap(
                                        state = "failed",
                                        sourceReady = sourceReady,
                                        targetReady = targetReady,
                                        message = targetTask.exception?.message,
                                    ),
                                )
                            }
                        }
                    }
            }
    }

    private fun translate(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text").orEmpty()
        val sourceLanguage = call.argument<String>("sourceLanguage") ?: DEFAULT_SOURCE
        val targetLanguage = call.argument<String>("targetLanguage") ?: DEFAULT_TARGET

        if (text.isBlank()) {
            result.success(text)
            return
        }
        if (TranslateLanguage.fromLanguageTag(sourceLanguage) == null ||
            TranslateLanguage.fromLanguageTag(targetLanguage) == null
        ) {
            result.error(
                "UNSUPPORTED_LANGUAGE",
                "Unsupported local translation pair: $sourceLanguage -> $targetLanguage",
                null,
            )
            return
        }

        getPairStatus(sourceLanguage, targetLanguage) { sourceReady, targetReady, error ->
            if (error != null) {
                result.error("MODEL_STATUS_FAILED", error.message, null)
                return@getPairStatus
            }
            if (!sourceReady || !targetReady) {
                result.error(
                    "MODEL_NOT_INSTALLED",
                    "Local translation models are not installed",
                    statusMap(
                        state = "notInstalled",
                        sourceReady = sourceReady,
                        targetReady = targetReady,
                    ),
                )
                return@getPairStatus
            }

            val options = TranslatorOptions.Builder()
                .setSourceLanguage(sourceLanguage)
                .setTargetLanguage(targetLanguage)
                .build()
            val translator = Translation.getClient(options)
            translator.translate(text)
                .addOnSuccessListener { translated ->
                    translator.close()
                    result.success(translated)
                }
                .addOnFailureListener { translationError ->
                    translator.close()
                    result.error(
                        "TRANSLATION_FAILED",
                        translationError.message ?: "Local translation failed",
                        null,
                    )
                }
        }
    }

    private fun getPairStatus(
        sourceLanguage: String,
        targetLanguage: String,
        callback: (Boolean, Boolean, Exception?) -> Unit,
    ) {
        val source = remoteModel(sourceLanguage)
        val target = remoteModel(targetLanguage)
        modelManager.isModelDownloaded(source)
            .addOnSuccessListener { sourceReady ->
                modelManager.isModelDownloaded(target)
                    .addOnSuccessListener { targetReady ->
                        callback(sourceReady, targetReady, null)
                    }
                    .addOnFailureListener { callback(sourceReady, false, it) }
            }
            .addOnFailureListener { callback(false, false, it) }
    }

    private fun statusMap(
        state: String,
        sourceReady: Boolean,
        targetReady: Boolean,
        message: String? = null,
    ): Map<String, Any?> = mapOf(
        "state" to state,
        "engineId" to ENGINE_ID,
        "engineVersion" to ENGINE_VERSION,
        "sourceModelInstalled" to sourceReady,
        "targetModelInstalled" to targetReady,
        "message" to message,
    )

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
