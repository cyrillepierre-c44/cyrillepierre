# Le visuel d'un post part sur Gemini 3 Pro Image, le meilleur modèle d'image de la passerelle
# (essai du 18/09/2026 : 15 s, composition propre, sans texte parasite). Le défaut de colonne
# suit le défaut de l'application ; les générations existantes gardent leur modèle.
class DefaultVisualsToGemini3ProImage < ActiveRecord::Migration[8.1]
  def change
    change_column_default :generations, :image_model, from: "gemini-2.5-flash-image", to: "gemini-3-pro-image-preview"
  end
end
