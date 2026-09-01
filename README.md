# Bubble Pop — Setup

Yeh version "Bouncing Balls" (Bubble Shooter) jaisa hai: neeche se ball shoot karo,
side walls se bounce hoti hai, upar grid mein same-color 3+ bubbles match hone par pop ho jaate hain.

## Gameplay

- **Grid** upar colored bubbles se bhara hota hai
- **Drag karo** aim karne ke liye — dashed line dikhati hai ball kahan jayegi
- **Chhodo (release)** to shoot — ball seedhi line mein jaati hai, left/right walls se bounce karti hai
- Ball grid se takra kar snap ho jaati hai nearest khaali jagah par
- **3 ya zyada same-color bubbles** connected hon toh woh pop ho jaate hain + score milta hai
- Jo bubbles disconnect ho jayein (floating, ceiling se connect nahi) woh bhi gir kar pop ho jaate hain — bonus score
- Har **6 shots** ke baad grid ek row neeche shift hoti hai aur naya row upar add hota hai — difficulty badhti jaati hai
- Agar koi bubble shooter ke paas tak pahunch jaye → **Game Over**
- High score `shared_preferences` se save hota hai

## Kaha rakhna hai (Folder placement)

```
bouncing_ball_game/
├── pubspec.yaml                        → project root (replace)
└── lib/
    ├── main.dart                        → lib/main.dart (unchanged, replace if unsure)
    ├── models/
    │   └── ball.dart                    → lib/models/ball.dart (replace)
    ├── game/
    │   └── bubble_grid.dart             → lib/game/bubble_grid.dart (NEW)
    ├── services/
    │   └── high_score_service.dart      → lib/services/high_score_service.dart (unchanged, replace if unsure)
    ├── widgets/
    │   ├── bubble_shooter_painter.dart  → lib/widgets/bubble_shooter_painter.dart (NEW)
    │   └── menu_overlay.dart            → lib/widgets/menu_overlay.dart (replace)
    └── screens/
        └── game_screen.dart             → lib/screens/game_screen.dart (replace — full rewrite)
```

**DELETE karo (ab use nahi ho rahe, purane obstacle-dodger version se):**
- `lib/models/obstacle.dart`
- `lib/models/coin.dart`
- `lib/widgets/obstacles_painter.dart`
- `lib/widgets/ball_painter.dart`

## Run karne ke steps

1. Naye/replace files apni jagah copy karo, purani unused files delete karo
2. `flutter pub get`
3. `flutter run -d chrome`

## Note

Yeh endless mode hai (jaise ki asli "Bouncing Balls" app mein bhi endless/high-score mode hota hai) —
"1000 numbered levels" wala feature alag content-design system maangta hai; agar wo bhi chahiye
(fixed level layouts, level-select screen, moves-limit per level) toh bata dena, wo separately add kar sakti hun.

## Aage kya add kar sakti ho

- Fixed level layouts + level-select screen (asli app jaisa "1000 levels")
- Power-up bubbles (bomb, rainbow/wildcard color)
- Sound effects on pop/shoot
- Smooth pop animation (scale-out) instead of instant removal
- Particle burst on match
