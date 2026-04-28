#!/bin/bash
# Apply custom invitation and verification email templates to a Cognito User Pool.
# All settings are applied in a single update-user-pool call to prevent regression.
# Usage: ./apply-email-template.sh <user-pool-id> [aws-profile] [region] [ses-source-arn] [from-address] [reply-to]

set -e

USER_POOL_ID="${1:?Usage: $0 <user-pool-id> [aws-profile] [region] [ses-source-arn] [from-address] [reply-to]}"
AWS_PROFILE="${2:-default}"
REGION="${3:-us-east-1}"
SES_SOURCE_ARN="${4:-arn:aws:ses:us-east-1:459120389451:identity/willdan.io}"
FROM_ADDRESS="${5:-Willdan - Claude Code <auth@willdan.io>}"
REPLY_TO="${6:-auth@willdan.com}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INVITE_TEMPLATE="$SCRIPT_DIR/invitation-email.html"
VERIFY_TEMPLATE="$SCRIPT_DIR/verification-email.html"

for f in "$INVITE_TEMPLATE" "$VERIFY_TEMPLATE"; do
  if [ ! -f "$f" ]; then
    echo "Error: Template file not found at $f"
    exit 1
  fi
done

echo "Applying email templates and configuration to user pool: $USER_POOL_ID"
echo "Region: $REGION"
echo "Profile: $AWS_PROFILE"

# Build and apply all settings in a single update-user-pool call
AWS_PROFILE="$AWS_PROFILE" aws cognito-idp update-user-pool \
  --user-pool-id "$USER_POOL_ID" \
  --region "$REGION" \
  --email-configuration "EmailSendingAccount=DEVELOPER,SourceArn=$SES_SOURCE_ARN,From=$FROM_ADDRESS,ReplyToEmailAddress=$REPLY_TO" \
  --email-verification-subject "Verify your Willdan Claude Code email address" \
  --email-verification-message file://"$VERIFY_TEMPLATE" \
  --admin-create-user-config file://<(python3 -c "
import json
with open('$INVITE_TEMPLATE') as f:
    body = f.read()
config = {
    'AllowAdminCreateUserOnly': False,
    'UnusedAccountValidityDays': 7,
    'InviteMessageTemplate': {
        'EmailSubject': 'Welcome to Willdan Claude Code - Your Account Details',
        'EmailMessage': body,
        'SMSMessage': 'Your username is {username} and temporary password is {####}.'
    }
}
print(json.dumps(config))
")

echo "Done. All email templates and SES configuration applied."
