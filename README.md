# Move Item Sorter

<!--PAGES_LINK_BANNER-->
> 🌐 **Live page:** [https://socrtwo.github.io/move-item-sorter/](https://socrtwo.github.io/move-item-sorter/)  
> 📦 **Releases:** [github.com/socrtwo/move-item-sorter/releases](https://github.com/socrtwo/move-item-sorter/releases)
<!--/PAGES_LINK_BANNER-->

**Cross-platform inventory management for your next move.**

Photograph every item in your home, speak its destination category, and let Move Item Sorter do the rest — from organising boxes to listing items for sale across major marketplaces.

---

## Platforms

| Platform | Status |
|----------|--------|
| Android  | Supported |
| iOS      | Supported |
| macOS    | Supported |
| Windows  | Supported |
| Linux    | Supported |
| Web      | Supported |

---

## Features

### Core Inventory
- **Photo capture** — take one photo or multiple angles of each item
- **Voice-first workflow** — speak item names and disposal decisions hands-free
- **Image recognition** — Google Cloud Vision automatically identifies items from photos
- **Barcode / QR scanning** — instant product lookup from barcodes
- **Room / location tagging** — assign each item to a room separately from its disposal category
- **Moving-day checklist** — mark items as Packed → Loaded → Delivered

### Disposal Categories
Assign every item to one of six categories (all fully configurable with custom keywords and sub-classifications):

| Category | Examples of sub-classifications |
|----------|---------------------------------|
| **Move** | Living Room, Master Bedroom, Kitchen, Garage |
| **Store** | Storage Unit, Attic, Basement |
| **Donate** | Goodwill, Salvation Army, Habitat |
| **Sell** | eBay, Amazon, Facebook Marketplace, Craigslist, Etsy, Walmart, OfferUp, Poshmark, Mercari, Depop |
| **Recycle** | Electronics, Paper, Metal |
| **Trash** | Hazardous, Bulk Pickup |

### Camera Modes
| Mode | How it works |
|------|-------------|
| **Manual** | Tap the shutter button to capture |
| **Semi-Auto** | Say "new item" (or your custom phrase) to capture |
| **Fully Automatic** | App watches for a new stationary, in-focus object and captures automatically |
| **Multi-angle** | Say "angles" or push the button to capture up to 8 views in sequence |

### Voice Commands (always listening during capture)
- **Categorise**: *"add this to move"*, *"put this in donate"*, *"categorize as sell"*, …
- **Sub-classify**: *"move to the living room"*, *"sell on eBay"*, *"donate to Goodwill"*, …
- **New item trigger**: *"new item"*, *"next item"*, *"capture"* (configurable)
- **Multi-angle**: *"angles"*, *"multi"*, *"rotate"* (configurable)
- All trigger phrases and category keywords are configurable in Settings

### Sell Flow (guided, voice-driven)
When an item is categorised as **Sell**, the app guides you through:
1. Which marketplace (spoken or tapped)
2. Listing type — Buy It Now / Auction / Auction + Buy It Now
3. Title — identified automatically or spoken by you
4. Subtitle
5. Price — AI-suggested based on item identity, or spoken by you
6. Description — speak it or let AI generate one
7. Shipping — spoken keywords: *"free"*, *"buyer arranges"*, *"exact"*, *"flat rate"*, *"local pickup"*
8. Condition — new / like new / good / fair / poor

In **semi-auto sell mode** the app listens continuously for all fields and fills any unspoken values with AI-generated suggestions (shown in [brackets]).

### Smart Features
- **AI-generated descriptions** — powered by OpenAI GPT-4o for marketplace listings
- **Price estimation** — AI suggests a selling price based on item identification
- **Smart photo enhancement** — auto-crop, brightness correction, background removal
- **Duplicate detection** — warns when a newly captured item may already be in your inventory
- **Insurance valuation mode** — record estimated market values; generate a total valuation report for your insurer

### Export & Reports
- **CSV** — all items and fields, no photos
- **Excel (.xlsx)** — all items with photo thumbnails embedded
- **SQLite (.db)** — full database export, openable in DB Browser, importable into Access via ODBC
- **Donation receipt PDF** — itemised receipt with estimated fair-market values for tax deduction
- **Insurance valuation report** — total value by category with policy info
- **Budget tracker** — running totals of expected sell revenue vs. donation write-off value

### Configuration
Everything is configurable in the Settings panel:
- Add / remove categories and custom keywords
- Add infinite sub-classifications to any category
- Manage rooms and location labels
- Configure each marketplace (API credentials, default listing type, shipping defaults)
- Camera sensitivity thresholds for auto-capture
- Speech recognition timeouts
- TTS speed and volume
- API keys (Google Vision, OpenAI, eBay, Amazon)

### Cloud Sync *(optional)*
- Firebase-based backup so multiple household members can contribute to the same inventory on different devices

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State management | Riverpod 2 |
| Navigation | go_router |
| Local database | SQLite (sqflite + sqflite_common_ffi for desktop) |
| Speech recognition | speech_to_text |
| Text-to-speech | flutter_tts |
| Camera | camera plugin |
| Barcode scanning | mobile_scanner |
| Image recognition | Google Cloud Vision API |
| AI descriptions / pricing | OpenAI GPT-4o |
| Export | excel, csv packages |
| Marketplace listing | eBay Trading API, Amazon SP-API, deep-links for others |

---

## Getting Started

### Prerequisites
- Flutter 3.16 or later — [install guide](https://flutter.dev/docs/get-started/install)
- Dart 3.2 or later (bundled with Flutter)
- For Android builds: Android SDK 21+
- For iOS / macOS builds: Xcode 15+, CocoaPods
- For Windows builds: Visual Studio 2022 with Desktop C++ workload

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/socrtwo/move-item-sorter.git
cd move-item-sorter

# 2. Install dependencies
flutter pub get

# 3. Run code generation (Riverpod, JSON serialisation)
dart run build_runner build --delete-conflicting-outputs

# 4. Launch on your target platform
flutter run                        # default connected device
flutter run -d android
flutter run -d ios
flutter run -d macos
flutter run -d windows
flutter run -d linux
flutter run -d chrome              # web
```

### API Keys
Copy `.env.example` to `.env` and fill in your keys (**never commit `.env`**):

```
GOOGLE_VISION_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here
EBAY_APP_ID=your_key_here
EBAY_DEV_ID=your_key_here
EBAY_CERT_ID=your_key_here
EBAY_USER_TOKEN=your_token_here
```

These can also be entered directly in **Settings → API Keys** inside the app.

### Regenerate Icons
Icons are programmatically generated via a Python script (requires Pillow):

```bash
pip install Pillow
python3 scripts/generate_icons.py
```

---

## Architecture

The project follows **Clean Architecture** with Riverpod for state management:

```
lib/
├── core/           # constants, theme, router
├── models/         # Item, Category, SellDetails, AppSettings
├── services/       # DatabaseService, SpeechService, VisionService, AiService,
│                   # ExportService, MarketplaceService, PhotoService, …
├── providers/      # Riverpod providers / notifiers
├── screens/        # full-page widgets
│   ├── home/
│   ├── camera/
│   ├── item_detail/
│   ├── sell_flow/
│   ├── settings/
│   └── export/
├── widgets/        # reusable components
└── utils/          # KeywordMatcher, helpers
```

---

## Contributing

1. Fork the repo and create a branch: `git checkout -b feature/my-feature`
2. Make your changes following the conventions in [CLAUDE.md](CLAUDE.md)
3. Run tests: `flutter test`
4. Open a pull request against `main`

---

## License

MIT — see [LICENSE](LICENSE).

Copyright 2026 Paul D Pruitt