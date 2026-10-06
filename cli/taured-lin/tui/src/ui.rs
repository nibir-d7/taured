use ratatui::{
    layout::{Alignment, Constraint, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap},
    Frame,
};

use crate::app::{accent, dim, App};

const BG: Color = Color::Rgb(20, 27, 30);
const SURFACE: Color = Color::Rgb(35, 42, 45);
const BORDER: Color = Color::Rgb(55, 65, 68);
const FG: Color = Color::Rgb(218, 218, 218);
const GREEN: Color = Color::Rgb(140, 207, 126);
const TEAL: Color = Color::Rgb(108, 191, 191);
const YELLOW: Color = Color::Rgb(229, 199, 107);
const CREDIT: &str = "Inspired by Chris Titus Tech";

pub fn draw(frame: &mut Frame, app: &mut App) {
    let area = frame.area();
    frame.render_widget(Block::default().style(Style::default().bg(BG).fg(FG)), area);

    let layout = Layout::vertical([Constraint::Min(10), Constraint::Length(5)]).split(area);
    let columns =
        Layout::horizontal([Constraint::Length(27), Constraint::Min(40)]).split(layout[0]);

    draw_sidebar(frame, app, columns[0]);
    draw_browser(frame, app, columns[1]);
    draw_key_guide(frame, app, layout[1]);

    if app.show_help {
        draw_help(frame, area);
    } else if app.show_confirmation {
        draw_confirmation(frame, app, area);
    } else if app.show_description {
        draw_description(frame, app, area);
    }
}

fn draw_sidebar(frame: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::vertical([
        Constraint::Length(3),
        Constraint::Min(5),
        Constraint::Length(4),
    ])
    .split(area);

    let version = env!("CARGO_PKG_VERSION");
    let brand = Block::default()
        .borders(Borders::BOTTOM)
        .border_style(Style::default().fg(BORDER));
    let brand_text = Paragraph::new(vec![
        Line::from(Span::styled(
            "taured",
            accent().add_modifier(Modifier::BOLD),
        )),
        Line::from(Span::styled(format!("linux toolbox  v{version}"), dim())),
    ])
    .block(brand)
    .style(Style::default().bg(BG));
    frame.render_widget(brand_text, chunks[0]);

    let categories: Vec<ListItem> = app
        .tabs
        .iter()
        .map(|tab| ListItem::new(Line::from(tab.name.as_str())))
        .collect();
    let category_list = List::new(categories)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(BORDER))
                .title(Span::styled(
                    " MODULES ",
                    accent().add_modifier(Modifier::BOLD),
                ))
                .style(Style::default().bg(SURFACE)),
        )
        .highlight_symbol("> ")
        .highlight_style(
            Style::default()
                .fg(BG)
                .bg(GREEN)
                .add_modifier(Modifier::BOLD),
        );
    let mut state = ListState::default().with_selected(Some(app.tab_index));
    frame.render_stateful_widget(category_list, chunks[1], &mut state);

    let system = Paragraph::new(vec![
        Line::from(Span::styled("SYSTEM", dim().add_modifier(Modifier::BOLD))),
        Line::from(vec![
            Span::styled("OS  ", dim()),
            Span::styled(std::env::consts::OS, Style::default().fg(TEAL)),
        ]),
        Line::from(vec![
            Span::styled("CPU ", dim()),
            Span::styled(std::env::consts::ARCH, Style::default().fg(TEAL)),
        ]),
    ])
    .block(
        Block::default()
            .borders(Borders::TOP)
            .border_style(Style::default().fg(BORDER)),
    )
    .style(Style::default().bg(BG));
    frame.render_widget(system, chunks[2]);
}

