# Flutter Metal Cube

Test project for rendering native Metal graphics displayed within the Flutter Texture Widget.
Renders a simple animated cube to a metal texture, which is then registered to the Flutter Texture registry.
Each time the contents of the texture are updated, the Flutter Texture Widget is notified and updated.

https://user-images.githubusercontent.com/1212726/217334427-45e95b75-c0b2-481c-9b07-9ca543fb2ff6.mp4

## Running

Works on macOS and iOS targets.

```
flutter pub get
flutter run
```

## Jank issues on Flutter < 3.8

As of current moment, with Flutter 3.7.1 there is noticeable jank with the Flutter Texture Widget.
Updating to the master branch fixed this issue.
