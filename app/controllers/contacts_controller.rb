require "net/http"

class ContactsController < ApplicationController
  def new
  end

  def chat
    message = params[:message].to_s.strip
    history = params[:history] || []
    themes  = params[:themes]  || []
    initial = params[:initial].to_s == "true"

    messages = [{ role: "system", content: build_system_prompt(themes) }]
    history.each { |m| messages << { role: m["role"], content: m["content"] } }
    messages << { role: "user", content: initial ? "__START__" : message }

    reply = call_llm(messages)
    render json: { reply: reply, ready: reply.include?("##READY##") }
  end

  def summarize
    history = params[:history] || []
    themes  = params[:themes]  || []

    messages = [
      { role: "system", content: "Tu rédiges des résumés structurés de demandes clients. Réponds en français." },
      *history.map { |m| { role: m["role"], content: m["content"] } },
      {
        role: "user",
        content: <<~PROMPT
          Génère un résumé structuré de la demande (max 80 mots) pour Cyrille PIERRE, consultant.
          Thèmes : #{themes.join(", ")}.
          Format :
          • Contexte : ...
          • Défi / Problème : ...
          • Ce qu'il recherche : ...
          • Urgence estimée : ...
        PROMPT
      }
    ]

    render json: { summary: call_llm(messages) }
  end

  def create
    ContactMailer.new_contact(
      name:    params[:contact_name],
      email:   params[:contact_email],
      company: params[:contact_company],
      phone:   params[:contact_phone],
      themes:  Array(params[:contact_themes]),
      summary: params[:contact_summary],
      history: params[:contact_history]
    ).deliver_later

    redirect_to root_path, notice: "Votre demande a bien été envoyée ! Je vous réponds sous 24h."
  end

  private

  def build_system_prompt(themes)
    themes_str = themes.any? ? themes.join(", ") : "non précisés"
    <<~PROMPT
      Tu es l'assistant de contact de Cyrille PIERRE, consultant indépendant expert en :
      - Excellence Opérationnelle (Lean, KAIZEN, TPM, WCM, 5S, TRS)
      - Leadership & Transformation (management jusqu'à 200 personnes, ADKAR, change management)
      - Tech & IA (développeur Rails, intégration IA, outils métier sur mesure)

      Ton rôle : aider le visiteur à formuler son besoin clairement pour que Cyrille puisse lui répondre efficacement.
      Thèmes sélectionnés : #{themes_str}

      Règles absolues :
      - Réponds toujours en français
      - Sois professionnel, chaleureux et concis
      - Pose UNE seule question à la fois
      - Si le visiteur envoie "__START__", accueille-le et pose ta première question (secteur, taille de la structure)
      - Après au moins 3 échanges substantiels et quand tu as suffisamment d'informations, ajoute exactement "##READY##" sur une nouvelle ligne à la fin de ta réponse
      - N'utilise jamais "##READY##" avant d'avoir posé au moins 2 vraies questions
    PROMPT
  end

  def call_llm(messages)
    uri = URI("https://models.inference.ai.azure.com/chat/completions")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{ENV.fetch('GITHUB_KEY', '')}"
    req["Content-Type"]  = "application/json"
    req.body = { model: "gpt-4o-mini", messages: messages, max_tokens: 500, temperature: 0.7 }.to_json

    data = JSON.parse(http.request(req).body)
    data.dig("choices", 0, "message", "content") || "Désolé, une erreur est survenue."
  rescue => e
    Rails.logger.error "ContactsController LLM error: #{e.message}"
    "Je rencontre une difficulté technique. Écrivez directement à cyrille.pierre@gmail.com"
  end
end
