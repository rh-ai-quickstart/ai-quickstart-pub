#!/bin/bash 
set -euo pipefail 

ORG="${GITHUB_REPOSITORY%%/*}"
REPO="${GITHUB_REPOSITORY##*/}"

TEAM_NAME="${TEAM_NAME:-publication-admin}" # uses env var or default to publication-admin
DAYS_APPROACHING=5
DAYS_BREACHED=7
DAYS_AUTO_CLOSE=21
NOW=$(date +%s)

# extract github usernames for members of reviewer team
fn_get_reviewers() {
    local members_json
    if ! members_json=$(gh api "/orgs/$ORG/teams/$TEAM_NAME/members"); then 
        echo "ERROR: Could not fetch team members. Skipping SLA checks."
        exit 0
    fi
    
    while IFS= read -r member; do 
        ADMIN_MEMBERS+=("$member")
    done < <(echo "$members_json" | jq -r '.[].login')
}

# get PR metadata
fn_get_open_prs_metadata() {
    if ! PRs=$(gh pr list --state open --json number,author,createdAt,labels --limit 100); then 
        echo "ERROR: Could not fetch open PRs. Skipping SLA checks."
        exit 0
    fi
}

# build comment timeline without bots
fn_build_timeline() {
    local comments=$1
    local reviews=$2
    local commits=$3 

    jq -s '
        (.[0] | map({author: .user.login, created_at: .created_at, type: "comment"})) +
        (.[1] | map(select(.state != "PENDING") | {author: .user.login, created_at: .submitted_at, type: "review"})) + 
        (.[2] | map({author: (.author.login // .commit.author.name), created_at: .commit.author.date, type: "commit"}))
        | map(select(.author | contains("bot") | not))
        | sort_by(.created_at) | reverse
    ' <(echo "$comments") <(echo "$reviews") <(echo "$commits")
}

# ensure required labels exist
fn_ensure_labels() {
    local labels_needed=("sla-approaching:f9d0c4:PR approaching 7-day review SLA"
                         "sla-breached:b60205:PR exceeded 7-day review SLA"
                         "waiting-on-author:fbca04:Waiting for PR author response")

    for label_def in "${labels_needed[@]}"; do
        IFS=':' read -r name color description <<< "$label_def"

        # Check if label exists using JSON output
        if gh label list --repo "$ORG/$REPO" --json name --jq '.[].name' | grep -qx "$name"; then
            echo "Label already exists: $name"
        else
            echo "Creating label: $name"
            gh label create "$name" --repo "$ORG/$REPO" --color "$color" --description "$description" || echo "  Warning: Could not create label $name"
        fi
    done
}

fn_get_reviewers
fn_get_open_prs_metadata
fn_ensure_labels

for pr_number in $(echo "$PRs" | jq -r '.[].number'); do 
    pr_author=$(echo "$PRs" | jq -r ".[] | select(.number == $pr_number) | .author.login")
    pr_created=$(echo "$PRs" | jq -r ".[] | select(.number == $pr_number) | .createdAt")
    comments=$(gh api "/repos/$ORG/$REPO/issues/$pr_number/comments")
    commits=$(gh api "/repos/$ORG/$REPO/pulls/$pr_number/commits")
    reviews=$(gh api "/repos/$ORG/$REPO/pulls/$pr_number/reviews")
    pr_labels=$(echo "$PRs" | jq -r ".[] | select(.number == $pr_number) | .labels[].name")

    timeline=$(fn_build_timeline "$comments" "$reviews" "$commits")

    last_event_date=$(echo "$timeline" | jq -r '.[0].created_at // empty')
    if [[ -z "$last_event_date" ]]; then 
        last_event_date=$pr_created
    fi

    days_since_event=$(jq -n --arg date "$last_event_date" '(now - ($date | fromdateiso8601)) / 86400 | floor')
    last_person=$(echo "$timeline" | jq -r '.[0].author // empty')

    is_admin=false 
    for admin in "${ADMIN_MEMBERS[@]}"; do 
        if [[ "$admin" == "$last_person" ]]; then 
            is_admin=true
            break
        fi
    done

    if [[ "$is_admin" == "true" ]]; then 
        echo "::group::PR #$pr_number: waiting on AUTHOR (last: $last_person) - https://www.github.com/$ORG/$REPO/pull/$pr_number"

        if echo "$pr_labels" | grep -q "sla-approaching"; then 
            echo "Removing sla-approaching label"
            gh pr edit $pr_number --repo "$ORG/$REPO" --remove-label "sla-approaching"
        fi
        
        if echo "$pr_labels" | grep -q "sla-breached"; then 
            echo "Removing sla-breached label"
            gh pr edit $pr_number --repo "$ORG/$REPO" --remove-label "sla-breached"
        fi
        
        if ! echo "$pr_labels" | grep -q "waiting-on-author"; then 
            echo "Adding waiting-on-author label" 
            gh pr edit $pr_number --repo "$ORG/$REPO" --add-label "waiting-on-author"
            gh pr comment $pr_number --repo "$ORG/$REPO" --body "**WAITING ON AUTHOR:** This PR is now waiting on new commits or comments from the author and will automatically close after $DAYS_AUTO_CLOSE days. Simply comment to keep the PR open, or reopen if automatically closed."
        fi

        if [[ $days_since_event -ge $DAYS_AUTO_CLOSE ]]; then 
            echo "WARNING: AUTO-CLOSING: $days_since_event days of author inactivity" 
            gh pr close $pr_number --repo "$ORG/$REPO" --comment "**CLOSING PR:** Closing due to $DAYS_AUTO_CLOSE days of inactivity after publication-admin feedback. Please reopen when ready to continue."
        fi
    else 
        echo "::group::PR #$pr_number: waiting on ADMIN (last: ${last_person:-nobody yet}) - https://www.github.com/$ORG/$REPO/pull/$pr_number"

        if echo "$pr_labels" | grep -q "waiting-on-author"; then 
            echo "Removing waiting-on-author label" 
            gh pr edit $pr_number --repo "$ORG/$REPO" --remove-label "waiting-on-author"
        fi
    
        if [[ $days_since_event -ge $DAYS_BREACHED ]]; then 
            if ! echo "$pr_labels" | grep -q "sla-breached"; then 
                echo " SLA BREACHED: adding sla-breached label"
                gh pr edit $pr_number --repo "$ORG/$REPO" --add-label "sla-breached" 
                gh pr comment $pr_number --repo "$ORG/$REPO" --body "**SLA BREACHED:** This PR has been waiting for publication-admin review for $DAYS_BREACHED days."
            fi

            if echo "$pr_labels" | grep -q "sla-approaching"; then 
                gh pr edit $pr_number --repo "$ORG/$REPO" --remove-label "sla-approaching" 
            fi

        elif [[ $days_since_event -ge $DAYS_APPROACHING ]]; then 

            if ! echo "$pr_labels" | grep -q "sla-approaching"; then 
                echo "SLA APPROACHING: adding sla-approaching label"
                gh pr edit $pr_number --repo "$ORG/$REPO" --add-label "sla-approaching" 
                gh pr comment $pr_number --repo "$ORG/$REPO" --body "**SLA REMINDER:** This PR has been pending review for $DAYS_APPROACHING days. Publication-admin review target is $DAYS_BREACHED days."
            fi

        else
            if echo "$pr_labels" | grep -q "sla-approaching"; then 
                echo "Removing sla-approaching label (under 5 days)"
                gh pr edit $pr_number --repo "$ORG/$REPO" --remove-label "sla-approaching" 
            fi 

            if echo "$pr_labels" | grep -q "sla-breached"; then 
                echo "Removing sla-breached label (under 7 days)" 
                gh pr edit $pr_number --repo "$ORG/$REPO" --remove-label "sla-breached" 
            fi
        fi

    fi

echo "::endgroup::"
done
