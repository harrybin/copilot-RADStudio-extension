# GitHub Copilot Instructions - RAD Studio Copilot Extension

## Project Overview

This is a RAD Studio IDE extension that creates an adapter wrapper around the [VS Code Copilot Chat](https://github.com/microsoft/vscode-copilot-chat) functionality. The goal is to integrate GitHub Copilot's conversational AI assistance directly into the RAD Studio IDE environment using the [IDE Tools API](https://docwiki.embarcadero.com/RADStudio/Athens/en/Extending_the_IDE_Using_the_Tools_API).

## Architecture & Key Components

### RAD Studio Integration Layer

- **Package Structure**: Extension built as a RAD Studio package using the Tools API
- **Data Module Pattern**: Use VCL-affinity data modules for OnCreate/OnDestroy lifecycle management
- **API Interfaces**: Leverage both OTA (Open Tools API) and NTA (Native Tools API) interfaces
- **Tools API Location**: Interface declarations found at `C:\Program Files (x86)\Embarcadero\Studio\23.0\source\ToolsAPI`
  - **Tools API** documentation: when needed fetch them here [Tools API Documentation](https://docwiki.embarcadero.com/Libraries/Athens/de/ToolsAPI)

## VS Code Copilot Chat Adapter

- **Target Integration**: Wrap VS Code Copilot Chat TypeScript/JavaScript functionality
  - find the original source code here [VS Code Copilot Chat](https://github.com/microsoft/vscode-copilot-chat)
- **Communication Bridge**: Create interface layer between RAD Studio's Pascal/Delphi environment and Node.js-based Copilot Chat
- **UI Integration**: Implement chat interface within RAD Studio IDE using Tools API UI services

## Development Conventions

- You are developing a RAD Studio IDE extension for RAD studio Athen or newer
- Use Pascal/Delphi filename conventions and class naming conventions
- Follow RAD Studio's VCL component design patterns for UI components
- find default [unit documentation here](https://docwiki.embarcadero.com/Libraries/Athens/en/Unit_List)
- for the objectpascel/delphi programming language use the reference [Object Pascal Language Guide](https://docwiki.embarcadero.com/RADStudio/Athens/en/Delphi_Language_Reference)
  Always reguard that the Object Pascal Language Guide is the primary source for language features, syntax, and semantics.

### Tools API Best Practices

- **Memory Management**: Use `NativeInt` instead of `Integer` for pointer casting (large-address-aware support)
- **Handle Declarations**: Use `THandle` type instead of `Integer` for Windows handles
- **Windows API**: Use proper `LPARAM`/`WPARAM` types for `SendMessage` calls
- **Interface Categories**: Distinguish between OTA (version-independent) and NTA (version-specific) interfaces
- take care of type compatibility when using Tools API interfaces

### IDE Integration Patterns

- **Menu Placement**: External tools go in Tools menu; help resources in Help > Third-Party Help
- **Service Access**: Use `BorlandIDEServices` to obtain Tools API service interfaces
- **Extension Lifecycle**: Implement proper initialization in package initialization/finalization

### Code Organization

- **Package Configuration**: Design-time package with IDE extension capabilities
- **Unit Structure**: Separate units for API interfaces, UI components, and business logic
- **Dependencies**: Handle both runtime and design-time package dependencies appropriately

## Key Development Workflows

### Building & Installation

1. Compile package using RAD Studio IDE

### VS Code Integration Testing

- Verify Copilot Chat API compatibility with current VS Code versions
- Test TypeScript/JavaScript bridge functionality
- Validate chat participant, variable, and slash command integration

## Integration Points

### External Dependencies

- **GitHub Copilot Service**: Authentication and AI model access
- **Node.js Runtime**: For executing VS Code Copilot Chat components
- **VS Code Extension Host**: Potential process communication requirements

### RAD Studio Services

- **IOTAEditorServices**: Code editor integration for inline suggestions
- **IOTAMessageServices**: Message window integration for chat display
- **IOTAMenuService**: Menu item registration and management
- **IOTAToolBarService**: Toolbar button integration

## Critical Technical Considerations

### Cross-Platform Compatibility

- Ensure large-address-aware compatibility (4GB+ memory support)
- Handle Windows-specific API calls appropriately
- Consider personality services for multi-language IDE support (Delphi/C++)

### Version Compatibility

- OTA interfaces preferred for version independence
- Handle RAD Studio version differences (Athens/Alexandria/Sydney)
- VS Code Copilot Chat version synchronization requirements

### Performance & Resource Management

- Minimize IDE startup impact through lazy initialization
- Proper cleanup in package finalization
- Handle potential memory leaks in cross-process communication

## File Structure Expectations

```
/src
  /toolsapi          # Tools API interface implementations
  /copilot-bridge    # VS Code Copilot Chat adapter layer
  /ui                # RAD Studio UI components
  /services          # Core service implementations
/package             # Package definition and registration
/docs               # Integration documentation
```

## Development Notes

- VS Code Copilot Chat updates frequently - monitor compatibility
- Consider enterprise authentication requirements for GitHub Copilot access
- Implement graceful degradation when Copilot services unavailable

## Development Workflow

- implement the requested feature in the source code
- at the end of code creation, after all identified tasks are done build the package by using the vscode task "🚀Build Extension🚀"
- check for compilation errors and fix them
- reapeat rebuilding until no errors are present, or you detect some kind loop with the steps above
