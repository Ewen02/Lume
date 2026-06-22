import Foundation

/// Traduction FR→EN des aliments courants, embarquée et instantanée, pour interroger
/// les bases USDA/OFF (anglophones) à partir d'une recherche en français.
///
/// Vocabulaire alimentaire = ensemble fini ; un dictionnaire couvre la grande majorité
/// des recherches sans coût ni réseau. Terme inconnu → on garde l'original.
enum FoodTranslator {
    /// Traduit un terme français en anglais, ou renvoie nil si non couvert.
    static func toEnglish(_ term: String) -> String? {
        let key = normalize(term)
        guard !key.isEmpty else { return nil }
        // Correspondance exacte, puis sur le mot principal (ex. "filet de poulet" → "poulet").
        if let hit = dictionary[key] { return hit }
        for word in key.split(separator: " ") {
            if let hit = dictionary[String(word)] { return hit }
        }
        return nil
    }

    /// Minuscule + sans accents (pour matcher quelle que soit la saisie).
    private static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Aliments les plus fréquents (clé normalisée sans accent → terme USDA anglais).
    private static let dictionary: [String: String] = [
        // Viandes & poissons
        "poulet": "chicken", "poulet grille": "grilled chicken", "blanc de poulet": "chicken breast",
        "boeuf": "beef", "steak": "beef steak", "steak hache": "ground beef", "porc": "pork",
        "jambon": "ham", "lardons": "bacon", "bacon": "bacon", "dinde": "turkey", "veau": "veal",
        "agneau": "lamb", "saucisse": "sausage", "saumon": "salmon", "thon": "tuna", "cabillaud": "cod",
        "crevette": "shrimp", "crevettes": "shrimp", "poisson": "fish", "sardine": "sardine",
        // Œufs & laitages
        "oeuf": "egg", "oeufs": "egg", "lait": "milk", "fromage": "cheese", "yaourt": "yogurt",
        "beurre": "butter", "creme": "cream", "creme fraiche": "sour cream", "skyr": "skyr",
        "fromage blanc": "fromage blanc", "mozzarella": "mozzarella", "cheddar": "cheddar",
        // Féculents & céréales
        "riz": "rice", "pates": "pasta", "pain": "bread", "pomme de terre": "potato",
        "patate": "potato", "frites": "french fries", "quinoa": "quinoa", "avoine": "oats",
        "flocons d avoine": "oatmeal", "semoule": "semolina", "ble": "wheat", "mais": "corn",
        "lentilles": "lentils", "haricots": "beans", "pois chiches": "chickpeas",
        // Légumes
        "laitue": "lettuce", "salade": "lettuce", "tomate": "tomato", "carotte": "carrot",
        "brocoli": "broccoli", "courgette": "zucchini", "aubergine": "eggplant", "poivron": "bell pepper",
        "concombre": "cucumber", "oignon": "onion", "ail": "garlic", "epinard": "spinach",
        "epinards": "spinach", "chou": "cabbage", "chou rouge": "red cabbage", "champignon": "mushroom",
        "haricot vert": "green beans", "petit pois": "peas", "betterave": "beet", "avocat": "avocado",
        // Fruits
        "pomme": "apple", "banane": "banana", "orange": "orange", "fraise": "strawberry",
        "framboise": "raspberry", "myrtille": "blueberry", "raisin": "grapes", "peche": "peach",
        "poire": "pear", "ananas": "pineapple", "mangue": "mango", "kiwi": "kiwi", "citron": "lemon",
        "pasteque": "watermelon", "melon": "melon", "cerise": "cherry", "abricot": "apricot",
        "fruit du dragon": "dragon fruit", "datte": "date", "figue": "fig",
        // Noix & graines
        "amande": "almonds", "amandes": "almonds", "noix": "walnuts", "noisette": "hazelnut",
        "cacahuete": "peanuts", "cacahuetes": "peanuts", "pistache": "pistachio",
        // Divers
        "chocolat": "chocolate", "miel": "honey", "sucre": "sugar", "huile": "oil",
        "huile d olive": "olive oil", "sel": "salt", "cafe": "coffee", "the": "tea",
        "ketchup": "ketchup", "mayonnaise": "mayonnaise", "moutarde": "mustard",
    ]
}
