#!/data/data/com.termux/files/usr/bin/bash

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display error messages
error_msg() {
    echo -e "${RED}[!] Error: $1${NC}" >&2
    exit 1
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if git is installed
if ! command_exists git; then
    error_msg "Git is not installed. Please install git first."
fi

# Check if jq is installed (for API calls)
if ! command_exists jq; then
    echo -e "${YELLOW}[!] jq is not installed. Some features will be limited.${NC}"
    read -p "Do you want to install jq? (y/n): " install_jq
    if [[ "$install_jq" =~ ^[Yy]$ ]]; then
        pkg install jq -y || error_msg "Failed to install jq"
    fi
fi

# Main function
main() {
    echo -e "${BLUE}=== GitHub Repository Uploader ===${NC}"
    
    # Get user input
    read -p "GitHub Username: " username
    [ -z "$username" ] && error_msg "Username cannot be empty"
    
    read -p "Repository Name: " repo
    [ -z "$repo" ] && error_msg "Repository name cannot be empty"
    
    read -p "Branch (default: main): " branch
    branch=${branch:-main}
    
    read -p "GitHub Token: " token
    [ -z "$token" ] && error_msg "Token cannot be empty"
    
    # Check if repository exists
    echo -e "${YELLOW}[*] Checking repository...${NC}"
    response=$(curl -s -H "Authorization: token $token" "https://api.github.com/repos/$username/$repo")
    
    if echo "$response" | jq -e '.message' | grep -q "Not Found"; then
        # Repository doesn't exist, create it
        echo -e "${YELLOW}[*] Creating new repository...${NC}"
        curl -s -X POST -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" \
            -d "{\"name\":\"$repo\", \"private\":false, \"auto_init\":false}" \
            "https://api.github.com/user/repos" || error_msg "Failed to create repository"
    else
        # Check if we have access to the repository
        if echo "$response" | jq -e '.message' | grep -q "Bad credentials"; then
            error_msg "Invalid token or permissions"
        fi
        echo -e "${GREEN}[*] Repository exists, will upload files${NC}"
    fi
    
    # Initialize git
    echo -e "${YELLOW}[*] Initializing Git repo...${NC}"
    git init || error_msg "Failed to initialize git repository"
    
    # Setup user info
    git config --global user.name "$username" || error_msg "Failed to set git username"
    git config --global user.email "$username@users.noreply.github.com" || error_msg "Failed to set git email"
    
    # Mark directory as safe
    git config --global --add safe.directory "$(pwd)" || error_msg "Failed to mark directory as safe"
    
    # Add all files
    echo -e "${YELLOW}[*] Adding files...${NC}"
    git add . || error_msg "Failed to add files"
    
    # Commit with timestamp
    commit_msg="Upload: $(date +"%Y-%m-%d %H:%M:%S")"
    git commit -m "$commit_msg" || error_msg "Failed to commit changes"
    
    # Rename branch if needed
    git branch -M "$branch" || error_msg "Failed to rename branch"
    
    # Add remote
    git remote add origin "https://$username:$token@github.com/$username/$repo.git" || error_msg "Failed to add remote"
    
    # Push to GitHub
    echo -e "${YELLOW}[*] Pushing to GitHub...${NC}"
    git push -u origin "$branch" || error_msg "Failed to push to GitHub"
    
    # Additional features
    echo -e "\n${GREEN}[v] Upload successful!${NC}"
    echo -e "${BLUE}Repository URL: https://github.com/$username/$repo${NC}"
    echo -e "${BLUE}Branch: $branch${NC}"
    
    # Open in browser if possible
    if command_exists termux-open-url; then
        read -p "Do you want to open the repository in browser? (y/n): " open_browser
        if [[ "$open_browser" =~ ^[Yy]$ ]]; then
            termux-open-url "https://github.com/$username/$repo"
        fi
    fi
    
    # Create .gitignore if not exists
    if [ ! -f ".gitignore" ]; then
        read -p "No .gitignore found. Create one? (y/n): " create_gitignore
        if [[ "$create_gitignore" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*] Creating basic .gitignore...${NC}"
            echo -e ".DS_Store\n*.log\n*.tmp\n*.swp\n.env\nnode_modules/\n__pycache__/\n.idea/\n.vscode/" > .gitignore
            git add .gitignore
            git commit -m "Add .gitignore"
            git push origin "$branch"
        fi
    fi
}

# Run main function
main