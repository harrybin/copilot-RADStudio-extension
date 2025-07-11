# RAD Studio Copilot Extension

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

[License information to be added]

## Contributing

[Contributing guidelines to be added]
