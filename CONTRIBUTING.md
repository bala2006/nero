# Contributing to Nero

Thank you for your interest in contributing to Nero! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/nero.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Run tests: `flutter test`
6. Commit your changes: `git commit -m "Add your feature"`
7. Push to your fork: `git push origin feature/your-feature-name`
8. Open a Pull Request

## Development Setup

### Prerequisites
- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2
- Android Studio or VS Code with Flutter extensions

### Installation
```bash
# Install dependencies
flutter pub get

# Generate code (for Drift database)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

## Code Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` before committing
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

## Testing

- Write unit tests for new features
- Ensure all tests pass before submitting PR
- Aim for good test coverage

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/path/to/test_file.dart
```

## Pull Request Process

1. Update the README.md with details of changes if applicable
2. Ensure your code follows the project's code style
3. Make sure all tests pass
4. Update documentation if needed
5. Your PR will be reviewed by maintainers

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive experience for everyone.

### Our Standards

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Publishing others' private information
- Any conduct that could reasonably be considered inappropriate

## Questions?

Feel free to open an issue for any questions or concerns.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
