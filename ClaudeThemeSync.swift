import Foundation

class ClaudeThemeSync {
    private let configPath: String
    private let installDir: String
    private let tmuxScriptPath: String
    private var retryTimer: Timer?
    private var skipFilePath: String?

    init() {
        self.configPath = NSString(string: "~/.claude.json").expandingTildeInPath
        self.installDir = NSString(string: "~/.claude/theme-sync").expandingTildeInPath
        self.tmuxScriptPath = "\(NSString(string: "~/.claude/theme-sync").expandingTildeInPath)/tmux-theme-inject.sh"
    }

    func start() {
        // Sync immediately on start (no tmux injection on startup)
        syncTheme(injectTmux: false)

        // Listen for theme changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        print("Claude Theme Sync started. Listening for theme changes...")

        // Keep running
        RunLoop.current.run()
    }

    @objc private func handleThemeChange() {
        print("Theme change detected")
        syncTheme(injectTmux: true)
    }

    private func syncTheme(injectTmux: Bool) {
        let isDarkMode = isDarkModeEnabled()
        let theme = isDarkMode ? "dark" : "light"

        print("Setting Claude Code theme to: \(theme)")

        if updateConfig(theme: theme) {
            print("Successfully updated ~/.claude.json")
            if injectTmux {
                injectTmuxTheme(theme: theme)
            }
        } else {
            print("Failed to update ~/.claude.json")
        }
    }

    private func injectTmuxTheme(theme: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: tmuxScriptPath) else {
            return
        }

        // Cancel any previous retry cycle
        stopRetryTimer()

        // Create skip file for tracking already-injected panes
        let skipFile = NSTemporaryDirectory() + "claude-theme-inject-\(ProcessInfo.processInfo.processIdentifier)"
        try? fileManager.removeItem(atPath: skipFile)
        skipFilePath = skipFile

        // Initial injection
        runInjectionScript(theme: theme, skipFile: skipFile)

        // Poll for panes that were busy (running subprocesses) during initial injection
        var retriesLeft = 5
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            retriesLeft -= 1
            self.runInjectionScript(theme: theme, skipFile: skipFile)
            if retriesLeft <= 0 {
                self.stopRetryTimer()
                print("tmux inject: Retry polling complete")
            }
        }
    }

    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let path = skipFilePath {
            try? FileManager.default.removeItem(atPath: path)
            skipFilePath = nil
        }
    }

    private func runInjectionScript(theme: String, skipFile: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [tmuxScriptPath, theme, skipFile]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print(output, terminator: "")
            }
        } catch {
            print("Error running tmux injection script: \(error)")
        }
    }

    private func isDarkModeEnabled() -> Bool {
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    private func updateConfig(theme: String) -> Bool {
        let fileManager = FileManager.default

        // Read existing config
        guard fileManager.fileExists(atPath: configPath),
              let data = fileManager.contents(atPath: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Error: Could not read ~/.claude.json")
            return false
        }

        // Check if theme is already correct
        if let currentTheme = json["theme"] as? String, currentTheme == theme {
            print("Theme already set to \(theme), skipping update")
            return true
        }

        // Update theme
        json["theme"] = theme

        // Write back with pretty printing to preserve readability
        guard let updatedData = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            print("Error: Could not serialize JSON")
            return false
        }

        // Write atomically to prevent corruption
        do {
            try updatedData.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            return true
        } catch {
            print("Error writing config: \(error)")
            return false
        }
    }
}

// Main
let sync = ClaudeThemeSync()
sync.start()
