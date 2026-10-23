# NoteCraft

**Local-first Flutter notes app** — search, swipe-to-delete, SharedPreferences persistence, Material 3 dark UI. Ships for **Web · Android · iOS**.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

Live web demo: **https://kianpk.github.io/notecraft/**

## Features

- Tags (#hash), pins, archive, preview, JSON export. Light stone UI.


- Create / edit / delete notes
- Instant search
- Offline storage (`shared_preferences`)
- Responsive layout for phone & desktop web

## Run

```bash
flutter pub get
flutter run -d chrome
# android / ios
flutter run
```

## Web build (GitHub Pages)

```bash
flutter build web --base-href "/notecraft/"
# copy build/web → docs/
```

## License

MIT © [kianPk](https://github.com/kianPk)
