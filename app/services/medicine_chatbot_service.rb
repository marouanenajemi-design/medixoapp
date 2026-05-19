class MedicineChatbotService
  SUPPORTED_LOCALES = %i[en fr].freeze

  KNOWLEDGE_BASE = {
    "ibuprofen" => {
      description: {
        en: "Ibuprofen is a nonsteroidal anti-inflammatory drug (NSAID).",
        fr: "L'ibuprofène est un anti-inflammatoire non stéroïdien (AINS)."
      },
      common_uses: {
        en: ["Temporary relief of mild pain", "Fever reduction", "Inflammation-related discomfort"],
        fr: ["Soulagement temporaire des douleurs légères", "Réduction de la fièvre", "Inconfort lié à l'inflammation"]
      },
      general_warnings: {
        en: ["Use caution with stomach ulcers or kidney disease", "May interact with blood thinners", "Use as labeled and seek professional advice when unsure"],
        fr: ["Prudence en cas d'ulcère gastrique ou de maladie rénale", "Peut interagir avec les anticoagulants", "Utilisez selon l'étiquetage et demandez conseil en cas de doute"]
      },
      common_side_effects: {
        en: ["Upset stomach", "Nausea", "Heartburn"],
        fr: ["Maux d'estomac", "Nausées", "Brûlures d'estomac"]
      }
    },
    "paracetamol" => {
      description: {
        en: "Paracetamol (acetaminophen) is a pain reliever and fever reducer.",
        fr: "Le paracétamol (acétaminophène) est un antalgique et antipyrétique."
      },
      common_uses: {
        en: ["Mild pain relief", "Fever reduction", "Short-term symptom management"],
        fr: ["Soulagement des douleurs légères", "Réduction de la fièvre", "Gestion symptomatique de courte durée"]
      },
      general_warnings: {
        en: ["Avoid combining multiple acetaminophen-containing products", "Use caution with liver disease", "Use only as directed on the label"],
        fr: ["Évitez de combiner plusieurs produits contenant de l'acétaminophène", "Prudence en cas de maladie du foie", "Utilisez uniquement selon les instructions de l'étiquette"]
      },
      common_side_effects: {
        en: ["Usually well tolerated at labeled use", "Rare nausea", "Rare rash"],
        fr: ["Généralement bien toléré aux doses indiquées", "Nausées rares", "Éruption cutanée rare"]
      }
    },
    "amoxicillin" => {
      description: {
        en: "Amoxicillin is a penicillin-type antibiotic.",
        fr: "L'amoxicilline est un antibiotique de la famille des pénicillines."
      },
      common_uses: {
        en: ["Commonly used for bacterial infections", "Ear, throat, or sinus infections", "Other infections as decided by a prescriber"],
        fr: ["Souvent utilisée pour les infections bactériennes", "Infections de l'oreille, de la gorge ou des sinus", "Autres infections selon décision du prescripteur"]
      },
      general_warnings: {
        en: ["Not effective for viral illnesses", "Avoid if allergy to penicillin-class drugs", "Use only with professional prescription guidance"],
        fr: ["Inefficace contre les maladies virales", "À éviter en cas d'allergie aux pénicillines", "À utiliser uniquement sur prescription professionnelle"]
      },
      common_side_effects: {
        en: ["Nausea", "Diarrhea", "Skin rash"],
        fr: ["Nausées", "Diarrhée", "Éruption cutanée"]
      }
    },
    "cetirizine" => {
      description: {
        en: "Cetirizine is an antihistamine used for allergy symptoms.",
        fr: "La cétirizine est un antihistaminique utilisé contre les symptômes allergiques."
      },
      common_uses: {
        en: ["Allergic rhinitis symptoms", "Itching and hives", "Seasonal allergy symptom relief"],
        fr: ["Symptômes de rhinite allergique", "Démangeaisons et urticaire", "Soulagement des allergies saisonnières"]
      },
      general_warnings: {
        en: ["May cause drowsiness in some people", "Use caution when driving until effects are known", "Review label warnings for interactions"],
        fr: ["Peut provoquer de la somnolence chez certaines personnes", "Prudence lors de la conduite tant que l'effet n'est pas connu", "Consultez les avertissements de l'étiquette pour les interactions"]
      },
      common_side_effects: {
        en: ["Drowsiness", "Dry mouth", "Fatigue"],
        fr: ["Somnolence", "Bouche sèche", "Fatigue"]
      }
    }
  }.freeze

  def initialize(locale: I18n.locale)
    @locale = locale.to_sym
    @locale = :en unless SUPPORTED_LOCALES.include?(@locale)
  end

  def answer(query:)
    user_query = query.to_s.strip
    return { error: t("chatbot.messages.empty_query") } if user_query.blank?

    medicine_key = extract_medicine_key(user_query)
    return { error: t("chatbot.messages.ask_medicine_name") } if medicine_key.blank?

    data = KNOWLEDGE_BASE[medicine_key] || generic_information(medicine_key)

    {
      medicine_name: medicine_key.titleize,
      description: data[:description][@locale],
      common_uses: data[:common_uses][@locale],
      general_warnings: data[:general_warnings][@locale],
      common_side_effects: data[:common_side_effects][@locale]
    }
  end

  private

  def t(key)
    I18n.t(key, locale: @locale)
  end

  def extract_medicine_key(query)
    normalized = query.downcase

    return "paracetamol" if normalized.include?("paracetamol") || normalized.include?("acetaminophen") || normalized.include?("acétaminophène")

    KNOWLEDGE_BASE.keys.find { |medicine| normalized.include?(medicine) }
  end

  def generic_information(medicine_key)
    {
      description: {
        en: "#{medicine_key.titleize} is a medicine name. Here is general information only.",
        fr: "#{medicine_key.titleize} est un nom de médicament. Voici des informations générales uniquement."
      },
      common_uses: {
        en: ["Common uses depend on formulation and local approval", "Read the package label", "Ask a professional for your specific situation"],
        fr: ["Les usages courants dépendent de la formulation et de l'autorisation locale", "Lisez l'étiquette du produit", "Demandez un avis professionnel pour votre situation spécifique"]
      },
      general_warnings: {
        en: ["Do not use as a diagnosis tool", "Do not rely on this for personalized dosing", "Always verify with a doctor or pharmacist"],
        fr: ["N'utilisez pas ceci comme outil de diagnostic", "Ne vous basez pas sur ceci pour une posologie personnalisée", "Vérifiez toujours avec un médecin ou un pharmacien"]
      },
      common_side_effects: {
        en: ["Side effects vary by product and person", "Review official product information", "Stop and seek medical help for severe reactions"],
        fr: ["Les effets secondaires varient selon le produit et la personne", "Consultez les informations officielles du produit", "Arrêtez et consultez en cas de réaction sévère"]
      }
    }
  end
end
