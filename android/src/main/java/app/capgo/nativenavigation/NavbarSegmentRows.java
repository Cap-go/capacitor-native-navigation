package app.capgo.nativenavigation;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/** Rows of Material-style segments drawn under the navbar toolbar. */
final class NavbarSegmentRows extends LinearLayout {

    static final int ROW_HEIGHT_DP = 48;
    private static final int PILL_HEIGHT_DP = 32;
    private static final int ICON_SIZE_DP = 18;

    interface OnSelectListener {
        void onSelect(String groupId, String id, int index);
    }

    static final class Item {

        final String id;
        final String title;
        final String accessibilityLabel;
        final boolean enabled;
        final String iconKey;
        final Drawable icon;

        Item(String id, String title, String accessibilityLabel, boolean enabled, String iconKey, Drawable icon) {
            this.id = id;
            this.title = title;
            this.accessibilityLabel = accessibilityLabel;
            this.enabled = enabled;
            this.iconKey = iconKey;
            this.icon = icon;
        }

        boolean sameLayout(Item other) {
            return (
                id.equals(other.id) &&
                Objects.equals(title, other.title) &&
                Objects.equals(accessibilityLabel, other.accessibilityLabel) &&
                enabled == other.enabled &&
                Objects.equals(iconKey, other.iconKey)
            );
        }
    }

    static final class Group {

        final String id;
        final List<Item> items;
        final String selectedId;
        final boolean segmented;

        Group(String id, List<Item> items, String selectedId, String style) {
            this.id = id;
            this.items = items;
            this.selectedId = selectedId;
            this.segmented = isSegmented(style, items.size());
        }

        int selectedIndex() {
            for (int index = 0; index < items.size(); index++) {
                if (items.get(index).id.equals(selectedId)) {
                    return index;
                }
            }
            return -1;
        }

        boolean sameLayout(Group other) {
            if (!id.equals(other.id) || segmented != other.segmented || items.size() != other.items.size()) {
                return false;
            }
            for (int index = 0; index < items.size(); index++) {
                if (!items.get(index).sameLayout(other.items.get(index))) {
                    return false;
                }
            }
            return true;
        }
    }

    /** `auto` keeps the equal-width control while every item still has room. */
    static boolean isSegmented(String style, int itemCount) {
        if ("segmented".equals(style)) {
            return true;
        }
        if ("scroll".equals(style)) {
            return false;
        }
        return itemCount <= 4;
    }

    private final List<Row> rows = new ArrayList<>();
    private OnSelectListener listener;
    private int tint = Color.rgb(0, 122, 255);
    private int foreground = Color.rgb(20, 24, 32);

    NavbarSegmentRows(Context context) {
        super(context);
        setOrientation(VERTICAL);
    }

    void setOnSelectListener(OnSelectListener listener) {
        this.listener = listener;
    }

    int rowCount() {
        return rows.size();
    }

