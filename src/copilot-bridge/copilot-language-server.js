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
    // Try to require the package
    const {
      CopilotLanguageServer,
    } = require("@githubnext/copilot-language-server");
    return CopilotLanguageServer;
  } catch (err) {
    log(
      'Error in require("@githubnext/copilot-language-server"): ' +
        (err && err.stack ? err.stack : err)
    );
    if (err.code === "MODULE_NOT_FOUND") {
      log("@githubnext/copilot-language-server not found. Installing...");
      const { execSync } = require("child_process");
      try {
        execSync("npm install @githubnext/copilot-language-server", {
          stdio: "inherit",
          cwd: __dirname,
        });
        // Try again after install
        const {
          CopilotLanguageServer,
        } = require("@githubnext/copilot-language-server");
        return CopilotLanguageServer;
      } catch (installErr) {
        log(
          "Failed to install @githubnext/copilot-language-server: " +
            (installErr && installErr.stack ? installErr.stack : installErr)
        );
        process.exit(1);
      }
    } else {
      log(
        "Error loading @githubnext/copilot-language-server: " +
          (err && err.stack ? err.stack : err)
      );
      process.exit(1);
    }
  }
}

const CopilotLanguageServer = ensureCopilotLanguageServer();
CopilotLanguageServer.run();
