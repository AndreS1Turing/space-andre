#!/bin/bash

# 1. Grab URLs
echo "Searching GitHub for PRs..."
urls=$(gh search prs "is:public is:merged linked:issue label:bug merged:>2026-04-15" --limit 500 --json url --jq '.[].url')

# Count how many URLs we actually got
url_count=$(echo "$urls" | wc -w)
echo "Found $url_count PRs to check."

if [ "$url_count" -eq 0 ]; then
    echo "Error: The search returned 0 URLs. Try running 'gh auth refresh' or widening the date range."
    exit 1
fi

# Empty the file if it exists so we start fresh
> candidate_tasks.jsonl

# 2. Loop through and check each one
count=1
for url in $urls; do
  echo -n "[$count/$url_count] Checking $url... "
  
  # Fetch the data, capturing any errors
  pr_data=$(gh pr view "$url" --json changedFiles 2>&1)
  
  # Check if the command failed (e.g., rate limit hit)
  if [[ $pr_data == *"rate limit"* ]] || [[ $pr_data == *"error"* ]]; then
      echo "FAILED (API Error: $pr_data)"
      # Wait a bit longer if we hit a rate limit
      sleep 2
  else
      # Extract just the number
      file_count=$(echo "$pr_data" | jq '.changedFiles')
      
      if [ "$file_count" -ge 3 ] && [ "$file_count" -le 6 ]; then
         echo "$file_count files - MATCH!"
         gh pr view "$url" --json url,title,changedFiles --jq '{url: .url, title: .title, files: .changedFiles}' >> candidate_tasks.jsonl
      else
         echo "$file_count files - Skipping."
      fi
  fi
  
  # Small delay to prevent rate-limiting
  sleep 0.5
  ((count++))
done

echo "Done! Check candidate_tasks.jsonl"