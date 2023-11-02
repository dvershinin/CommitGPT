# Git Commit Message Hook

## Description
This git hook automatically generates commit messages based on the changes made to the files in a repository.

## Prerequisites

- `jq`
- `curl`
- `git`

## Installation Instructions

Clone this repository:

````bash
git clone https://github.com/dvershinin/CommitGPT.git ~/.local/share/CommitGPT
````

Navigate to your project's git hooks directory. It is usually located in:

```bash
cd your-project/.git/hooks/
```

Create a symbolic link to the `prepare-commit-msg` hook from the cloned repository:

```bash
ln -s ~/.local/share/CommitGPT/prepare-commit-msg.sh prepare-commit-msg 
```

```bash
chmod +x prepare-commit-msg 
```

Configure the necessary environment variable `OPENAI_API_KEY` in your `.bashrc`, for example.

## Usage

Once installed, the hook will automatically run when you execute git commit in your project repository.

To automatically generate commit messages disregarding any user input (in automated scripts for example, you can use):

```bash
GIT_EDITOR=true git commit
```

## Configuring project goal

This step is optional, but it is recommended to configure the project goal in the `prepare-commit-msg` hook. 
This will help generate more elaborate reasons as to *why* the changes introduced by commit was made

Navigate to the Repository:

Change directory into the repository where you want to configure the project goal.


Run the following command to set a custom prompt, for example:

```bash
git config commit.goal "package new NGINX versions"
```

### Verifying the Configuration:

To verify that the configuration has been set correctly, you can use the following command:

```bash
git config --get commit.goal
```

This command will output the currently set goal, allowing you to confirm it’s correctly configured.