fn draw_browser(frame: &mut Frame, app: &App, area: Rect) {
    let rows = Layout::vertical([Constraint::Length(3), Constraint::Min(5)]).split(area);
    let visible = app.visible_indices();
    let search_text = if app.searching {
        format!("/ {}_", app.search)
    } else if app.search.is_empty() {
        "/  Search commands".to_string()
    } else {
        format!("/  {}", app.search)
    };
    let search = Paragraph::new(vec![Line::from(vec![
        Span::styled("/  ", accent()),
        Span::styled(search_text, Style::default().fg(FG)),
        Span::raw("  "),
        Span::styled(
            format!(
                "{} commands",
                visible.iter().filter(|i| !app.entries[**i].is_dir).count()
            ),
            dim(),
        ),
    ])])
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(BORDER))
            .style(Style::default().bg(SURFACE)),
    );
    frame.render_widget(search, rows[0]);

    let active_category = app.current_tab_name();
    let items: Vec<ListItem> = visible
        .iter()
        .map(|index| {
            let item = &app.entries[*index];
            let checked = app
                .selected
                .contains_key(&(app.tab_index, item.path.clone()));
            let mut spans = if item.is_dir {
                vec![
                    Span::styled("[D]", Style::default().fg(TEAL)),
                    Span::raw("  "),
                    Span::styled(item.node.name.as_str(), Style::default().fg(FG)),
                ]
            } else {
                vec![
                    Span::styled(
                        if checked { "[*]" } else { "[ ]" },
                        if checked {
                            accent().add_modifier(Modifier::BOLD)
                        } else {
                            dim()
                        },
                    ),
                    Span::raw("  "),
                    Span::styled(item.node.name.as_str(), Style::default().fg(FG)),
                ]
            };
            if !item.node.task_list.is_empty() {
                spans.push(Span::raw("  "));
                spans.push(Span::styled(
                    item.node.task_list.as_str(),
                    Style::default().fg(TEAL),
                ));
            }
            ListItem::new(Line::from(spans))
        })
        .collect();

    let breadcrumb = if app.path_names.is_empty() {
        active_category
    } else {
        format!("{active_category} / {}", app.path_names.join(" / "))
    };
    let title = Line::from(vec![
        Span::styled(" TAURED ", accent().add_modifier(Modifier::BOLD)),
        Span::styled(format!("/ {breadcrumb} "), Style::default().fg(FG)),
    ]);
    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(BORDER))
                .title(title)
                .title_alignment(Alignment::Left)
                .style(Style::default().bg(SURFACE)),
        )
        .highlight_symbol("> ")
        .highlight_style(
            Style::default()
                .fg(BG)
                .bg(GREEN)
                .add_modifier(Modifier::BOLD),
        );

    let selected_position = visible.iter().position(|index| *index == app.cursor);
    let mut state = ListState::default().with_selected(selected_position);
    frame.render_stateful_widget(list, rows[1], &mut state);
}

fn draw_key_guide(frame: &mut Frame, app: &App, area: Rect) {
    let shortcuts_top = Line::from(vec![
        key("↑↓"),
        label(" move    "),
        key("←→"),
        label(" category    "),
        key("backspace"),
        label(" up    "),
        key("space"),
        label(" select    "),
        key("a"),
        label(" all    "),
        key("/"),
        label(" search    "),
    ]);
    let shortcuts_bottom = Line::from(vec![
        key("d"),
        label(" details    "),
        key("enter"),
        label(" open / run    "),
        key("y / n"),
        label(" confirm / cancel    "),
        key("?"),
        label(" help    "),
        key("q"),
        label(" quit"),
    ]);
    let mut state_line = vec![Span::styled(
        format!("{} selected", app.selected.len()),
        if app.selected.is_empty() {
            dim()
        } else {
            accent()
        },
    )];
    if !app.message.is_empty() {
        state_line.push(Span::raw("   "));
        state_line.push(Span::styled(
            app.message.as_str(),
            Style::default().fg(YELLOW),
        ));
    }
    let row = |offset: u16| Rect {
        x: area.x,
        y: area.y.saturating_add(offset),
        width: area.width,
        height: 1,
    };
    frame.render_widget(
        Paragraph::new(shortcuts_top).style(Style::default().bg(BG)),
        row(1),
    );
    frame.render_widget(
        Paragraph::new(shortcuts_bottom).style(Style::default().bg(BG)),
        row(2),
    );
    let status_columns =
        Layout::horizontal([Constraint::Min(1), Constraint::Length(CREDIT.len() as u16)])
            .split(row(area.height.saturating_sub(1)));
    frame.render_widget(
        Paragraph::new(Line::from(state_line)).style(Style::default().bg(BG)),
        status_columns[0],
    );
    frame.render_widget(
        Paragraph::new(Span::styled(CREDIT, dim()))
            .alignment(Alignment::Right)
            .style(Style::default().bg(BG)),
        status_columns[1],
    );
    frame.render_widget(
        Block::default()
            .borders(Borders::TOP)
            .border_style(Style::default().fg(BORDER)),
        area,
    );
}

