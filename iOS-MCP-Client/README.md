# iOS MCP Client

## Environment Variables Setup

This project uses environment variables to store sensitive information like API keys. You have two options for setting up your environment variables:

### Option 1: Using Xcode Environment Variables

1. Create a local `.env` file based on the `.env.example` template
2. In Xcode, go to Product → Scheme → Edit Scheme
3. Select "Run" from the left sidebar
4. Go to the "Arguments" tab
5. Under "Environment Variables", add your variables (e.g., OPENAI_API_KEY)

### Option 2: Including .env File in Bundle (for development only)

1. Create a `.env` file in the project root based on the `.env.example` template
2. Add the `.env` file to your Xcode project:
   - Drag the `.env` file into your Xcode project navigator
   - When prompted, check "Copy items if needed" and select your target
   - Important: Before committing, ensure the `.env` file is not added to version control

### Security Notes

- The `.env` file should never be committed to version control
- For production builds, use more secure methods like Keychain for storing sensitive information
- The `.env` file method is primarily intended for development purposes

## How It Works

The `Config` class will:
1. First try to load variables from Xcode's environment variables
2. Fall back to the `.env` file if included in the bundle
3. Return empty string if neither is available (which should trigger an appropriate error message) 