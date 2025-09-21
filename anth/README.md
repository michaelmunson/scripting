# Anth - Anthropic CLI Tool

A command-line interface tool for interacting with Anthropic's Claude AI models. This tool provides an interactive chat interface, single message generation, and automatic commit message generation from git diffs.

## Features

- **Interactive Chat**: Start a persistent chat session with Claude
- **Single Message Generation**: Send a single message and get a response
- **Commit Message Generation**: Automatically generate commit messages from git diffs
- **Chat History**: Persistent chat history across sessions
- **Colored Output**: Beautiful terminal output with colors
- **Configuration Management**: Support for environment variables and config files

## Installation

### Prerequisites

- Rust (latest stable version)
- Git (for commit message generation)

### Build from Source

```bash
# Clone the repository
git clone <your-repo-url>
cd anth

# Build the project
cargo build --release

# Install globally (optional)
cargo install --path .
```

## Configuration

### API Key Setup

You need to set up your Anthropic API key. You can do this in one of two ways:

#### Option 1: Environment Variable (Recommended)

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

Or add it to your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

#### Option 2: Config File

Create a config file at `~/.config/anth/config.json`:

```json
{
  "api_key": "your-api-key-here"
}
```

### Getting an API Key

1. Visit [Anthropic's Console](https://console.anthropic.com/)
2. Sign up or log in to your account
3. Navigate to the API Keys section
4. Create a new API key
5. Copy the key and set it up using one of the methods above

## Usage

### Interactive Chat

Start an interactive chat session with Claude:

```bash
anth start
```

This will start a chat interface where you can:
- Type messages and get responses from Claude
- Use `quit` or `exit` to end the session
- Use `clear` to clear chat history
- Use Ctrl+C to interrupt

### Single Message Generation

Send a single message and get a response:

```bash
anth gen "What is the capital of France?"
```

### Commit Message Generation

Generate a commit message from your current git changes:

```bash
# Stage your changes first
git add .

# Generate a commit message
anth commit
```

The tool will:
1. Read the current git diff (staged or unstaged changes)
2. Send it to Claude with instructions to generate a conventional commit message
3. Display the suggested commit message

## File Locations

- **Config**: `~/.config/anth/config.json`
- **Chat History**: `~/.local/share/anth/chat_history.json`

## Examples

### Interactive Chat Example

```bash
$ anth start
Welcome to Anthropic CLI Chat!
Type 'quit' or 'exit' to end the session.
Type 'clear' to clear chat history.

You: Hello! Can you help me with a programming question?
Claude: Hello! I'd be happy to help you with your programming question. What would you like to know?

You: How do I implement a binary search in Python?
Claude: Here's how you can implement a binary search in Python...

You: quit
Goodbye!
```

### Single Message Example

```bash
$ anth gen "Explain the concept of recursion in simple terms"
Recursion is a programming concept where a function calls itself...

$ anth gen "Write a Python function to calculate fibonacci numbers"
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

### Commit Message Example

```bash
$ git add .
$ anth commit
Suggested commit message:
feat: add user authentication system

- Implement login/logout functionality
- Add password hashing with bcrypt
- Create user session management
- Add middleware for protected routes
```

## Error Handling

The tool provides clear error messages for common issues:

- **Missing API Key**: Instructions on how to set up the API key
- **Network Errors**: Clear error messages for API connection issues
- **Git Errors**: Helpful messages when no git changes are found
- **Invalid Commands**: Usage help for incorrect command syntax

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Troubleshooting

### Common Issues

1. **"ANTHROPIC_API_KEY not found"**
   - Make sure you've set the environment variable or config file correctly
   - Check that the API key is valid

2. **"No git changes found"**
   - Make sure you're in a git repository
   - Stage your changes with `git add` before running `anth commit`

3. **Network errors**
   - Check your internet connection
   - Verify your API key is correct
   - Check Anthropic's service status

### Getting Help

If you encounter issues not covered here, please:
1. Check the error message carefully
2. Verify your configuration
3. Try running with verbose output
4. Open an issue on the project repository