    void apply(List<Group> groups, int tint, int foreground) {
        this.tint = tint;
        this.foreground = foreground;
        boolean reusable = rows.size() == groups.size();
        for (int index = 0; reusable && index < groups.size(); index++) {
            reusable = rows.get(index).group.sameLayout(groups.get(index));
        }
        if (!reusable) {
            removeAllViews();
            rows.clear();
            for (Group group : groups) {
                Row row = new Row(group);
                rows.add(row);
                addView(row.view, new LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(ROW_HEIGHT_DP)));
            }
        }
        for (int index = 0; index < groups.size(); index++) {
            Row row = rows.get(index);
            row.group = groups.get(index);
            row.select(row.group.selectedIndex(), reusable);
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static int withAlpha(int color, int alpha) {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color));
    }

    private final class Row {

        Group group;
        final View view;
        final List<TextView> pills = new ArrayList<>();
        HorizontalScrollView scrollView;
        int selectedIndex = -1;

        Row(Group group) {
            this.group = group;
            LinearLayout strip = new LinearLayout(getContext());
            strip.setOrientation(HORIZONTAL);
            strip.setGravity(Gravity.CENTER_VERTICAL);
            strip.setPadding(dp(16), 0, dp(16), 0);
            for (int index = 0; index < group.items.size(); index++) {
                TextView pill = makePill(group.items.get(index), index);
                LayoutParams params = group.segmented
                    ? new LayoutParams(0, dp(PILL_HEIGHT_DP), 1f)
                    : new LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(PILL_HEIGHT_DP));
                if (index > 0) {
                    // Connected segments overlap by the stroke so neighbours share one border.
                    params.setMarginStart(group.segmented ? -dp(1) : dp(8));
                }
                strip.addView(pill, params);
                pills.add(pill);
            }
            if (group.segmented) {
                view = strip;
            } else {
                scrollView = new HorizontalScrollView(getContext());
                scrollView.setHorizontalScrollBarEnabled(false);
                scrollView.setOverScrollMode(OVER_SCROLL_IF_CONTENT_SCROLLS);
                scrollView.addView(
                    strip,
                    new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.MATCH_PARENT)
                );
                view = scrollView;
            }
        }

        private TextView makePill(Item item, int index) {
            TextView pill = new TextView(getContext());
            pill.setText(item.title == null ? "" : item.title);
            pill.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
            pill.setSingleLine(true);
            pill.setEllipsize(TextUtils.TruncateAt.END);
            pill.setGravity(Gravity.CENTER);
            pill.setPadding(dp(14), 0, dp(14), 0);
            pill.setCompoundDrawablePadding(dp(6));
            pill.setEnabled(item.enabled);
            pill.setAlpha(item.enabled ? 1f : 0.38f);
            pill.setClickable(true);
            pill.setFocusable(true);
            String label = item.accessibilityLabel != null ? item.accessibilityLabel : item.title;
            pill.setContentDescription(label);
            pill.setOnClickListener((v) -> {
                if (selectedIndex != index) {
                    select(index, true);
                }
                if (listener != null) {
                    listener.onSelect(group.id, item.id, index);
                }
            });
            return pill;
        }

        void select(int index, boolean animated) {
            boolean changed = selectedIndex != index;
            selectedIndex = index;
            for (int position = 0; position < pills.size(); position++) {
                style(pills.get(position), group.items.get(position), position);
            }
            if (scrollView != null && index >= 0 && (changed || !animated)) {
                TextView target = pills.get(index);
                scrollView.post(() -> {
                    int left = target.getLeft() - dp(16);
                    int right = target.getRight() + dp(16) - scrollView.getWidth();
                    int x = scrollView.getScrollX();
                    int destination = left < x ? left : (right > x ? right : x);
                    if (animated) {
                        scrollView.smoothScrollTo(Math.max(0, destination), 0);
                    } else {
                        scrollView.scrollTo(Math.max(0, destination), 0);
                    }
                });
            }
        }

        /** Material 3 look: filter chips for scroll rows, connected segmented buttons otherwise. */
        private void style(TextView pill, Item item, int position) {
            boolean selected = position == selectedIndex;
            int textColor = selected ? Color.WHITE : foreground;
            pill.setTextColor(textColor);
            pill.setTypeface(Typeface.create(Typeface.DEFAULT, selected ? Typeface.BOLD : Typeface.NORMAL));
            pill.setSelected(selected);

            GradientDrawable background = new GradientDrawable();
            float radius = dp(PILL_HEIGHT_DP) / 2f;
            if (group.segmented) {
                int last = pills.size() - 1;
                float start = position == 0 ? radius : 0f;
                float end = position == last ? radius : 0f;
                boolean rtl = getLayoutDirection() == LAYOUT_DIRECTION_RTL;
                float left = rtl ? end : start;
                float right = rtl ? start : end;
                background.setCornerRadii(new float[] { left, left, right, right, right, right, left, left });
            } else {
                background.setCornerRadius(radius);
            }
            background.setColor(selected ? tint : Color.TRANSPARENT);
            background.setStroke(dp(1), selected ? tint : withAlpha(foreground, 72));
            Drawable icon = item.icon == null ? null : item.icon.mutate();
            if (icon != null) {
                icon.setTint(textColor);
            }
            if (icon != null && (item.title == null || item.title.isEmpty())) {
                // Compound drawables hug the padding edge; an icon-only segment centers it instead.
                LayerDrawable layers = new LayerDrawable(new Drawable[] { background, icon });
                layers.setLayerGravity(1, Gravity.CENTER);
                layers.setLayerSize(1, dp(ICON_SIZE_DP), dp(ICON_SIZE_DP));
                pill.setBackground(layers);
                pill.setMinWidth(dp(48));
                pill.setCompoundDrawablesRelative(null, null, null, null);
                return;
            }
            pill.setBackground(background);
            if (icon != null) {
                icon.setBounds(0, 0, dp(ICON_SIZE_DP), dp(ICON_SIZE_DP));
            }
            pill.setCompoundDrawablesRelative(icon, null, null, null);
        }
    }
}
