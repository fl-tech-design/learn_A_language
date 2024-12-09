# EmptyKivyTemplate v1.0

## Overview
This is a basic template for a Kivy application that features a simple home screen with two buttons leading to settings pages, where language can be adjusted.

## Features
- **Home Screen:** Displays two buttons leading to different settings.
- **Settings Page:** Allows language adjustment.

## Requirements
- Python 3.10
- Kivy 2.3.0
## Installation

1. **Clone the repository:**
   ```bash
    git clone https://github.com/fl-tech-design/empty_kivy_template.git
    cd empty_kivy_template

2. **Create a virtual environment (optional but recommended):**
    ```bash
    python3 -m venv venv
    source venv/bin/activate  # On Windows, use venv\Scripts\activate

3. **Install the required dependencies:**
    ```bash
    pip install -r requirements.txt

4. **Run the application:**
    ```bash
    python3 main.py

## Usage
**Working with the Repository**  
When you clone this repository, you are downloading all the necessary files to work with the basic template, including the .git directory, which contains the version control history.  

If you want to use this template as a base for your own project, you can do the following:

1. **Start a New Git Repository:**  
    If you want to create your own separate project, you can remove the existing Git history and initialize a new repository:
    ```bash
    # Remove the existing .git directory, which contains the version history 
    # and all Git-related metadata. This effectively disconnects your local 
    # copy from the original repository.
    rm -rf .git

    # Initialize a new Git repository in the current directory. 
    # This creates a new .git directory and starts tracking changes.
    git init

    # Add all files in the current directory to the staging area. 
    # This prepares them to be included in the next commit.
    git add .

    # Create a new commit with the message "Initial commit". 
    # This saves the current state of the files in the repository.
    git commit -m "Initial commit"
2. **Push to Your Own GitHub Repository:**  
After creating your own Git repository, you can push it to a new GitHub repository:
    ```bash
    # Link your local repository to a remote repository hosted on a platform 
    # like GitHub. Replace <your-repo-url> with the actual URL of your new remote repository.
    git remote add origin <your-repo-url>

    # Push the changes from your local repository to the remote repository. 
    # The `-u` flag sets the upstream tracking, so future pushes can be done 
    # simply with `git push`.
    git push -u origin main
## Forking and Contributions

Forks of this repository are welcome, but please note the following guidelines:

- **Forking Purpose**: This repository is intended to serve as a minimal template for Kivy applications. Forks should be focused on improving the existing base code (e.g., bug fixes, optimizations, or enhancements to existing functionality).
  
- **Pull Requests**: Pull requests are welcome if they improve the existing functionality of the base code. However, any pull requests that introduce additional features or app-specific logic will be declined. The goal of this repository is to remain a clean and simple starting point for new Kivy applications.

- **General Rule**: If you wish to extend or customize this template for a specific project, please do so in your own fork. The main repository will only include improvements that maintain the template’s status as a bare-bones foundation.

Thank you for understanding and contributing within these guidelines!