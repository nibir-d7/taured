use std::io::Write;
use std::process::Command;

pub fn run(scripts: &[String]) {
    if scripts.is_empty() {
        return;
    }

    let mut stdout = std::io::stdout();
    let _ = writeln!(stdout);
    let _ = writeln!(stdout, "taured: running {} item(s)", scripts.len());
    let _ = writeln!(stdout);

    for script in scripts {
        let _ = writeln!(stdout, "$ {}", script);
        let _ = writeln!(stdout);

        let status = Command::new("bash").arg("-c").arg(script).status();
        match status {
            Ok(code) if code.success() => {
                let _ = writeln!(stdout, "done");
            }
            Ok(code) => {
                let _ = writeln!(stdout, "exited with {code}");
            }
            Err(error) => {
                let _ = writeln!(stdout, "failed to start: {error}");
            }
        }

        let _ = writeln!(stdout);
    }

    let _ = writeln!(stdout, "Press Enter to return to taured...");
    let _ = std::io::stdin().read_line(&mut String::new());
    let _ = std::io::stdout().flush();
}
