# Gaabi AI Assistant

A comprehensive iOS personal assistant app that combines task management, location services, voice notes, AI integration, smart home control, and habit tracking.

## Features

- 📋 Task Management
- 📍 Location-based Services
- 🎤 Voice Notes with Transcription
- 🤖 AI-powered Assistance
- 🏠 Smart Home Integration
- 📊 Habit Tracking

## Setup

1. Clone the repository:
```bash
git clone https://github.com/coladimeji/GaabiAi.git
cd GaabiAi
```

2. Set up environment variables:
```bash
cp .env.template .env
cp Config.xcconfig.template Config.xcconfig
```

3. Configure your environment variables:
   - Edit `.env` with your API keys
   - Update `Config.xcconfig` with your configuration
   - Add the configuration file to your Xcode project

4. Install dependencies (if any)

5. Open `Gaabi.xcodeproj` in Xcode

## Environment Variables

The following environment variables are required:

- `OPENAI_API_KEY`: Your OpenAI API key
- `WEATHER_API_KEY`: Weather service API key
- `MAPS_API_KEY`: Maps service API key

## Security

This project uses environment variables to secure sensitive information. Make sure to:
- Never commit `.env` or `Config.xcconfig` files
- Keep your API keys private
- Use the template files as references

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details
