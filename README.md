# Ricochet Pop 🎯

A fast-paced bounce-and-pop arcade game built with **Flutter**. Aim, shoot, and match colored bubbles in this bubble-shooter-style game inspired by classics like *Bubble Shooter* and *Bouncing Balls*.

## Gameplay

- **Aim** by dragging on screen — a dashed trajectory line shows where the ball will travel.
- **Release** to shoot — the ball travels in a straight line and bounces off the left/right walls.
- The ball snaps into the nearest open slot when it hits the bubble grid.
- **Match 3 or more** same-colored, connected bubbles to pop them and score points.
- Bubbles left floating (disconnected from the ceiling) fall and pop automatically for bonus points.
- Every **6 shots**, the grid shifts down one row and a new row is added — difficulty increases over time.
- **Game Over** if any bubble reaches the shooter.
- High scores are saved locally using `shared_preferences`.

## Tech Stack

- **Framework:** Flutter (Dart)
- **State/Rendering:** Custom `CustomPainter` for grid and ball rendering
- **Persistence:** `shared_preferences` — local high score storage
- **Audio:** `audioplayers` — sound effects
- **Monetization:** `google_mobile_ads`
- **Platforms:** Android, iOS, Web, Windows, macOS, Linux

## Project Structure

```
lib/
├── main.dart                        # App entry point
├── models/
│   └── ball.dart                    # Ball data model
├── game/
│   └── bubble_grid.dart             # Grid logic, matching, and collision
├── services/
│   └── high_score_service.dart      # High score persistence
├── widgets/
│   ├── bubble_shooter_painter.dart  # Custom painter for game rendering
│   └── menu_overlay.dart            # Menu / overlay UI
└── screens/
    └── game_screen.dart             # Main game screen
```

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>=3.0.0 <4.0.0)
- A connected device, emulator, or Chrome for web

### Installation

```bash
git clone https://github.com/zahra01-m/Ricochet_Pop.git
cd Ricochet_Pop
flutter pub get
```

### Run

```bash
flutter run -d chrome     # Web
flutter run                # Connected device/emulator
```

## Roadmap

- [ ] Fixed level layouts with a level-select screen
- [ ] Power-up bubbles (bomb, rainbow/wildcard color)
- [ ] Sound effects on pop/shoot
- [ ] Smooth pop animation (scale-out) instead of instant removal
- [ ] Particle burst effects on match

## Author

**Zahra Mushtaq**
[GitHub](https://github.com/zahra01-m) · [LinkedIn](https://www.linkedin.com/in/zahra-mushtaq-)

## License

This project currently has no license specified. Add a `LICENSE` file if you intend to open-source it under a specific license (e.g., MIT).