fn key(text: &'static str) -> Span<'static> {
    Span::styled(
        format!(" {text} "),
        Style::default()
            .fg(BG)
            .bg(GREEN)
            .add_modifier(Modifier::BOLD),
    )
}

fn label(text: &'static str) -> Span<'static> {
    Span::styled(text, dim())
}

fn popup_rect(area: Rect, width: u16, height: u16) -> Rect {
    let width = width.min(area.width.saturating_sub(4));
    let height = height.min(area.height.saturating_sub(4));
    Rect {
        x: area.x + area.width.saturating_sub(width) / 2,
        y: area.y + area.height.saturating_sub(height) / 2,
        width,
        height,
    }
}

fn draw_help(frame: &mut Frame, area: Rect) {
    let popup = popup_rect(area, 66, 15);
    let lines = [
        ("↑ / k", "move through commands"),
        ("← →", "switch categories"),
        ("space", "toggle current command"),
        ("a", "select / clear visible commands"),
        ("/", "search commands"),
        ("backspace", "go up one folder"),
        ("d", "show command description"),
        ("enter", "open folder or review and run selection"),
        ("y / n", "confirm / cancel run"),
        ("?", "close this help"),
        ("q", "quit"),
    ];
    let text: Vec<Line> = lines
        .iter()
        .map(|(shortcut, description)| {
            Line::from(vec![
                Span::styled(
                    format!("{shortcut:<12}"),
                    accent().add_modifier(Modifier::BOLD),
                ),
                Span::styled(*description, Style::default().fg(FG)),
            ])
        })
        .collect();
    frame.render_widget(Clear, popup);
    frame.render_widget(
        Paragraph::new(text).block(popup_block(" KEYBOARD SHORTCUTS ")),
        popup,
    );
}

fn draw_description(frame: &mut Frame, app: &App, area: Rect) {
    let popup = popup_rect(area, 76, 14);
    let mut lines = vec![Line::from(Span::styled(
        app.current()
            .map(|item| item.node.name.as_str())
            .unwrap_or("Command details"),
        accent().add_modifier(Modifier::BOLD),
    ))];
    lines.push(Line::from(""));
    if let Some(item) = app.current() {
        lines.extend(
            item.node
                .description
                .replace("\\n", "\n")
                .lines()
                .map(|line| Line::from(line.to_string())),
        );
    }
    lines.push(Line::from(Span::styled("Press d or Esc to close", dim())));
    frame.render_widget(Clear, popup);
    frame.render_widget(
        Paragraph::new(lines)
            .wrap(Wrap { trim: true })
            .block(popup_block(" COMMAND DESCRIPTION ")),
        popup,
    );
}

fn draw_confirmation(frame: &mut Frame, app: &App, area: Rect) {
    let popup = popup_rect(area, 62, 9);
    let lines = vec![
        Line::from(Span::styled(
            format!("Run {} selected task(s)?", app.selected.len()),
            Style::default().fg(FG).add_modifier(Modifier::BOLD),
        )),
        Line::from(""),
        Line::from(vec![
            key("y"),
            label(" run now     "),
            key("n"),
            label(" go back"),
        ]),
    ];
    frame.render_widget(Clear, popup);
    frame.render_widget(
        Paragraph::new(lines).block(popup_block(" CONFIRM ACTIONS ")),
        popup,
    );
}

fn popup_block(title: &'static str) -> Block<'static> {
    Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(TEAL))
        .title(Span::styled(
            title,
            Style::default().fg(TEAL).add_modifier(Modifier::BOLD),
        ))
        .style(Style::default().bg(SURFACE).fg(FG))
}
