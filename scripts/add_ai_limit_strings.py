"""Adds the ai.limit.* strings (daily AI limit, HTTP 429) to the 6 locale files.

Keeps the existing key order and inserts each new key before the first
existing key that sorts after it. Run from the project root.
"""
import json

STRINGS = {
    "ai.limit.title": {
        "it": "Limite giornaliero raggiunto",
        "en": "Daily limit reached",
        "es": "Límite diario alcanzado",
        "fr": "Limite quotidienne atteinte",
        "de": "Tageslimit erreicht",
        "pt": "Limite diário atingido",
    },
    "ai.limit.msg": {
        "it": "Hai usato tutte le analisi AI di oggi. Riprova domani: intanto puoi scegliere a mano.",
        "en": "You’ve used all of today’s AI analyses. Try again tomorrow — meanwhile you can choose manually.",
        "es": "Has usado todos los análisis con IA de hoy. Vuelve a intentarlo mañana; mientras tanto, puedes elegir manualmente.",
        "fr": "Tu as utilisé toutes les analyses IA d’aujourd’hui. Réessaie demain — en attendant, tu peux choisir manuellement.",
        "de": "Du hast alle heutigen KI-Analysen verbraucht. Versuch es morgen wieder – bis dahin kannst du manuell wählen.",
        "pt": "Você usou todas as análises de IA de hoje. Tente novamente amanhã — enquanto isso, pode escolher manualmente.",
    },
}

for lang in ["it", "en", "es", "fr", "de", "pt"]:
    path = f"ios/MoodE/Resources/{lang}.json"
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    items = [(k, v) for k, v in data.items() if k not in STRINGS]
    for key in sorted(STRINGS):
        value = STRINGS[key][lang]
        index = next((i for i, (k, _) in enumerate(items) if k > key), len(items))
        items.insert(index, (key, value))
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(dict(items), ensure_ascii=False, indent=2) + "\n")
    print(lang, "ok")
