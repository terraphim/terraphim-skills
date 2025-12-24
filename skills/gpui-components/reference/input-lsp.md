# Input with LSP Completions

The Input component supports LSP-style completions for autocomplete, slash commands, and intelligent suggestions.

## CompletionProvider Trait

```rust
use gpui_component::input::{CompletionProvider, InputState};
use lsp_types::{CompletionContext, CompletionItem, CompletionResponse};
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
            ];
            
            let items: Vec<CompletionItem> = commands
                .iter()
                .filter(|(name, _, _)| name.starts_with(query))
                .map(|(name, insert, detail)| CompletionItem {
                    label: format!("/{}", name),
                    detail: Some(detail.to_string()),
                    insert_text: Some(insert.to_string()),
                    ..Default::default()
                })
                .collect();
            
            return Task::ready(Ok(CompletionResponse::Array(items)));
        }
        
        Task::ready(Ok(CompletionResponse::Array(vec![])))
    }
    
    fn is_completion_trigger(
        &self,
        _offset: usize,
        new_text: &str,
        _cx: &mut Context<InputState>,
    ) -> bool {
        new_text == "/"
    }
}
```

## Attaching Provider to Input

```rust
use std::sync::Arc;

let input_state = cx.new(|cx| {
    let mut state = InputState::new(cx).multi_line(true);
    state.set_completion_provider(Arc::new(SlashCommandProvider), cx);
    state
});
```

## Completion Item Properties

```rust
use lsp_types::{CompletionItem, CompletionItemKind};

CompletionItem {
    label: "myFunction".to_string(),
    kind: Some(CompletionItemKind::FUNCTION),
    detail: Some("fn myFunction() -> i32".to_string()),
    insert_text: Some("myFunction()".to_string()),
    ..Default::default()
}
```
