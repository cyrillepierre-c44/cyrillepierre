# L'analyse financière d'une note de diagnostic a son propre champ : collée à la suite du brief,
# elle se confondait avec lui, et le mode de la note (comptes ou signaux publics) ne pouvait
# pas se décider sur la présence d'un fichier que Cyrille ne joignait pas.
class AddFinancialAnalysisToGenerations < ActiveRecord::Migration[8.1]
  def change
    add_column :generations, :financial_analysis, :text
  end
end
