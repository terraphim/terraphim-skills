//! Basic GPUI application with gpui-component
//! cargo run --example basic_app

use gpui::*;
use gpui_component::*;
use gpui_component::button::{Button, ButtonVariants};
use gpui_component::input::{Input, InputState};

struct App {
    input_state: Entity<InputState>,
    count: i32,
}

impl App {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            input_state: cx.new(|cx| InputState::new(cx)),
            count: 0,
        }
    }
}

impl Render for App {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Root::new(
            div()
                .size_full()
                .flex()
                .flex_col()
                .gap_4()
                .p_6()
                .bg(cx.theme().background)
                .child(
                    div().text_xl().font_weight(FontWeight::BOLD)
                        .child("GPUI Demo")
                )
                .child(
                    Input::new(&self.input_state)
                        .placeholder("Type something...")
                        .cleanable(true)
                )
                .child(
                    h_flex().gap_2().items_center()
                        .child(Button::new("dec").icon(IconName::Minus)
                            .on_click(cx.listener(|this, _, _, cx| {
                                this.count -= 1;
                                cx.notify();
                            })))
                        .child(div().px_4().py_2().bg(cx.theme().secondary)
                            .child(format!("{}", self.count)))
                        .child(Button::new("inc").icon(IconName::Plus)
                            .on_click(cx.listener(|this, _, _, cx| {
                                this.count += 1;
                                cx.notify();
                            })))
                )
                .child(
                    h_flex().gap_2()
                        .child(Button::new("b1").label("Primary").primary())
                        .child(Button::new("b2").label("Danger").danger())
                        .child(Button::new("b3").label("Ghost").ghost())
                ),
            window, cx,
        )
    }
}

fn main() {
    Application::new().run(|cx| {
        gpui_component::init(cx);
        cx.open_window(WindowOptions::default(), |window, cx| {
            cx.new(|cx| App::new(cx))
        }).unwrap();
    });
}
