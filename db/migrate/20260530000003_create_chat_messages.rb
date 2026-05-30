class CreateChatMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string  :role,          null: false               # 'user' | 'assistant'
      t.text    :content,       null: false, default: ""  # user query or AI summary text
      t.jsonb   :response_data                            # full structured AI response (assistant only)

      t.timestamps
    end

    add_index :chat_messages, [:conversation_id, :created_at]
    add_index :chat_messages, :role
  end
end
