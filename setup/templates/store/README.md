# Store texts — edit these, then run `make store-info`

One folder per language (`en-US`, `fr-FR`, ...). The same files are used for
**both** the App Store and Google Play:

| File | App Store | Google Play | Max length |
|---|---|---|---|
| `name.txt` | App name | Title | 30 |
| `subtitle.txt` | Subtitle | – | 30 |
| `short_description.txt` | – | Short description | 80 |
| `description.txt` | Description | Full description | 4000 |
| `keywords.txt` | Keywords (comma separated, no spaces) | – | 100 |
| `promotional_text.txt` | Promotional text | – | 170 |
| `release_notes.txt` | What's New (from version 1.0.1) | – | 4000 |

**Filled in automatically** from your developer profile and `app.env`,
so you never type them again:
review contact (name, phone, email), support / marketing / privacy URLs,
copyright, App Store category, Google Play contact email / phone / website.

To add a language: copy the `en-US` folder (for example to `fr-FR`), translate it,
and add the code to `STORE_LANGUAGES` in `app.env`.
