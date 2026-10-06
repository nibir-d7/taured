use std::collections::BTreeMap;

use ratatui::style::{Color, Style};
use taured_core::{ego_tree::NodeId, Command, ListNode, Tab};

use std::rc::Rc;

pub struct Item {
    pub node: Rc<ListNode>,
    pub id: NodeId,
    pub path: String,
    pub is_dir: bool,
}

pub struct App {
    pub tabs: Vec<Tab>,
    pub tab_index: usize,
    pub entries: Vec<Item>,
    pub location: Vec<NodeId>,
    pub path_names: Vec<String>,
    pub cursor: usize,
    pub selected: BTreeMap<(usize, String), String>,
    pub message: String,
    pub should_quit: bool,
    pub show_help: bool,
    pub show_description: bool,
    pub show_confirmation: bool,
    pub searching: bool,
    pub search: String,
}

impl App {
    pub fn new(tabs: Vec<Tab>) -> Self {
        let mut app = Self {
            tabs,
            tab_index: 0,
            entries: Vec::new(),
            location: Vec::new(),
            path_names: Vec::new(),
            cursor: 0,
            selected: BTreeMap::new(),
            message: String::new(),
            should_quit: false,
            show_help: false,
            show_description: false,
            show_confirmation: false,
            searching: false,
            search: String::new(),
        };
        app.load_tab();
        app
    }

    pub fn load_tab(&mut self) {
        self.entries.clear();
        self.cursor = 0;
        self.search.clear();
        self.searching = false;
        if let Some(tab) = self.tabs.get(self.tab_index) {
            if self.location.is_empty() {
                self.location.push(tab.tree.root().id());
            }
            if let Some(parent) = tab.tree.get(*self.location.last().unwrap()) {
                for child in parent.children() {
                    let value = child.value().clone();
                    let is_dir = matches!(&value.command, Command::None);
                    let path = self
                        .path_names
                        .iter()
                        .chain(std::iter::once(&value.name))
                        .cloned()
                        .collect::<Vec<_>>()
                        .join("/");
                    self.entries.push(Item {
                        node: value,
                        id: child.id(),
                        path,
                        is_dir,
                    });
                }
            }
        }
    }

    pub fn next_tab(&mut self) {
        if self.tabs.is_empty() {
            return;
        }
        self.tab_index = (self.tab_index + 1) % self.tabs.len();
        self.location.clear();
        self.path_names.clear();
        self.load_tab();
    }

    pub fn previous_tab(&mut self) {
        if self.tabs.is_empty() {
            return;
        }
        self.tab_index = (self.tab_index + self.tabs.len() - 1) % self.tabs.len();
        self.location.clear();
        self.path_names.clear();
        self.load_tab();
    }

    pub fn move_cursor(&mut self, delta: isize) {
        let visible = self.visible_indices();
        if visible.is_empty() {
            return;
        }
        let current = visible
            .iter()
            .position(|index| *index == self.cursor)
            .unwrap_or(0);
        let next = (current as isize + delta).clamp(0, visible.len() as isize - 1) as usize;
        self.cursor = visible[next];
    }

    pub fn toggle(&mut self) {
        let Some(item) = self.entries.get(self.cursor) else {
            return;
        };
        if item.is_dir {
            return;
        }
        let key = (self.tab_index, item.path.clone());
        if self.selected.contains_key(&key) {
            self.selected.remove(&key);
        } else {
            self.selected.insert(key, item.script());
        }
    }

    pub fn toggle_all(&mut self) {
        let visible = self.visible_indices();
        if visible
            .iter()
            .filter_map(|index| self.entries.get(*index))
            .filter(|item| !item.is_dir)
            .all(|item| {
                self.selected
                    .contains_key(&(self.tab_index, item.path.clone()))
            })
        {
            for index in visible {
                if let Some(item) = self.entries.get(index).filter(|item| !item.is_dir) {
                    self.selected.remove(&(self.tab_index, item.path.clone()));
                }
            }
        } else {
            for index in visible {
                if let Some(item) = self.entries.get(index).filter(|item| !item.is_dir) {
                    self.selected
                        .insert((self.tab_index, item.path.clone()), item.script());
                }
            }
        }
    }

    pub fn visible_indices(&self) -> Vec<usize> {
        let query = self.search.trim().to_lowercase();
        self.entries
            .iter()
            .enumerate()
            .filter(|(_, item)| item.node.name.to_lowercase().contains(&query))
            .map(|(index, _)| index)
            .collect()
    }

    pub fn update_search(&mut self, query: String) {
        self.search = query;
        let visible = self.visible_indices();
        if !visible.contains(&self.cursor) {
            self.cursor = visible.first().copied().unwrap_or(0);
        }
    }

    pub fn clear_search(&mut self) {
        self.search.clear();
        self.searching = false;
        if !self.entries.is_empty() {
            self.cursor = self.cursor.min(self.entries.len() - 1);
        }
    }

    pub fn open_current_directory(&mut self) -> bool {
        let Some(item) = self.entries.get(self.cursor).filter(|item| item.is_dir) else {
            return false;
        };
        self.location.push(item.id);
        self.path_names.push(item.node.name.clone());
        self.load_tab();
        true
    }

    pub fn go_up(&mut self) {
        if self.location.len() > 1 {
            self.location.pop();
            self.path_names.pop();
            self.load_tab();
        }
    }

    pub fn clear(&mut self) {
        self.selected.clear();
        self.message = "Selection cleared.".into();
    }

    pub fn current(&self) -> Option<&Item> {
        self.entries.get(self.cursor)
    }

    pub fn current_tab_name(&self) -> String {
        self.tabs
            .get(self.tab_index)
            .map(|tab| tab.name.clone())
            .unwrap_or_default()
    }

    pub fn selected_commands(&self) -> Vec<String> {
        self.selected.values().cloned().collect()
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
    Style::default().fg(Color::Rgb(140, 207, 126))
}

pub fn dim() -> Style {
    Style::default().fg(Color::Rgb(179, 185, 184))
}

impl Item {
    pub fn script(&self) -> String {
        script_for(&self.node)
    }
}
