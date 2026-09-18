package com.meteor.kikoeruflutter

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView

/**
 * Hiraukan floating lyric view.
 * Keeps the existing drag/touch-lock behavior while adding the useful style
 * options from newer KikoFlu builds.
 */
class FloatingLyricView(
    context: Context,
    private val windowManager: WindowManager,
    private val layoutParams: WindowManager.LayoutParams,
    initialTouchEnabled: Boolean,
    private val onTouchEnabledChanged: (Boolean) -> Unit,
    private val onClose: () -> Unit
) : FrameLayout(context) {
    private val textView: TextView
    private val lockIndicator: ImageView
    private val closeIndicator: ImageView

    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    private var isDragging = false
    private var longPressTriggered = false
    private val dragThreshold = 10f
    private val longPressTimeout = ViewConfiguration.getLongPressTimeout().toLong()

    private val longPressRunnable = Runnable {
        longPressTriggered = true
        touchEnabled = !touchEnabled
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        onTouchEnabledChanged(touchEnabled)
    }

    var touchEnabled: Boolean = initialTouchEnabled
        set(value) {
            field = value
            updateLockIndicator()
        }

    private var currentBackgroundColor: Int = Color.parseColor("#F2000000")
    private var currentCornerRadius: Float = 16f
    private var transparencyMode: Int = 0
    private var configuredPaddingHorizontal: Float = 20f
    private var configuredPaddingVertical: Float = 10f

    init {
        updateBackground()
        clipChildren = false
        clipToPadding = false
        updatePadding()
        elevation = dpToPx(12f)

        textView = TextView(context).apply {
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            gravity = Gravity.CENTER
            maxLines = 6
            ellipsize = android.text.TextUtils.TruncateAt.END
            letterSpacing = 0.02f
        }
        addView(
            textView,
            LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        )

        lockIndicator = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            setColorFilter(Color.WHITE)
            alpha = 0.7f
        }
        addView(
            lockIndicator,
            LayoutParams(dpToPx(10f).toInt(), dpToPx(10f).toInt(), Gravity.END or Gravity.TOP).apply {
                topMargin = -dpToPx(8f).toInt()
                rightMargin = -dpToPx(16f).toInt()
            }
        )

        closeIndicator = ImageView(context).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.WHITE)
            alpha = 0.85f
            visibility = View.GONE
            isClickable = true
            setOnClickListener {
                performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                onClose()
            }
        }
        addView(
            closeIndicator,
            LayoutParams(dpToPx(22f).toInt(), dpToPx(22f).toInt(), Gravity.END or Gravity.CENTER_VERTICAL)
        )

        updateLockIndicator()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = layoutParams.x
                initialY = layoutParams.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isDragging = false
                longPressTriggered = false
                removeCallbacks(longPressRunnable)
                postDelayed(longPressRunnable, longPressTimeout)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - initialTouchX
                val dy = event.rawY - initialTouchY
                if (!isDragging &&
                    (kotlin.math.abs(dx) > dragThreshold || kotlin.math.abs(dy) > dragThreshold)) {
                    removeCallbacks(longPressRunnable)
                    if (touchEnabled) isDragging = true
                }
                if (isDragging && touchEnabled) {
                    layoutParams.x = initialX + dx.toInt()
                    layoutParams.y = initialY + dy.toInt()
                    try {
                        windowManager.updateViewLayout(this, layoutParams)
                    } catch (_: Exception) {}
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                removeCallbacks(longPressRunnable)
                if (!isDragging && !longPressTriggered) performClick()
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    private fun updateLockIndicator() {
        lockIndicator.visibility = if (touchEnabled) View.GONE else View.VISIBLE
    }

    fun updateText(text: String) {
        textView.text = text
    }

    private fun updateBackground() {
        val color = if (transparencyMode == 1) Color.TRANSPARENT else currentBackgroundColor
        background = GradientDrawable().apply {
            setColor(color)
            cornerRadius = dpToPx(currentCornerRadius)
        }
        elevation = if (transparencyMode == 1) 0f else dpToPx(12f)
    }

    private fun updatePadding() {
        val horizontal = if (transparencyMode == 2) configuredPaddingHorizontal + 8f else configuredPaddingHorizontal
        val vertical = if (transparencyMode == 2) configuredPaddingVertical + 4f else configuredPaddingVertical
        setPadding(
            dpToPx(horizontal).toInt(),
            dpToPx(vertical).toInt(),
            dpToPx(horizontal).toInt(),
            dpToPx(vertical).toInt()
        )
    }

    @Suppress("LongParameterList")
    fun updateStyle(
        fontSize: Float?,
        textColor: Int?,
        backgroundColor: Int?,
        cornerRadius: Float?,
        paddingHorizontal: Float?,
        paddingVertical: Float?,
        fontFamily: String? = null,
        fontWeight: Int? = null,
        shadowEnabled: Boolean? = null,
        shadowBlur: Float? = null,
        shadowColor: Int? = null,
        transparencyMode: Int? = null,
        showCloseButton: Boolean? = null
    ) {
        fontSize?.let { textView.textSize = it }
        textColor?.let { textView.setTextColor(it) }
        fontFamily?.let { family ->
            val style = if ((fontWeight ?: 3) >= 5) Typeface.BOLD else Typeface.NORMAL
            textView.typeface = Typeface.create(
                if (family.isBlank()) Typeface.DEFAULT else Typeface.create(family, style),
                style
            )
        }
        if (fontFamily == null && fontWeight != null) {
            textView.setTypeface(textView.typeface, if (fontWeight >= 5) Typeface.BOLD else Typeface.NORMAL)
        }

        val useShadow = shadowEnabled ?: false
        if (useShadow) {
            textView.setShadowLayer(
                dpToPx(shadowBlur ?: 3f),
                0f,
                dpToPx(1f),
                shadowColor ?: Color.argb(204, 0, 0, 0)
            )
        } else {
            textView.setShadowLayer(0f, 0f, 0f, Color.TRANSPARENT)
        }

        backgroundColor?.let { currentBackgroundColor = it }
        cornerRadius?.let { currentCornerRadius = it }
        paddingHorizontal?.let { configuredPaddingHorizontal = it }
        paddingVertical?.let { configuredPaddingVertical = it }
        transparencyMode?.let { this.transparencyMode = it.coerceIn(0, 2) }
        showCloseButton?.let {
            closeIndicator.visibility = if (it) View.VISIBLE else View.GONE
        }

        updateBackground()
        updatePadding()
    }

    private fun dpToPx(dp: Float): Float = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        dp,
        resources.displayMetrics
    )
}
