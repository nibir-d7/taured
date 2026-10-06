use std::collections::BTreeSet;

use ratatui::style::{Color, Style};
use taured_core::{Command, ListNode, Tab};

use std::rc::Rc;

pub struct Item {
    pub node: Rc<ListNode>,
    pub depth: usize,
}

pub struct App {
    pub tabs: Vec<Tab>,
    pub tab_index: usize,
    pub entries: Vec<Item>,
    pub cursor: usize,
    pub selected: BTreeSet<usize>,
    pub message: String,
    pub should_quit: bool,
    pub show_help: bool,
}

impl App {
    pub fn new(tabs: Vec<Tab>) -> Self {
        let mut app = Self {
            tabs,
            tab_index: 0,
            entries: Vec::new(),
            cursor: 0,
            selected: BTreeSet::new(),
            message: String::new(),
            should_quit: false,
            show_help: false,
        };
        app.load_tab();
        app
    }

    pub fn load_tab(&mut self) {
        self.entries.clear();
        self.cursor = 0;
        if let Some(tab) = self.tabs.get(self.tab_index) {
            let root = tab.tree.root();
            let mut stack = vec![(root, 0usize)];
            while let Some((node, depth)) = stack.pop() {
                for child in node.children() {
                    stack.push((child, depth + 1));
                }
                let value = node.value();
                if matches!(value.command, Command::None) {
                    continue;
                }
                self.entries.push(Item {
                    node: value.clone(),
                    depth,
                });
            }
            self.entries.sort_by(|a, b| a.node.name.to_lowercase().cmp(&b.node.name.to_lowercase()));
        }
    }

    pub fn next_tab(&mut self) {
        if self.tabs.is_empty() {
            return;
        }
        self.tab_index = (self.tab_index + 1) % self.tabs.len();
        self.selected.clear();
        self.load_tab();
    }

    pub fn previous_tab(&mut self) {
        if self.tabs.is_empty() {
            return;
        }
        self.tab_index = (self.tab_index + self.tabs.len() - 1) % self.tabs.len();
        self.selected.clear();
        self.load_tab();
    }

    pub fn move_cursor(&mut self, delta: isize) {
        if self.entries.is_empty() {
            return;
        }
        let next = self.cursor as isize + delta;
        self.cursor = next.clamp(0, self.entries.len() as isize - 1) as usize;
    }

    pub fn toggle(&mut self) {
        if self.cursor >= self.entries.len() {
            return;
        }
        if self.selected.contains(&self.cursor) {
            self.selected.remove(&self.cursor);
        } else {
            self.selected.insert(self.cursor);
        }
    }

    pub fn toggle_all(&mut self) {
        if self.selected.len() == self.entries.len() {
            self.selected.clear();
        } else {
            self.selected = (0..self.entries.len()).collect();
        }
    }

    pub fn clear(&mut self) {
        self.selected.clear();
        self.message = "Selection cleared.".into();
    }

    pub fn current(&self) -> Option<&Item> {
        self.entries.get(self.cursor)
    }

    pub fn selected_commands(&self) -> Vec<String> {
        self.selected
            .iter()
            .filter_map(|index| self.entries.get(*index))
            .map(|item| item.script())
            .collect()
    }
}

pub fn script_for(node: &ListNode) -> String {
    match &node.command {
        Command::Raw(raw) => raw.clone(),
        Command::LocalFile { file, .. } => format!("bash {}", file.display()),
        Command::None => String::new(),
    }
}

pub fn accent() -> Style {
    Style::default().fg(Color::LightRed)
}

pub fn dim() -> Style {
    Style::default().fg(Color::DarkGray)
}

impl Item {
    pub fn script(&self) -> String {
        script_for(&self.node)
    }
}