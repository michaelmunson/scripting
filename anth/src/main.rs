use clap::{Parser, Subcommand};
use colored::*;
use rustyline::error::ReadlineError;
use rustyline::Editor;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use tokio;

#[derive(Parser)]
#[command(name = "anth")]
#[command(about = "Anthropic CLI tool for chatting and generating content")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start an interactive chat session
    Start,
    /// Generate a response to a message
    Gen {
        /// The message to send
        message: String,
    },
    /// Generate a commit message from git diff
    Commit,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct Message {
    role: String,
    content: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct AnthropicRequest {
    model: String,
    max_tokens: u32,
    messages: Vec<Message>,
}

#[derive(Debug, Deserialize)]
struct AnthropicResponse {
    content: Vec<Content>,
}

#[derive(Debug, Deserialize)]
struct Content {
    text: String,
}

struct AnthropicClient {
    client: reqwest::Client,
    api_key: String,
    base_url: String,
}

impl AnthropicClient {
    fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let api_key = env::var("ANTHROPIC_API_KEY")
            .or_else(|_| {
                // Try to read from config file
                let config_path = get_config_path()?;
                if config_path.exists() {
                    let config_content = fs::read_to_string(config_path)?;
                    let config: HashMap<String, String> = serde_json::from_str(&config_content)?;
                    Ok(config.get("api_key").cloned().unwrap_or_default())
                } else {
                    Ok(String::new())
                }
            })
            .unwrap_or_else(|_: Box<dyn std::error::Error>| String::new());

        if api_key.is_empty() {
            return Err("ANTHROPIC_API_KEY not found. Please set it as an environment variable or in the config file.".into());
        }

        Ok(Self {
            client: reqwest::Client::new(),
            api_key,
            base_url: "https://api.anthropic.com/v1/messages".to_string(),
        })
    }

    async fn send_message(&self, messages: Vec<Message>) -> Result<String, Box<dyn std::error::Error>> {
        let request = AnthropicRequest {
            model: "claude-3-sonnet-20240229".to_string(),
            max_tokens: 1000,
            messages,
        };

        let response = self
            .client
            .post(&self.base_url)
            .header("x-api-key", &self.api_key)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .json(&request)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            return Err(format!("API request failed: {}", error_text).into());
        }

        let response_data: AnthropicResponse = response.json().await?;
        Ok(response_data.content.first().map(|c| c.text.clone()).unwrap_or_default())
    }
}

fn get_config_path() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let config_dir = dirs::config_dir()
        .ok_or("Could not find config directory")?
        .join("anth");
    
    if !config_dir.exists() {
        fs::create_dir_all(&config_dir)?;
    }
    
    Ok(config_dir.join("config.json"))
}

fn get_chat_history_path() -> Result<PathBuf, Box<dyn std::error::Error>> {
    let data_dir = dirs::data_dir()
        .ok_or("Could not find data directory")?
        .join("anth");
    
    if !data_dir.exists() {
        fs::create_dir_all(&data_dir)?;
    }
    
    Ok(data_dir.join("chat_history.json"))
}

fn load_chat_history() -> Vec<Message> {
    let history_path = match get_chat_history_path() {
        Ok(path) => path,
        Err(_) => return Vec::new(),
    };

    if let Ok(content) = fs::read_to_string(history_path) {
        serde_json::from_str(&content).unwrap_or_default()
    } else {
        Vec::new()
    }
}

fn save_chat_history(messages: &[Message]) -> Result<(), Box<dyn std::error::Error>> {
    let history_path = get_chat_history_path()?;
    let content = serde_json::to_string_pretty(messages)?;
    fs::write(history_path, content)?;
    Ok(())
}

fn get_git_diff() -> Result<String, Box<dyn std::error::Error>> {
    let output = Command::new("git")
        .args(["diff", "--cached"])
        .output()?;

    if output.status.success() {
        Ok(String::from_utf8(output.stdout)?)
    } else {
        // Try unstaged changes if no staged changes
        let output = Command::new("git")
            .args(["diff"])
            .output()?;
        
        if output.status.success() {
            Ok(String::from_utf8(output.stdout)?)
        } else {
            Err("No git changes found".into())
        }
    }
}

async fn start_chat() -> Result<(), Box<dyn std::error::Error>> {
    let client = AnthropicClient::new()?;
    let mut rl: Editor<(), rustyline::FileHistory> = Editor::new()?;
    let mut messages = load_chat_history();

    println!("{}", "Welcome to Anthropic CLI Chat!".green().bold());
    println!("Type 'quit' or 'exit' to end the session.");
    println!("Type 'clear' to clear chat history.");
    println!();

    loop {
        let readline = rl.readline("You: ");
        match readline {
            Ok(line) => {
                let line = line.trim();
                
                if line.is_empty() {
                    continue;
                }

                match line {
                    "quit" | "exit" => {
                        println!("Goodbye!");
                        break;
                    }
                    "clear" => {
                        messages.clear();
                        save_chat_history(&messages)?;
                        println!("{}", "Chat history cleared.".yellow());
                        continue;
                    }
                    _ => {
                        // Add user message
                        messages.push(Message {
                            role: "user".to_string(),
                            content: line.to_string(),
                        });

                        print!("{}", "Claude: ".blue().bold());
                        
                        // Send to API
                        match client.send_message(messages.clone()).await {
                            Ok(response) => {
                                println!("{}", response);
                                
                                // Add assistant response
                                messages.push(Message {
                                    role: "assistant".to_string(),
                                    content: response,
                                });
                                
                                // Save history
                                if let Err(e) = save_chat_history(&messages) {
                                    eprintln!("Warning: Failed to save chat history: {}", e);
                                }
                            }
                            Err(e) => {
                                println!("{}", format!("Error: {}", e).red());
                                // Remove the user message if API call failed
                                messages.pop();
                            }
                        }
                    }
                }
            }
            Err(ReadlineError::Interrupted) => {
                println!("^C");
                break;
            }
            Err(ReadlineError::Eof) => {
                println!("^D");
                break;
            }
            Err(err) => {
                println!("Error: {}", err);
                break;
            }
        }
    }

    Ok(())
}

async fn generate_message(message: String) -> Result<(), Box<dyn std::error::Error>> {
    let client = AnthropicClient::new()?;
    
    let messages = vec![Message {
        role: "user".to_string(),
        content: message,
    }];

    match client.send_message(messages).await {
        Ok(response) => {
            println!("{}", response);
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

async fn generate_commit_message() -> Result<(), Box<dyn std::error::Error>> {
    let diff = get_git_diff()?;
    
    if diff.trim().is_empty() {
        eprintln!("{}", "No git changes found. Please stage some changes first.".red());
        std::process::exit(1);
    }

    let client = AnthropicClient::new()?;
    
    let prompt = format!(
        "Please generate a concise and descriptive commit message for the following git diff. \
         The commit message should follow conventional commit format and be clear about what changes were made:\n\n{}",
        diff
    );

    let messages = vec![Message {
        role: "user".to_string(),
        content: prompt,
    }];

    match client.send_message(messages).await {
        Ok(response) => {
            println!("{}", "Suggested commit message:".green().bold());
            println!("{}", response.trim());
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv::dotenv().ok();

    let cli = Cli::parse();

    match cli.command {
        Commands::Start => {
            start_chat().await?;
        }
        Commands::Gen { message } => {
            generate_message(message).await?;
        }
        Commands::Commit => {
            generate_commit_message().await?;
        }
    }

    Ok(())
}
