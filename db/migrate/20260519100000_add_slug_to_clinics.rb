class AddSlugToClinics < ActiveRecord::Migration[7.1]
  def up
    add_column :clinics, :slug, :string

    Clinic.find_each do |clinic|
      base      = clinic.name.to_s.parameterize.presence || "clinic"
      candidate = base
      n = 1
      while Clinic.where(slug: candidate).where.not(id: clinic.id).exists?
        candidate = "#{base}-#{n}"
        n += 1
      end
      clinic.update_column(:slug, candidate)
    end

    change_column_null :clinics, :slug, false
    add_index :clinics, :slug, unique: true
  end

  def down
    remove_index :clinics, :slug
    remove_column :clinics, :slug
  end
end
