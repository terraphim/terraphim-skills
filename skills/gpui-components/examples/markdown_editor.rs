//! Markdown editor with slash commands
//! cargo run --example markdown_editor

use std::sync::Arc;
use anyhow::Result;
use gpui::*;
use gpui_component::*;
use gpui_component::input::{Input, InputState, CompletionProvider};
use lsp_types::{CompletionContext, CompletionItem, CompletionItemKind, CompletionResponse};
use ropey::Rope;

struct SlashCommandProvider;

impl CompletionProvider for SlashCommandProvider {
    fn completions(
        &self,
        text: &Rope,
        offset: usize,
        _trigger: CompletionContext,
        _window: &mut Window,
        _cx: &mut Context<InputState>,
    ) -> Task<Result<CompletionResponse>> {
        let text_str = text.slice(..offset).to_string();
        
        if let Some(slash_pos) = text_str.rfind('/') {
            let query = &text_str[slash_pos + 1..];
            let commands = [
                ("heading", "# ", "Insert heading"),
                ("code", "```\n\n```", "Insert code block"),
                ("list", "- ", "Insert bullet list"),
                ("quote", "> ", "Insert blockquote"),
                ("table", "| Col1 | Col2 |\n|------|------|", "Insert table"),
            ];
            
            let items: Vec<CompletionItem> = commands
                .iter()
                .filter(|(name, _, _)| name.starts_with(query))
                .map(|(name, insert, detail)| CompletionItem {
                    label: format!("/{}", name),
                    kind: Some(CompletionItemKind::SNIPPET),
                    detail: Some(detail.to_string()),
                    insert_text: Some(insert.to_string()),
                    ..Default::default()
                })
                .collect();
            
            return Task::ready(Ok(CompletionResponse::Array(items)));
        }
        Task::ready(Ok(CompletionResponse::Array(vec![])))
    }
    
    fn is_completion_trigger(&self, _: usize, new_text: &str, _: &mut Context<InputState>) -> bool {
        new_text == "/"
    }
}

struct MarkdownEditor {
    input_state: Entity<InputState>,
}

impl MarkdownEditor {
    fn new(cx: &mut Context<Self>) -> Self {
        let input_state = cx.new(|cx| {
            let mut state = InputState::new(cx)
                .multi_line(true)
                .text("# Welcome\n\nType `/` for commands.\n");
            state.set_completion_provider(Arc::new(SlashCommandProvider), cx);
            state
        });
        Self { input_state }
    }
}

impl Render for MarkdownEditor {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Root::new(
            div()
                .size_full()
                .flex()
                .flex_col()
                .bg(cx.theme().background)
                .child(
                    h_flex().px_4().py_2().bg(cx.theme().secondary)
                        .child(Icon::new(IconName::FileText).color(cx.theme().primary))
                        .child(div().font_weight(FontWeight::SEMIBOLD).child("Markdown Editor"))
                )
                .child(
                    div().flex_1().p_4()
                        .child(Input::new(&self.input_state).h_full())
                ),
            window, cx,
        )
    }
}

fn main() {
    Application::new().run(|cx| {
        gpui_component::init(cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(Bounds::centered(
                    None, size(px(800.0), px(600.0)), cx,
                ))),
                ..Default::default()
            },
            |window, cx| cx.new(|cx| MarkdownEditor::new(cx)),
        ).unwrap();
    });
}
