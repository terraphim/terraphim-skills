# GPUI Component API Reference

Complete API for gpui-component library components.

## Button

```rust
use gpui_component::button::{Button, ButtonVariants, ButtonRounded};

// Basic button
Button::new("id")
    .label("Click me")
    
// With icon
Button::new("save")
    .icon(IconName::Save)
    .label("Save")
    
// Variants
Button::new("id").primary()      // Primary style
Button::new("id").danger()       // Destructive
Button::new("id").success()      // Success
Button::new("id").warning()      // Warning
Button::new("id").ghost()        // Ghost/transparent
Button::new("id").link()         // Link style
Button::new("id").text()         // Text only, no padding

// Sizes
Button::new("id").xsmall()
Button::new("id").small()
Button::new("id").medium()       // default
Button::new("id").large()

// States
Button::new("id").disabled(true)
Button::new("id").loading(true)
Button::new("id").selected(true)

// Click handler
Button::new("id")
    .on_click(cx.listener(|this, event, window, cx| {
        // handle click
    }))

// With tooltip
Button::new("id")
    .tooltip("Save file", Some(Box::new(Save)))
```

## Input

```rust
use gpui_component::input::{Input, InputState};

// Create state entity
let state = cx.new(|cx| InputState::new(cx));

// Basic input
Input::new(&state)
    .placeholder("Enter text...")

// Password input
let state = cx.new(|cx| InputState::new(cx).masked(true));
Input::new(&state).mask_toggle()

// Multi-line
let state = cx.new(|cx| InputState::new(cx).multi_line(true));
Input::new(&state).h(px(200.0))

// With prefix/suffix
Input::new(&state)
    .prefix(Icon::new(IconName::Search))
    .suffix(Icon::new(IconName::X))

// Cleanable (show clear button)
Input::new(&state).cleanable(true)
```

### InputState API

```rust
// Create
InputState::new(cx)
InputState::new(cx).text("initial value")
InputState::new(cx).multi_line(true)
InputState::new(cx).masked(true)  // password

// Read/write text
state.read(cx).text()            // Get text as &str
state.update(cx, |s, cx| {
    s.set_text("new text", window, cx);
});
```

## Select

```rust
use gpui_component::select::Select;

Select::new("size-select")
    .items(vec![
        ListItem::new("sm").label("Small"),
        ListItem::new("md").label("Medium"),
        ListItem::new("lg").label("Large"),
    ])
    .selected_value("md")
    .placeholder("Select size...")
    .on_select(cx.listener(|this, value, window, cx| {
        this.size = value;
        cx.notify();
    }))
```

## Checkbox & Switch

```rust
use gpui_component::checkbox::Checkbox;
use gpui_component::switch::Switch;

Checkbox::new("agree")
    .label("I agree to terms")
    .checked(self.agreed)
    .on_click(cx.listener(|this, checked, window, cx| {
        this.agreed = *checked;
        cx.notify();
    }))

Switch::new("dark-mode")
    .checked(self.dark_mode)
    .label("Dark Mode")
    .on_click(cx.listener(|this, checked, window, cx| {
        this.dark_mode = *checked;
        cx.notify();
    }))
```

## Dialog

```rust
use gpui_component::dialog::Dialog;

Dialog::new("confirm-dialog")
    .title("Confirm Action")
    .content(|window, cx| {
        div().child("Are you sure?")
    })
    .footer(|window, cx| {
        h_flex()
            .gap_2()
            .child(Button::new("cancel").label("Cancel").ghost())
            .child(Button::new("confirm").label("Confirm").primary())
    })
    .open(self.dialog_open)
```

## PopupMenu

```rust
use gpui_component::menu::{PopupMenu, PopupMenuItem};

let menu = cx.new(|cx| {
    PopupMenu::build(cx, |menu, window, cx| {
        menu.menu_item(PopupMenuItem::new("New File")
                .icon(IconName::FilePlus)
                .action(Box::new(NewFile)))
            .separator()
            .menu_item(PopupMenuItem::new("Save")
                .icon(IconName::Save)
                .action(Box::new(Save)))
    })
});

// Show menu
menu.update(cx, |m, cx| m.show(window, cx));
```

## Tab

```rust
use gpui_component::tab::{Tab, TabBar};

TabBar::new("main-tabs")
    .child(Tab::new("tab1").label("Editor"))
    .child(Tab::new("tab2").label("Terminal"))
    .active_tab("tab1")
    .on_select(cx.listener(|this, tab_id, window, cx| {
        this.active_tab = tab_id.clone();
        cx.notify();
    }))
```

## VirtualList

```rust
use gpui_component::virtual_list::v_virtual_list;

v_virtual_list(
    "items-list",
    self.items.len(),
    move |idx, window, cx| {
        let item = &self.items[idx];
        div().p_2().child(item.label.clone())
    }
)
.item_height(px(32.0))
```

## Icon

```rust
use gpui_component::icon::{Icon, IconName};

Icon::new(IconName::Save)
Icon::new(IconName::FilePlus)
Icon::new(IconName::Settings)
Icon::new(IconName::Search)
Icon::new(IconName::Check)
Icon::new(IconName::X)

// Custom size/color
Icon::new(IconName::Save).size(px(24.0))
Icon::new(IconName::Check).color(cx.theme().success)
```

## Kbd (Keyboard Shortcut)

```rust
use gpui_component::kbd::Kbd;

Kbd::new("Cmd+S")
Kbd::new("Ctrl+Shift+P")
```
