# Core Reusable Components

This directory contains core reusable components used throughout the app:

## Components

### CardWidget
A card component with rounded corners, border, and optional header/footer.

```dart
CardWidget(
  child: Text('Content'),
  header: Text('Header'),
  footer: Text('Footer'),
  elevation: true,
)
```

### TabBarWidget
A segmented tab bar component with active/inactive styling.

```dart
TabBarWidget(
  tabs: const [
    TabData(label: 'Tab 1'),
    TabData(label: 'Tab 2'),
  ],
  selectedIndex: 0,
  onChanged: (index) {},
)
```

### ProgressBar
A progress bar component with customizable appearance.

```dart
ProgressBar(
  progress: 0.5,
  appearance: ProgressBarAppearance(height: 8),
)
```

### Toggle
A switch toggle component with customizable appearance.

```dart
Toggle(
  value: true,
  onChanged: (value) {},
)
```

## Usage

Import the core widgets package:

```dart
import 'package:runnin/core/widgets/index.dart';
```

Then use any of the components listed above.
