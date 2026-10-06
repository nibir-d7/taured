use ratatui::{
    layout::{Constraint, Layout, Rect},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap},
    Frame,
};
use unicode_width::UnicodeWidthStr;

use crate::app::{accent, dim, App};

const CREDIT: &str = "based on LinUtil by Chris Titus Tech";

pub fn draw(frame: &mut Frame, app: &mut App) {
    let area = frame.area();
    let rows = Layout::vertical([
        Constraint::Length(3),
        Constraint::Length(3),
        Constraint::Min(5),
        Constraint::Length(4),
        Constraint::Length(1),
    ])
    .split(area);

    draw_header(frame, app, rows[0]);
    draw_tabs(frame, app, rows[1]);
    draw_list(frame, app, rows[2]);
    draw_detail(frame, app, rows[3]);
    draw_credit(frame, rows[4]);

    if app.show_help {
        draw_help(frame, area);
    }
}

fn draw_header(frame: &mut Frame, app: &App, area: Rect) {
    let version = env!("CARGO_PKG_VERSION");
    let left = Line::from(vec![
        Span::styled("taured", accent().add_modifier(ratatui::style::Modifier::BOLD)),
        Span::raw("  "),
        Span::styled("linux toolbox", dim()),
    ]);
    let right = Line::from(Span::styled(format!("v{version}"), dim()));
    let block = Block::default().borders(Borders::ALL).border_style(accent());
    let inner = block.inner(area);
    frame.render_widget(block, area);
    frame.render_widget(Paragraph::new(left), Rect { height: 1, ..inner });
    if inner.width > right.width() as u16 {
        frame.render_widget(
            Paragraph::new(right).alignment(ratatui::layout::Alignment::Right),
            Rect { height: 1, ..inner },
        );
    }
    let _ = app;
}

fn draw_tabs(frame: &mut Frame, app: &App, area: Rect) {
    let mut spans = Vec::new();
    for (index, tab) in app.tabs.iter().enumerate() {
        if index > 0 {
            spans.push(Span::styled("  ", dim()));
        }
        let active = index == app.tab_index;
        let style = if active { accent().add_modifier(ratatui::style::Modifier::BOLD) } else { dim() };
        spans.push(Span::styled(format!(" {} ", tab.name), style));
    }
    frame.render_widget(Paragraph::new(Line::from(spans)), area);
}

fn draw_list(frame: &mut Frame, app: &mut App, area: Rect) {
    let items: Vec<ListItem> = app
        .entries
        .iter()
        .enumerate()
        .map(|(index, item)| {
            let marker = if app.selected.contains(&index) { "[x]" } else { "[ ]" };
            let indent = "  ".repeat(item.depth);
            let mut spans = vec![
                Span::styled(format!("{marker} "), if app.selected.contains(&index) { accent() } else { dim() }),
                Span::raw(format!("{indent}{}", item.node.name)),
            ];
            if !item.node.task_list.is_empty() {
                spans.push(Span::styled(format!("  [{}]", item.node.task_list), dim()));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(format!(" {} ", app.current_tab_name())))
        .highlight_symbol(">")
        .highlight_style(accent());

    let mut state = ListState::default();
    if !app.entries.is_empty() {
        state.select(Some(app.cursor));
    }
    frame.render_stateful_widget(list, area, &mut state);
}

fn draw_detail(frame: &mut Frame, app: &App, area: Rect) {
    let mut lines: Vec<Line> = Vec::new();
    if let Some(item) = app.current() {
        let description = item.node.description.replace("\\n", "\n");
        for line in description.lines() {
            lines.push(Line::from(Span::raw(line.to_string())));
        }
    }
    if !app.message.is_empty() {
        lines.push(Line::from(Span::styled(app.message.clone(), accent())));
    }
    let hint = Line::from(vec![
        Span::styled("space", dim()),
        Span::raw(" toggle  "),
        Span::styled("a", dim()),
        Span::raw(" all  "),
        Span::styled("tab", dim()),
        Span::raw(" switch tab  "),
        Span::styled("enter", dim()),
        Span::raw(" run  "),
        Span::styled("?", dim()),
        Span::raw(" help  "),
        Span::styled("q", dim()),
        Span::raw(" quit"),
    ]);
    lines.push(hint);

    let block = Block::default().borders(Borders::ALL).title(" Details ");
    frame.render_widget(
        Paragraph::new(lines)
            .block(block)
            .wrap(Wrap { trim: true }),
        area,
    );
}

fn draw_credit(frame: &mut Frame, area: Rect) {
    let line = Line::from(Span::styled(
        format!(" {CREDIT}"),
        dim().add_modifier(ratatui::style::Modifier::ITALIC),
    ));
    frame.render_widget(Paragraph::new(line), area);
}

fn draw_help(frame: &mut Frame, area: Rect) {
    let width = 60.min(area.width.saturating_sub(4));
    let height = 12.min(area.height.saturating_sub(4));
    let popup = Rect {
        x: area.x + (area.width.saturating_sub(width)) / 2,
        y: area.y + (area.height.saturating_sub(height)) / 2,
        width,
        height,
    };

    let rows: Vec<(&str, &str)> = vec![
        ("up / k", "move up"),
        ("down / j", "move down"),
        ("space", "toggle item"),
        ("a", "toggle all"),
        ("c", "clear selection"),
        ("tab / shift+tab", "switch category"),
        ("enter", "run selected"),
        ("?", "close this help"),
        ("q", "quit"),
    ];

    let lines: Vec<Line> = rows
        .iter()
        .map(|(key, description)| {
            Line::from(vec![
                Span::styled(format!("{key:<16}"), accent()),
                Span::raw(*description),
            ])
        })
        .collect();

    frame.render_widget(Clear, popup);
    frame.render_widget(
        Paragraph::new(lines).block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(accent())
                .title(" Keys "),
        ),
        popup,
    );
}

impl App {
    pub fn current_tab_name(&self) -> String {
        self.tabs
            .get(self.tab_index)
            .map(|tab| tab.name.clone())
            .unwrap_or_default()
    }

    pub fn help_width() -> usize {
        "space".width()
    }
}