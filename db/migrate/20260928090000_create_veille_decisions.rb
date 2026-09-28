# La mémoire de tri de Cyrille : chaque « Retenir », « Écarter » ou suppression de fiche porte
# sa raison, dans ses mots. La routine du lundi la relit (GET /api/veille_memory) pour ne pas
# ressortir une entreprise déjà tranchée et pour appliquer ses règles. Table indépendante des
# signaux et des fiches : une raison survit à la suppression de ce qu'elle jugeait.
class CreateVeilleDecisions < ActiveRecord::Migration[8.1]
  def up
    create_table :veille_decisions do |t|
      t.string :company, null: false
      t.string :company_key, null: false
      t.string :signal_type
      t.string :source_name
      t.string :source_url
      t.integer :decision, null: false, default: 0
      t.text :reason
      t.references :user, foreign_key: true
      t.references :veille_signal, foreign_key: { on_delete: :nullify }
      t.references :prospect, foreign_key: { on_delete: :nullify }
      t.timestamps
    end
    add_index :veille_decisions, :company_key
    add_index :veille_decisions, :created_at

    # Les signaux déjà tranchés avant cette table entrent dans la mémoire sans raison : c'est ce
    # qui permet, dès lundi, de reconnaître une entreprise déjà retenue (Nicoll, 28/09/2026).
    admin_id = select_value("SELECT id FROM users WHERE role = 1 ORDER BY id LIMIT 1")
    select_all("SELECT * FROM veille_signals WHERE status <> 0 ORDER BY updated_at").each do |s|
      key = VeilleDecision.company_key(s["company"])
      execute ActiveRecord::Base.sanitize_sql_array([<<~SQL, s["company"], key, s["signal_type"], s["source_name"],
        INSERT INTO veille_decisions (company, company_key, signal_type, source_name, source_url, decision, user_id,
                                      veille_signal_id, prospect_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
                                                    s["source_url"], s["status"] == 1 ? 0 : 1, admin_id, s["id"],
                                                    s["prospect_id"], s["updated_at"], s["updated_at"]])
    end
  end

  def down
    drop_table :veille_decisions
  end
end
