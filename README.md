# bgpbar

`bgp` — a progress-reporting wrapper for long background commands (`bin/bgp`, see its docstring) —
and a macOS menu bar view of its tasks. Reads `~/.claude/progress/*.json` every second.

- Menu bar: percent of the newest running task (`~` = estimated from `-e`), `+N` for more running tasks;
  `!` after a failed/died task, a quiet gauge when idle.
- Panel: running tasks and the ones finished in the last hour — progress bar, `124/200 · 25s · ещё ~15s`,
  last output line. Click a row to open its log; hover for stop (SIGINT) / dismiss.
- Notification when a task finishes (sound on failure). "При входе" toggles launch at login.

    ./scripts/bundle.sh --install   # build, copy to ~/Applications, restart

Install the CLI: `ln -s "$PWD/bin/bgp" ~/.local/bin/bgp`.
