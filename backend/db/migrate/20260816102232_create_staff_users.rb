class CreateStaffUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :staff_users, :email, unique: true
  end
end
