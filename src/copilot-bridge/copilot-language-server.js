// Entrypoint for Copilot Language Server (Node.js)
// --- Logging Setup ---
const fs = require("fs");
const path = require("path");
const LOG_PATH = path.join(__dirname, "copilot-lsp-server.log");
function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}\n`;
  try {
    fs.appendFileSync(LOG_PATH, line, { encoding: "utf8" });
  } catch (e) {
    /* ignore */
  }
}
log("Node.js Copilot LSP server starting");
process.on("exit", (code) => {
  log("Node.js Copilot LSP server exiting, code=" + code);
});
process.on("uncaughtException", (err) => {
  log("Uncaught exception: " + err.stack);
});
process.stdin.on("data", (chunk) => {
  log("Received from stdin: " + chunk.toString("utf8").trim());
});
// This file should be shipped with the extension DLL and started by the RAD Studio extension

function ensureCopilotLanguageServer() {
  try {
    // Try to require the correct package
    const CopilotLanguageServer = require("@github/copilot-language-server");
    return CopilotLanguageServer;
  } catch (err) {
    log(
      'Error in require("@github/copilot-language-server"): ' +
        (err && err.stack ? err.stack : err)
    );
    if (err.code === "MODULE_NOT_FOUND") {
      log("@github/copilot-language-server not found. Installing...");
      const { execSync } = require("child_process");
      try {
        execSync("npm install @github/copilot-language-server", {
          stdio: "inherit",
          cwd: __dirname,
        });
        // Try again after install
        const CopilotLanguageServer = require("@github/copilot-language-server");
        return CopilotLanguageServer;
      } catch (installErr) {
        log(
          "Failed to install @github/copilot-language-server: " +
            (installErr && installErr.stack ? installErr.stack : installErr)
        );
        process.exit(1);
      }
    } else {
      log(
        "Error loading @github/copilot-language-server: " +
          (err && err.stack ? err.stack : err)
      );
      process.exit(1);
    }
  }
}

// --- Patch: Add logging for all requests and responses ---

// --- Check if Copilot LSP Node.js process is already running ---
const { execSync } = require("child_process");
const copilotLspCmd = process.argv.join(" ");
let alreadyRunning = false;
try {
  // List all Node.js processes and check for copilot-language-server.js with same parameters
  const tasklist = execSync(
    "wmic process where name='node.exe' get CommandLine,ProcessId /FORMAT:CSV",
    { encoding: "utf8" }
  );
  const lines = tasklist.split(/\r?\n/);
  for (const line of lines) {
    if (
      line.includes("copilot-language-server.js") &&
      line.includes(__dirname)
    ) {
      // Optionally check for matching parameters
      if (copilotLspCmd && line.includes(copilotLspCmd)) {
        alreadyRunning = true;
        log("Copilot LSP Node.js process already running: " + line);
        break;
      }
    }
  }
} catch (e) {
  log(
    "Error checking for running Node.js processes: " +
      (e && e.stack ? e.stack : e)
  );
}

if (alreadyRunning) {
  log(
    "Not starting CopilotLanguageServer: already running with correct parameters. Exiting."
  );
  process.exit(0);
} else {
  const CopilotLanguageServer = ensureCopilotLanguageServer();
  log(
    "Result of require('@github/copilot-language-server'): " +
      JSON.stringify(CopilotLanguageServer)
  );
  if (
    CopilotLanguageServer &&
    typeof CopilotLanguageServer.run === "function"
  ) {
    const originalRun = CopilotLanguageServer.run;
    CopilotLanguageServer.run = function (...args) {
      log("CopilotLanguageServer.run called");
      try {
        if (this && typeof this.on === "function") {
          this.on("request", (req) => {
            log(
              "CopilotLanguageServer received request: " + JSON.stringify(req)
            );
          });
          this.on("response", (res) => {
            log("CopilotLanguageServer sent response: " + JSON.stringify(res));
          });
          this.on("error", (err) => {
            log(
              "CopilotLanguageServer error: " +
                (err && err.stack ? err.stack : err)
            );
          });
        }
        return originalRun.apply(this, args);
      } catch (e) {
        log(
          "CopilotLanguageServer.run exception: " + (e && e.stack ? e.stack : e)
        );
        throw e;
      }
    };
    CopilotLanguageServer.run();
  } else {
    log(
      "CopilotLanguageServer.run is not a function or server not loaded. Exiting."
    );
    process.exit(1);
  }
}
