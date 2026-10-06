mod app;
mod exec;
mod ui;

use std::io::{self, Stdout};

use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use taured_core::get_tabs;

use app::App;

const ABOUT: &str = "taured - distro-agnostic Linux toolbox. Free and open source. Based on LinUtil by Chris Titus Tech.";

struct Options {
    help: bool,
    version: bool,
    list: bool,
    override_validation: bool,
}

fn parse_options() -> Options {
    let mut options = Options {
        help: false,
        version: false,
        list: false,
        override_validation: false,
    };

    for argument in std::env::args().skip(1) {
        match argument.as_str() {
            "-h" | "--help" => options.help = true,
            "-V" | "--version" => options.version = true,
            "-l" | "--list" => options.list = true,
            "-u" | "--unsafe" => options.override_validation = true,
            _ => {}
        }
    }

    options
}

fn main() -> io::Result<()> {
    let options = parse_options();

    if options.help {
        println!("{ABOUT}");
        println!();
        println!("Usage: taured [options]");
        println!();
        println!("  -l, --list      print every available item and exit");
        println!("  -u, --unsafe    skip compatibility checks");
        println!("  -V, --version   print the version and exit");
        println!("  -h, --help      print this help and exit");
        return Ok(());
    }

    if options.version {
        println!("taured {}", env!("CARGO_PKG_VERSION"));
        return Ok(());
    }

    let tabs = get_tabs(!options.override_validation);

    if options.list {
        for tab in &tabs.0 {
            println!("{}", tab.name);
            for node in tab.tree.root().descendants() {
                let value = node.value();
                if matches!(value.command, taured_core::Command::None) {
                    continue;
                }
                println!("  {}", value.name);
            }
        }
        return Ok(());
    }

    if tabs.0.is_empty() {
        println!("taured: no compatible items found for this system.");
        return Ok(());
    }

    let app = App::new(tabs.0);
    run(app)
}

fn run(mut app: App) -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = event_loop(&mut terminal, &mut app);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    result
}

fn event_loop(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    app: &mut App,
) -> io::Result<()> {
    loop {
        terminal.draw(|frame| ui::draw(frame, app))?;

        if !event::poll(std::time::Duration::from_millis(120))? {
            continue;
        }

        let Event::Key(key) = event::read()? else {
            continue;
        };
        if key.kind != KeyEventKind::Press {
            continue;
        }

        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => app.should_quit = true,
            KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => app.should_quit = true,
            KeyCode::Up | KeyCode::Char('k') => app.move_cursor(-1),
            KeyCode::Down | KeyCode::Char('j') => app.move_cursor(1),
            KeyCode::Char(' ') => app.toggle(),
            KeyCode::Char('a') => app.toggle_all(),
            KeyCode::Char('c') => app.clear(),
            KeyCode::Char('?') => app.show_help = !app.show_help,
            KeyCode::Tab | KeyCode::Right => app.next_tab(),
            KeyCode::BackTab | KeyCode::Left => app.previous_tab(),
            KeyCode::Enter => {
                let scripts = app.selected_commands();
                if scripts.is_empty() {
                    app.message = "Nothing selected. Use space to pick items.".into();
                } else {
                    leave_screen(terminal)?;
                    exec::run(&scripts);
                    enter_screen(terminal)?;
                }
            }
            _ => {}
        }

        if app.should_quit {
            return Ok(());
        }
    }
}

fn leave_screen(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)
}

fn enter_screen(terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> io::Result<()> {
    enable_raw_mode()?;
    execute!(terminal.backend_mut(), EnterAlternateScreen)?;
    terminal.clear()
}