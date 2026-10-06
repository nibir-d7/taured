use crate::theme::Theme;
use ratatui::{
    layout::Alignment,
    prelude::*,
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
};

const CREDIT: &str = "powered by LinUtil \u{b7} Chris Titus Tech";

pub struct Logo {
    lines: Vec<Line<'static>>,
}

impl Logo {
    pub fn load() -> Option<Self> {
        let lines = vec![
            Line::from(Span::styled(
                "taured",
                Style::default().fg(Color::LightRed).bold(),
            )),
            Line::from(Span::styled(
                "LINUX TOOLBOX",
                Style::default().fg(Color::White).bold(),
            )),
            Line::from(Span::styled(
                CREDIT,
                Style::default().fg(Color::DarkGray),
            )),
        ];
        Some(Self { lines })
    }

    pub fn area_height_for_width(&self, _width: u16, max_height: u16) -> u16 {
        (self.lines.len() as u16 + 2).min(max_height)
    }

    pub fn draw(&self, frame: &mut Frame, area: Rect, theme: &Theme) {
        if area.height == 0 || area.width == 0 {
            return;
        }
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.tab_color()));
        let inner = block.inner(area);
        frame.render_widget(block, area);
        if inner.height == 0 {
            return;
        }
        let mut lines = self.lines.clone();
        lines[1] = Line::from(Span::styled(
            format!("LINUX TOOLBOX v{}", env!("CARGO_PKG_VERSION")),
            Style::default().fg(Color::White).bold(),
        ));
        frame.render_widget(
            Paragraph::new(lines)
                .alignment(Alignment::Left)
                .style(Style::default()),
            inner,
        );
    }
}