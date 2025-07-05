# Configuration Setup

This app uses a configuration file to manage sensitive information like API keys. The actual configuration file is not committed to version control for security reasons.

## Setup Instructions

1. **Copy the template file:**
   ```bash
   cp Config.plist.template Config.plist
   ```

2. **Edit the configuration file:**
   Open `Config.plist` and replace the placeholder values with your actual Appwrite configuration:
   
   - `AppwriteEndpoint`: Your Appwrite endpoint URL
   - `AppwriteProjectId`: Your Appwrite project ID
   - `AppwriteDatabaseId`: Your Appwrite database ID
   - `AppwriteApiKey`: Your Appwrite API key

## Security Notes

- The `Config.plist` file is ignored by git (see `.gitignore`)
- Only `Config.plist.template` is committed to version control
- Never commit the actual `Config.plist` file with real secrets
- Share configuration values securely with team members (not through version control)

## Troubleshooting

If you see a warning about not being able to load `Config.plist`, make sure:
1. You've copied `Config.plist.template` to `Config.plist`
2. You've filled in the actual configuration values
3. The `Config.plist` file is included in your Xcode project target 