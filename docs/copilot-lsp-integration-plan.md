# Copilot Language Server Integration Plan for RAD Studio Extension

## Goal
Integrate GitHub Copilot's agent mode into RAD Studio using copilot-language-server-release, leveraging the ToolsAPI and ToolsAPI.AI if possible.


## Checklist

- [ ] Step 1: Research and document ToolsAPI.AI plugin architecture and required interfaces (`IOTAAIPlugin`, `IOTAAIEngineService`, etc.)
- [ ] Step 2: Assess and design a Delphi-based LSP client to communicate with copilot-language-server-release (JSON-RPC over stdio/IPC)
- [ ] Step 3: Architect the AI plugin to register Copilot agent mode features using ToolsAPI.AI (TAIFeature, TAIFeatures)
- [ ] Step 4: Plan and implement process management for launching and monitoring copilot-language-server
- [ ] Step 5: Implement LSP client core (initialization, document sync, authentication, completions, agent mode)
- [ ] Step 6: Integrate with ToolsAPI.AI to expose Copilot features in RAD Studio (chat, inline suggestions, agent mode)
- [ ] Step 7: Design and implement UI components for chat, agent mode, and status using VCL and ToolsAPI services
- [ ] Step 8: Identify and remove obsolete or conflicting code from the current project
- [ ] Step 9: Test build after each major step and fix any errors
- [ ] Step 10: Finalize, refactor, and document the extension
