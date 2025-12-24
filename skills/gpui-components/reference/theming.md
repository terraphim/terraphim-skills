# GPUI Theming Reference

## Theme Access

Use the `ActiveTheme` trait to access theme colors:

```rust
use gpui_component::ActiveTheme;

impl Render for MyComponent {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .bg(cx.theme().background)
            .text_color(cx.theme().foreground)
    }
}
```

## Theme Colors

### Backgrounds
```rust
cx.theme().background          // Main background
cx.theme().secondary           // Secondary/sidebar background
cx.theme().muted               // Muted/disabled background
cx.theme().card                // Card/elevated background
cx.theme().popover             // Popover/dropdown background
```

### Foregrounds
```rust
cx.theme().foreground          // Primary text
cx.theme().secondary_foreground // Secondary text
cx.theme().muted_foreground    // Muted/placeholder text
cx.theme().accent_foreground   // Text on accent background
```

### Semantic Colors
```rust
cx.theme().primary             // Primary action color
cx.theme().primary_foreground  // Text on primary
cx.theme().destructive         // Destructive/danger color
cx.theme().success             // Success color
cx.theme().warning             // Warning color
```

### Border & Ring
```rust
cx.theme().border              // Default border color
cx.theme().input               // Input border color
cx.theme().ring                // Focus ring color
```

## Switching Themes

```rust
use gpui_component::theme::{Theme, ThemeMode};

// Sync with system appearance
Theme::sync_system_appearance(None, cx);

// Set specific mode
Theme::set_mode(ThemeMode::Dark, cx);
Theme::set_mode(ThemeMode::Light, cx);
```

## Theme Properties

```rust
let theme = Theme::global(cx);

theme.font_size          // Base font size (16px default)
theme.font_family        // UI font family
theme.mono_font_family   // Monospace font
theme.radius             // General border radius
theme.radius_lg          // Large border radius
theme.shadow             // Whether to use shadows
```
