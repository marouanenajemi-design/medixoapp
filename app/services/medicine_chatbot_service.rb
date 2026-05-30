class MedicineChatbotService
  SUPPORTED_LOCALES = %i[en fr].freeze

  # Model to use. gpt-4o-mini gives excellent medical accuracy at minimal cost.
  # Override with OPENAI_MODEL env var if needed.
  DEFAULT_MODEL = "gpt-4o-mini".freeze

  # Cache query results for 24 hours to reduce API cost for repeated lookups.
  CACHE_TTL = 24.hours

  # ── System prompt ──────────────────────────────────────────────────────────
  # Instructs the model to behave as a structured medical information assistant.
  # JSON output is enforced so the response always maps cleanly to our view structure.
  SYSTEM_PROMPT = <<~PROMPT.strip
    You are MedixoApp, a medical information assistant built for healthcare professionals
    in a clinic management system. Your role is to provide accurate, evidence-based
    information about medications, diseases, and medical topics to support clinical teams.

    RULES:
    - Always include a reminder to verify with a licensed pharmacist or doctor.
    - Never provide a personalized diagnosis or patient-specific treatment plan.
    - Dosage notes must reflect general/standard ranges only, never a prescription.
    - If the query is unrelated to medicine, health, or biology, respond with an error.
    - Respond in the same language as the user's query.

    RESPONSE FORMAT — you MUST return valid JSON with exactly these keys:
    {
      "medicine_name":       "Canonical name of the medicine or topic",
      "description":         "2–4 sentence factual overview",
      "common_uses":         ["Use 1", "Use 2", "Use 3"],
      "general_warnings":    ["Warning 1", "Warning 2", "Warning 3"],
      "common_side_effects": ["Side effect 1", "Side effect 2", "Side effect 3"],
      "drug_interactions":   ["Interaction 1", "Interaction 2"],
      "dosage_notes":        "General dosage guidance (not patient-specific). Always consult prescriber.",
      "disclaimer":          "Short reminder that this is for educational purposes only."
    }

    For disease queries, set medicine_name to the disease name and adapt the fields accordingly.
    For drug interaction queries, populate drug_interactions with specific pairs and mechanisms.
    For dosage queries, expand dosage_notes with age groups and renal/hepatic considerations where relevant.
    Keep all content professional, factual, and concise.
  PROMPT

  def initialize(locale: I18n.locale)
    @locale = locale.to_sym
    @locale = :en unless SUPPORTED_LOCALES.include?(@locale)
  end

  # Main entry point. Returns a Hash with medical information keys, or { error: "..." }.
  def answer(query:)
    user_query = query.to_s.strip
    return { error: t("chatbot.messages.empty_query") } if user_query.blank?

    # Check cache before hitting the API
    cached = Rails.cache.read(cache_key(user_query))
    return cached if cached.present?

    result = if openai_configured?
               openai_answer(user_query)
             else
               Rails.logger.warn("[MedicineChatbotService] OPENAI_API_KEY not set — using built-in knowledge base only")
               knowledge_base_answer(user_query)
             end

    # Cache successful responses only
    if result && !result[:error]
      Rails.cache.write(cache_key(user_query), result, expires_in: CACHE_TTL)
    end

    result
  end

  private

  # ── OpenAI integration ──────────────────────────────────────────────────────

  def openai_configured?
    ENV["OPENAI_API_KEY"].present?
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"],
      request_timeout: 20
    )
  end

  def openai_answer(user_query)
    model = ENV.fetch("OPENAI_MODEL", DEFAULT_MODEL)

    response = openai_client.chat(
      parameters: {
        model:           model,
        messages:        [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user",   content: user_query }
        ],
        response_format: { type: "json_object" },
        temperature:     0.2,    # Low temperature → more consistent, factual output
        max_tokens:      800
      }
    )

    raw_content = response.dig("choices", 0, "message", "content").to_s

    if raw_content.blank?
      Rails.logger.error("[MedicineChatbotService] OpenAI returned empty content for query: #{user_query.inspect}")
      return knowledge_base_answer(user_query)
    end

    parsed = JSON.parse(raw_content, symbolize_names: true)

    # Map OpenAI's JSON keys to our standard response hash
    build_response_from_openai(parsed)

  rescue OpenAI::Error => e
    Rails.logger.error("[MedicineChatbotService] OpenAI API error: #{e.class}: #{e.message}")
    # Graceful fallback to built-in KB if API fails
    knowledge_base_answer(user_query) || { error: t("chatbot.messages.service_unavailable") }

  rescue JSON::ParserError => e
    Rails.logger.error("[MedicineChatbotService] JSON parse error from OpenAI: #{e.message}. Raw: #{raw_content.truncate(200)}")
    { error: t("chatbot.messages.service_unavailable") }
  end

  def build_response_from_openai(parsed)
    # Normalise to arrays where the view expects arrays
    %i[common_uses general_warnings common_side_effects drug_interactions].each do |key|
      parsed[key] = Array(parsed[key]).compact.reject(&:blank?)
    end

    {
      medicine_name:       parsed[:medicine_name].to_s.presence || "—",
      description:         parsed[:description].to_s,
      common_uses:         parsed[:common_uses],
      general_warnings:    parsed[:general_warnings],
      common_side_effects: parsed[:common_side_effects],
      drug_interactions:   parsed[:drug_interactions],
      dosage_notes:        parsed[:dosage_notes].to_s,
      disclaimer:          parsed[:disclaimer].to_s
    }
  end

  # ── Built-in knowledge base (fast path / offline fallback) ─────────────────
  # Covers 4 common medicines without an API call. Used when OPENAI_API_KEY
  # is absent or as a fallback when the API is unreachable.

  KNOWLEDGE_BASE = {
    "ibuprofen" => {
      description: {
        en: "Ibuprofen is a nonsteroidal anti-inflammatory drug (NSAID) that reduces hormones causing inflammation and pain in the body.",
        fr: "L'ibuprofène est un anti-inflammatoire non stéroïdien (AINS) qui réduit les hormones provoquant inflammation et douleur."
      },
      common_uses: {
        en: ["Mild to moderate pain relief", "Fever reduction", "Inflammation from arthritis or injury"],
        fr: ["Soulagement des douleurs légères à modérées", "Réduction de la fièvre", "Inflammation liée à l'arthrite ou aux blessures"]
      },
      general_warnings: {
        en: ["Use caution with stomach ulcers or kidney disease", "May interact with blood thinners", "Not recommended in late pregnancy"],
        fr: ["Prudence en cas d'ulcère ou de maladie rénale", "Peut interagir avec les anticoagulants", "Déconseillé en fin de grossesse"]
      },
      common_side_effects: {
        en: ["Upset stomach", "Nausea", "Heartburn", "Dizziness"],
        fr: ["Maux d'estomac", "Nausées", "Brûlures d'estomac", "Vertiges"]
      },
      drug_interactions: {
        en: ["Warfarin (increased bleeding risk)", "Aspirin (GI bleed risk)", "ACE inhibitors (reduced efficacy)"],
        fr: ["Warfarine (risque hémorragique accru)", "Aspirine (risque de saignement GI)", "IEC (efficacité réduite)"]
      },
      dosage_notes: {
        en: "Adults: 200–400 mg every 4–6 hours. Max 1200 mg/day OTC. Prescription doses up to 3200 mg/day. Always take with food.",
        fr: "Adultes : 200–400 mg toutes les 4–6 heures. Max 1200 mg/jour sans ordonnance. À prendre avec de la nourriture."
      }
    },
    "paracetamol" => {
      description: {
        en: "Paracetamol (acetaminophen) is an analgesic and antipyretic widely used for pain and fever. It does not have significant anti-inflammatory properties.",
        fr: "Le paracétamol est un antalgique et antipyrétique utilisé pour la douleur et la fièvre, sans propriétés anti-inflammatoires significatives."
      },
      common_uses: {
        en: ["Mild to moderate pain", "Fever reduction", "Post-operative pain management"],
        fr: ["Douleurs légères à modérées", "Réduction de la fièvre", "Gestion post-opératoire de la douleur"]
      },
      general_warnings: {
        en: ["Overdose causes severe liver damage", "Avoid with heavy alcohol use", "Do not combine multiple paracetamol-containing products"],
        fr: ["Le surdosage cause des lésions hépatiques graves", "Évitez avec une consommation excessive d'alcool", "Ne combinez pas plusieurs produits contenant du paracétamol"]
      },
      common_side_effects: {
        en: ["Rare nausea at standard doses", "Liver damage with overdose", "Rare allergic rash"],
        fr: ["Nausées rares aux doses habituelles", "Lésions hépatiques en cas de surdosage", "Éruption allergique rare"]
      },
      drug_interactions: {
        en: ["Warfarin (increased INR at high doses)", "Alcohol (hepatotoxicity risk)", "Isoniazid (hepatotoxicity risk)"],
        fr: ["Warfarine (INR augmenté à doses élevées)", "Alcool (risque hépatotoxique)", "Isoniazide (risque hépatotoxique)"]
      },
      dosage_notes: {
        en: "Adults: 500–1000 mg every 4–6 hours. Max 4000 mg/day (3000 mg for elderly or liver risk). Children dosed by weight.",
        fr: "Adultes : 500–1000 mg toutes les 4–6 h. Max 4000 mg/jour (3000 mg chez les personnes âgées). Dose enfant selon le poids."
      }
    },
    "amoxicillin" => {
      description: {
        en: "Amoxicillin is a broad-spectrum penicillin-type antibiotic active against many gram-positive and some gram-negative bacteria.",
        fr: "L'amoxicilline est un antibiotique à large spectre de la famille des pénicillines, actif contre de nombreuses bactéries."
      },
      common_uses: {
        en: ["Ear, nose, and throat infections", "Respiratory tract infections", "Urinary tract infections", "Skin infections"],
        fr: ["Infections ORL", "Infections respiratoires", "Infections urinaires", "Infections cutanées"]
      },
      general_warnings: {
        en: ["Contraindicated with penicillin allergy", "Not effective against viral infections", "Complete the full course"],
        fr: ["Contre-indiqué en cas d'allergie aux pénicillines", "Inefficace contre les infections virales", "Terminer le traitement complet"]
      },
      common_side_effects: {
        en: ["Nausea and vomiting", "Diarrhea", "Skin rash", "Risk of C. difficile with prolonged use"],
        fr: ["Nausées et vomissements", "Diarrhée", "Éruption cutanée", "Risque de C. difficile en usage prolongé"]
      },
      drug_interactions: {
        en: ["Methotrexate (increased toxicity)", "Warfarin (increased anticoagulation)", "Oral contraceptives (reduced efficacy, rare)"],
        fr: ["Méthotrexate (toxicité accrue)", "Warfarine (anticoagulation augmentée)", "Contraceptifs oraux (efficacité réduite, rare)"]
      },
      dosage_notes: {
        en: "Adults: 250–500 mg every 8 hours or 500–875 mg every 12 hours depending on severity. Renal dose adjustment required if CrCl < 30.",
        fr: "Adultes : 250–500 mg toutes les 8 h ou 500–875 mg toutes les 12 h selon la sévérité. Ajustement si clairance < 30."
      }
    },
    "cetirizine" => {
      description: {
        en: "Cetirizine is a second-generation antihistamine with minimal sedating effects, used to relieve allergy symptoms.",
        fr: "La cétirizine est un antihistaminique de deuxième génération peu sédatif utilisé pour les symptômes allergiques."
      },
      common_uses: {
        en: ["Seasonal and perennial allergic rhinitis", "Urticaria and hives", "Allergic conjunctivitis"],
        fr: ["Rhinite allergique saisonnière et perannuelle", "Urticaire", "Conjonctivite allergique"]
      },
      general_warnings: {
        en: ["May cause drowsiness in some patients", "Use caution in severe renal impairment", "Avoid with CNS depressants"],
        fr: ["Peut provoquer de la somnolence", "Prudence en cas d'insuffisance rénale sévère", "Éviter avec les dépresseurs du SNC"]
      },
      common_side_effects: {
        en: ["Drowsiness", "Dry mouth", "Fatigue", "Headache"],
        fr: ["Somnolence", "Bouche sèche", "Fatigue", "Maux de tête"]
      },
      drug_interactions: {
        en: ["Alcohol (increased sedation)", "CNS depressants (additive effect)", "Azithromycin (QT prolongation risk)"],
        fr: ["Alcool (sédation accrue)", "Dépresseurs du SNC (effet additif)", "Azithromycine (risque allongement QT)"]
      },
      dosage_notes: {
        en: "Adults and children ≥12: 10 mg once daily. Children 6–11: 5–10 mg once daily. Renal impairment: 5 mg once daily.",
        fr: "Adultes et enfants ≥12 ans : 10 mg une fois par jour. Enfants 6–11 ans : 5–10 mg/jour. Insuffisance rénale : 5 mg/jour."
      }
    }
  }.freeze

  def knowledge_base_answer(user_query)
    medicine_key = extract_medicine_key(user_query)
    return { error: t("chatbot.messages.ask_medicine_name") } if medicine_key.blank?

    data = KNOWLEDGE_BASE[medicine_key]
    return { error: t("chatbot.messages.ask_medicine_name") } unless data

    {
      medicine_name:       medicine_key.titleize,
      description:         data[:description][@locale],
      common_uses:         data[:common_uses][@locale],
      general_warnings:    data[:general_warnings][@locale],
      common_side_effects: data[:common_side_effects][@locale],
      drug_interactions:   data[:drug_interactions][@locale],
      dosage_notes:        data[:dosage_notes][@locale],
      disclaimer:          t("chatbot.messages.disclaimer")
    }
  end

  def extract_medicine_key(query)
    normalized = query.downcase
    # Handle common aliases first
    return "paracetamol" if normalized.match?(/paracetamol|acetaminophen|acétaminophène/)

    KNOWLEDGE_BASE.keys.find { |med| normalized.include?(med) }
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  def cache_key(query)
    digest = Digest::MD5.hexdigest(query.downcase.strip)
    "medicine_chatbot:#{@locale}:#{digest}"
  end

  def t(key)
    I18n.t(key, locale: @locale)
  end
end
