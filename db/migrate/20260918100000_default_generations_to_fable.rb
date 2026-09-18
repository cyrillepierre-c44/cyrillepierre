# Le brouillon du Studio part désormais sur Claude Fable 5.1 : le modèle le plus capable de la
# passerelle, choisi par Cyrille le 18/09/2026 après deux notes de diagnostic sorties sur Gemini.
# Les générations existantes gardent leur modèle ; seule la valeur par défaut change.
class DefaultGenerationsToFable < ActiveRecord::Migration[8.1]
  def change
    change_column_default :generations, :llm_model, from: "gemini-3.5-flash", to: "claude-fable-5.1"
  end
end
