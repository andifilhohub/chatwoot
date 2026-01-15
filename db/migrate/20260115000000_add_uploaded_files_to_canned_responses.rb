class AddUploadedFilesToCannedResponses < ActiveRecord::Migration[7.1]
  def change
    add_column :canned_responses, :uploaded_files, :jsonb
  end
end
