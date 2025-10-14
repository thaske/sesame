# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sesame RailsAdmin integration" do
  it "adds custom fields to the Email model configuration" do
    list_field_names = RailsAdmin.config("Email").list.fields.map(&:name)
    expect(list_field_names).to include(:current_status)

    show_field_names = RailsAdmin.config("Email").show.fields.map(&:name)
    expect(show_field_names).to include(:email_preview)
  end

  it "adds scopes to the EmailEvent list view" do
    scopes = RailsAdmin.config("EmailEvent").list.scopes
    expect(scopes).to include(:recent, :delivered, :bounced, :failed)
  end
end
