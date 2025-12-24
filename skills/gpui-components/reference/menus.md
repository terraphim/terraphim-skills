# Menus and Command Palette

## PopupMenu

```rust
use gpui_component::menu::{PopupMenu, PopupMenuItem};

fn build_command_palette(cx: &mut App) -> Entity<PopupMenu> {
    cx.new(|cx| {
        PopupMenu::build(cx, |menu, window, cx| {
            menu
                .menu_item(PopupMenuItem::label("File"))
                .menu_item(PopupMenuItem::new("New File")
                    .icon(IconName::FilePlus)
                    .action(Box::new(NewFile)))
                .menu_item(PopupMenuItem::new("Save")
                    .icon(IconName::Save)
                    .action(Box::new(Save)))
                .separator()
                .menu_item(PopupMenuItem::new("Quit")
                    .icon(IconName::X)
                    .on_click(|_, window, cx| cx.quit()))
        })
    })
}
```

## Menu Item Types

```rust
// Standard item
PopupMenuItem::new("Label")
    .icon(IconName::Save)
    .action(Box::new(MyAction))

// Separator
PopupMenuItem::separator()

// Label (non-interactive header)
PopupMenuItem::label("Section Header")

// Submenu
PopupMenuItem::submenu("More Options", submenu_entity)

// Custom element
PopupMenuItem::element(|window, cx| {
    h_flex().gap_2().child(Icon::new(IconName::User)).child("Custom")
})
```

## Actions and Keyboard Shortcuts

```rust
use gpui::{actions, Action, KeyBinding};

actions!(my_app, [NewFile, Save, Undo, Redo, ToggleSidebar]);

fn init(cx: &mut App) {
    cx.bind_keys([
        KeyBinding::new("cmd-n", NewFile, None),
        KeyBinding::new("cmd-s", Save, None),
        KeyBinding::new("cmd-z", Undo, None),
        KeyBinding::new("cmd-shift-p", ToggleCommandPalette, None),
    ]);
}
```

## Showing Menu

```rust
// At mouse position
menu.update(cx, |m, cx| m.show(window, cx));

// At specific position
menu.update(cx, |m, cx| {
    m.show_at(Point::new(px(100.0), px(200.0)), window, cx);
});
```

## ContextMenu (Right-click)

```rust
use gpui_component::menu::ContextMenuExt;

div()
    .context_menu(|window, cx| {
        PopupMenu::build(cx, |menu, window, cx| {
            menu.menu_item(PopupMenuItem::new("Cut"))
                .menu_item(PopupMenuItem::new("Copy"))
                .menu_item(PopupMenuItem::new("Paste"))
        })
    })
    .child("Right-click me")
```

## Keyboard Navigation

PopupMenu handles these keys automatically:
- `Up/Down` - Navigate items
- `Enter` - Select item
- `Escape` - Close menu
- `Left/Right` - Navigate submenus
