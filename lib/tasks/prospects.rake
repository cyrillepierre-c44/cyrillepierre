# En production, une fois après déploiement : heroku run rails prospects:cabinets -a cyrillepierre
namespace :prospects do
  desc "Crée les fiches des cabinets de management de transition à se faire référencer (CabinetReferencing)"
  task cabinets: :environment do
    admin = User.admin.order(:id).first or abort("Aucun administrateur : rien à rattacher.")
    created = CabinetReferencing.create_missing!(user: admin)
    puts "#{created} fiche(s) cabinet créée(s), #{CabinetReferencing::CABINETS.size - created} déjà présente(s)."
  end
end
