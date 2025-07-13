# Copilot LSP Server Setup (RAD Studio Extension)

## Required Node.js Package

- The extension requires the official Copilot LSP server package:
  ```
  @github/copilot-language-server
  ```

## Installation Steps

- The extension will attempt to auto-install the package in the output directory at runtime.
- If auto-install fails (e.g., due to missing `package.json`, network, or permissions), you must install manually:

  ```shell
  cd d:\harrybin\copilot-RADStudio-extension\build\output
  npm init -y
  npm install @github/copilot-language-server
  ```

## Troubleshooting

- If you see errors about missing modules or failed installs:
  - Check the log file: `copilot-lsp-server.log` (same directory as the JS file).
  - Review npm error logs in your user profile:  
    `C:\Users\<YourUser>\AppData\Local\npm-cache\_logs\...`
  - Common issues:
    - No `package.json` in output directory (run `npm init -y`)
    - Network or proxy issues (check npm config)
    - Permissions (run terminal as administrator if needed)

## Runtime Diagnostics

- All startup, install, and error events are logged to `copilot-lsp-server.log`.
- If the Node.js process exits with code 1, check the log for stack traces and error details.

## Manual Deployment

- If auto-install is not desired, you can pre-install the package in the output directory before running the extension.

Once installation completes, the extension will start the Copilot LSP server and route chat requests through it.
# Copilot Extension for RAD Studio by harrybin

A RAD Studio IDE extension that integrates GitHub Copilot's conversational AI assistance directly into the RAD Studio IDE environment using the IDE Tools API.

## Overview

This extension creates an adapter wrapper around the VS Code Copilot Chat functionality, bringing GitHub Copilot's powerful AI assistance to RAD Studio developers working with Delphi and C++Builder projects.

## Features

- **AI Code Assistance**: Get intelligent code suggestions and explanations
- **Chat Interface**: Interactive chat panel integrated into RAD Studio IDE
- **Context Awareness**: Understanding of RAD Studio projects and code structure
- **Multi-Language Support**: Works with both Delphi (Object Pascal) and C++Builder

## Architecture

- **Tools API Integration**: Built using RAD Studio's Open Tools API (OTA) and Native Tools API (NTA)
- **VS Code Bridge**: Adapter layer connecting to VS Code Copilot Chat functionality
- **VCL Components**: Native RAD Studio UI components for seamless integration

## Requirements

- RAD Studio Athens 12.3 or later
- GitHub Copilot subscription
- Node.js runtime (for VS Code bridge components)

## Installation

1. Download the latest release package
2. Install via Component > Install Packages in RAD Studio
3. Configure GitHub Copilot authentication

## Using the DelphiLSP Server of the VS Code Extension EmbarcaderoTechnologies.delphilsp

To enable advanced code insight and language features for Delphi projects in VS Code, follow these steps:

1. **Prerequisites**
   - Make sure you have Embarcadero Delphi 11.0 or higher installed on your machine.

2. **Generate .delphilsp.json Files**
   - In Delphi, go to: `Tools > Options > User Interface > Editor > Language > Code Insight`.
   - Turn on **Generate LSP Config**.
   - Close and reopen your project to generate the `.delphilsp.json` file for each project you want to work with.
   - For full details, see the [Code Insight Reference](https://docwiki.embarcadero.com/RADStudio/Athens/en/Code_Insight_Reference) page on the docwiki.

3. **Open Your Project in VS Code**
   - Open a directory in VS Code that contains one or more Delphi projects.
   - If there are multiple projects (`.delphilsp.json` files) in the folder, you will be prompted to choose one.
   - If you close the project selection dialog by mistake, you can execute the command **DelphiLSP: Select project settings** to set the project context.

4. **Start Coding**
   - You can now work with your Delphi code in VS Code with full language server support.

## Development

See [Development Guide](docs/development.md) for detailed information on building and contributing to this extension.

## Project Structure

```
/src
  /toolsapi          # Tools API interface implementations
  /copilot-bridge    # VS Code Copilot Chat adapter layer
  /ui                # RAD Studio UI components
  /services          # Core service implementations
/package             # Package definition and registration
/docs               # Integration documentation
/tests              # Unit and integration tests
/build              # Build scripts and configuration
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

