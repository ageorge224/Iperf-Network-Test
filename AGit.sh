#!/bin/bash

# Prompt for a commit message
read -r -p "Enter your commit message: " commit_message

# Check if the commit message is empty
if [[ -z "$commit_message" ]]; then
	echo "Commit message cannot be empty. Please provide a message."
	exit 1
fi

# Add all changes to the staging area
git add .

# Commit the changes with the specified message
git commit -m "$commit_message"

# Check if the commit was successful
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	echo "Commit failed. Please check for errors and try again."
	exit 1
fi

# Push the changes to the remote repository
git push origin main

# Check if the push was successful
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	echo "Push failed. Please check your network connection or remote repository settings."
	exit 1
fi

echo "Changes have been successfully pushed."
