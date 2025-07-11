# Development Guide

This guide provides detailed information for developers working on the RAD Studio Copilot Extension.

## Prerequisites

- RAD Studio Athens 12.3 or later
- Node.js 16.0 or later
- GitHub Copilot subscription
- Git for version control

## Development Environment Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd copilot-RADStudio-extension
```

### 2. Install Dependencies

The extension requires Node.js for the VS Code Copilot bridge functionality:

```bash
# Install Node.js dependencies (if bridge components are added)
npm install
```

### 3. Open in RAD Studio

1. Open RAD Studio
2. Open the package file: `package\RADStudioCopilotExtension.dpk`
3. Build the package (Ctrl+F9)

## Architecture Overview

### Component Structure

```
RAD Studio IDE
    ↓
Tools API Layer (Pascal/Delphi)
    ↓
Core Services (Pascal/Delphi)
    ↓
Bridge Layer (Pascal/Delphi ↔ Node.js)
    ↓
VS Code Copilot Chat (TypeScript/JavaScript)
    ↓
GitHub Copilot Service
```

### Key Components

1. **Tools API Integration** (`src/toolsapi/`)
   - IDE menu integration
   - Editor services and notifications
   - Project context awareness

2. **Core Services** (`src/services/`)
   - Main service coordination
   - Authentication management
   - Configuration handling

3. **Copilot Bridge** (`src/copilot-bridge/`)
   - Interface to VS Code Copilot Chat
   - Inter-process communication
   - Request/response handling

4. **UI Components** (`src/ui/`)
   - Chat panel interface
   - Settings dialogs
   - Status displays

## Building and Testing

### Building the Package

1. Open `package\RADStudioCopilotExtension.dpk` in RAD Studio
2. Build the package (Project → Build)
3. Install the package (Component → Install Packages)

### Testing

1. After installation, restart RAD Studio
2. Check Tools menu for "GitHub Copilot" submenu
3. Test authentication and chat functionality

### Debugging

- Use RAD Studio's integrated debugger for Pascal/Delphi code
- For Node.js bridge components, use VS Code or node debugger
- Check IDE message window for error messages

## Code Guidelines

### Pascal/Delphi Conventions

- Use proper memory management with `try...finally` blocks
- Handle exceptions appropriately
- Use `NativeInt` for pointer operations (large-address-aware)
- Follow RAD Studio naming conventions

### Interface Design

- All major functionality should be interface-based
- Use dependency injection where possible
- Implement proper error handling and logging

### Tools API Best Practices

- Use `BorlandIDEServices` to access IDE services
- Register/unregister services properly in package initialization/finalization
- Handle IDE shutdown gracefully

## Testing Strategy

### Unit Tests

- Create unit tests for core service functionality
- Test authentication flows
- Test bridge communication

### Integration Tests

- Test full IDE integration
- Test menu functionality
- Test chat interface

### Manual Testing

- Test with different project types (Delphi, C++)
- Test authentication scenarios
- Test error handling

## Common Development Tasks

### Adding New Menu Items

1. Edit `CopilotExtension.ToolsAPI.Implementation.pas`
2. Add menu item creation in `RegisterMenuItems`
3. Add event handler method
4. Update `UnregisterMenuItems` for cleanup

### Adding New Services

1. Create interface in appropriate directory
2. Implement service class
3. Register with core service
4. Add to package requires/contains

### Extending Bridge Functionality

1. Add method to `ICopilotBridge` interface
2. Implement in `TCopilotBridge` class
3. Add corresponding Node.js bridge script functionality
4. Test communication

## Deployment

### Package Distribution

1. Build release version of package
2. Create installer or distribution package
3. Include Node.js dependencies if needed
4. Provide installation instructions

### Installation Process

1. User installs package via Component → Install Packages
2. Extension registers with IDE automatically
3. User configures GitHub authentication
4. Extension is ready for use

## Troubleshooting

### Common Issues

1. **Package won't install**
   - Check RAD Studio version compatibility
   - Verify all dependencies are available
   - Check for conflicting packages

2. **Menu items don't appear**
   - Verify package registration in initialization
   - Check Tools API service availability
   - Restart RAD Studio

3. **Bridge communication fails**
   - Verify Node.js installation
   - Check bridge script path
   - Review error messages in IDE

4. **Authentication problems**
   - Verify GitHub token permissions
   - Check Copilot subscription status
   - Clear stored credentials and retry

### Debug Logging

Enable debug logging by setting log level in configuration:

```pascal
CoreService.SetConfigValue('logLevel', 'debug');
```

Check IDE message window for detailed logs.

## Contributing

### Code Review Process

1. Create feature branch
2. Implement changes following guidelines
3. Add tests for new functionality
4. Submit pull request
5. Address review feedback

### Documentation

- Update this guide for architectural changes
- Add inline code documentation
- Update README for user-facing changes

## Resources

- [RAD Studio Tools API Documentation](https://docwiki.embarcadero.com/RADStudio/Athens/en/Extending_the_IDE_Using_the_Tools_API)
- [GitHub Copilot API Documentation](https://docs.github.com/en/copilot)
- [VS Code Extension API](https://code.visualstudio.com/api)
- [Node.js Documentation](https://nodejs.org/docs/)
